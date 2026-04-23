classdef VoltageOutputXY < mladapter
    properties
        Channel   % Stimulation# on the I/O menu, scalar or 1-by-2
    end
    properties (Access = protected)
        AO
        nStim
        nChan
        ChanIndex
        OutputRange
    end
    
    methods
        function obj = VoltageOutputXY(varargin)
            obj@mladapter(varargin{:});
        end
        
        function set.Channel(obj,val)
            if ~isvector(val) || 2<numel(val), error('Channel must be a scalar or 1-by-2 vector'); end
            non_stim = ~ismember(val,obj.Tracker.DAQ.stimulation_available);
            if any(non_stim), error('Stimulation #%d is not assigned.',val(find(non_stim,1))); end
            obj.Channel = val;
            
            daq = [obj.Tracker.DAQ.Stimulation{val}];
            if 1~=length(unique({daq.Name})), error('All analogoutput channels must be on the same DAQ device.'); end
            
            obj.AO = daq(1); %#ok<*MCSUP>
            obj.nStim = length(obj.Channel);     % # of stimulations
            obj.nChan = length(obj.AO.Channel);  % # of analogoutput channels
            obj.ChanIndex = zeros(1,obj.nStim);
            for m=1:obj.nStim, obj.ChanIndex(m) = obj.AO.Channel(strcmp(sprintf('Stimulation%d',obj.Channel(m)),obj.AO.Channel.ChannelName)).Index; end
            obj.OutputRange = obj.AO.Channel(obj.ChanIndex(1)).OutputRange;
        end
        
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            if ~isempty(obj.Tracker.XYData)
                data = obj.Tracker.CalFun.pix2deg(obj.Tracker.XYData(end,:));
                data = min(max(data,obj.OutputRange(1)),obj.OutputRange(2));
                
                output = zeros(1,obj.nChan);
                output(obj.ChanIndex) = data(1:obj.nStim);
                putsample(obj.AO,output);
            end
        end
    end
end
