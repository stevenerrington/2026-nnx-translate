classdef Stimulator < mlstimulus
    properties
        WaveformNumber
        Channel   % Stimulation# on the I/O menu, scalar or vector
        Waveform  % n-by-Channel
        Frequency
        OffAtSceneEnd = false;
    end
    properties (Access = protected)
        AO
        Filepath
    end
    
    methods
        function obj = Stimulator(varargin)
            obj@mlstimulus(varargin{:});
        end

        function set.Channel(obj,val)
            if ~isvector(val), error('Channel must be a vector'); end
            non_stim = ~ismember(val,obj.Tracker.DAQ.stimulation_available);
            if any(non_stim), error('Stimulation #%d is not assigned.',val(find(non_stim,1))); end
            if ~isempty(obj.Channel) && all(val==obj.Channel), return, end
            obj.Channel = val;
            init_analogoutput(obj);
        end
        function set.Waveform(obj,val)
            obj.Waveform = val;
            init_analogoutput(obj);
        end
        function set.Frequency(obj,val)
            if ~isscalar(val), error('Frequency must be a scalar.'); end
            if ~isempty(obj.Frequency) && val==obj.Frequency, return, end
            obj.Frequency = val;
            init_analogoutput(obj);
        end
        function set.WaveformNumber(obj,val)
            if ~isobject(obj.AO), error('Set the other properties (Channel, Waveform and Frequency) first.'); end %#ok<*MCSUP>
            if issending(obj.AO), stop(obj.AO,1); end
            obj.AO.ManualTriggerNextWF = val;
        end
        function val = get.WaveformNumber(obj)
            if ~isobject(obj.AO), error('Set the other properties (Channel, Waveform and Frequency) first.'); end
            val = obj.AO.ManualTriggerNextWF;
        end
        
        function init(obj,p)
            init@mlstimulus(obj,p);
            if ~isobject(obj.AO) || ~obj.AO.Running, init_analogoutput(obj); end
            if ~obj.Trigger
                obj.Triggered = true;
                register(obj.AO);
                mglactivategraphic(obj.Tracker.Screen.Stimulation(:,obj.Channel),true);
            end
        end
        function fini(obj,p)
            fini@mlstimulus(obj,p);
            if obj.OffAtSceneEnd, stop(obj.AO); end
            mglactivategraphic(obj.Tracker.Screen.Stimulation(:,obj.Channel),false);
            p.stimfile(obj.Filepath);
        end
        function continue_ = analyze(obj,p)
            analyze@mlstimulus(obj,p);
            if obj.Triggered
                if 0<p.scene_frame()
                    obj.Success = ~obj.AO.Sending;
                    if obj.Success, mglactivategraphic(obj.Tracker.Screen.Stimulation(:,obj.Channel),false); end
                end
            else
                if obj.Adapter.Success
                    obj.Triggered = true;
                    register(obj.AO);
                    mglactivategraphic(obj.Tracker.Screen.Stimulation(:,obj.Channel),true);
                    p.eventmarker(obj.EventMarker);
                end
            end
            continue_ = ~obj.Success;
        end
    end
    methods (Access = protected)
        function init_analogoutput(obj)
            obj.Filepath = [];
            if isempty(obj.Channel) || isempty(obj.Waveform), return, end
            if ischar(obj.Waveform)
                err = []; try [wf.y,wf.fs] = eval(obj.Waveform); catch err, end
                if ~isempty(err), obj.Filepath{end+1} = obj.Tracker.validate_path(obj.Waveform); wf = load(obj.Filepath{end}); end
                data = wf.y;
                if isfield(wf,'fs'), obj.Frequency = wf.fs; end
            else
                data = obj.Waveform;
            end
            if isempty(obj.Frequency), return, end
            
            daq = [obj.Tracker.DAQ.Stimulation{obj.Channel}];
            if 1~=length(unique({daq.Name})), error('All analogoutput channels must be on the same DAQ device. If not, create another Stimulator.'); end
            
            obj.AO = daq(1);
            if obj.AO.Running, stop(obj.AO); end
            if 0~=obj.AO.SamplesAvailable, stop(obj.AO); end
            obj.AO.TriggerType = 'Manual';
            obj.AO.SampleRate = obj.Frequency;
            obj.AO.ManualTriggerWFOutput = 'Chosen';
            obj.AO.RegenerationMode = 1;
            
            nstim = length(obj.Channel);     % # of stimulations
            nchan = length(obj.AO.Channel);  % # of analogoutput channels
            if ~iscell(data), data = {data}; end
            for m=1:length(data)
                if ~any(size(data{m})==nstim), error('The size of waveform does not match the number of channels.'); end
                if size(data{m},2)~=nstim, data{m} = data{m}'; end
                output = zeros(size(data{m},1),nchan);
                idx = zeros(1,nstim);
                for n=1:nstim, idx(n) = obj.AO.Channel(strcmp(sprintf('Stimulation%d',obj.Channel(n)),obj.AO.Channel.ChannelName)).Index; end
                output(:,idx) = data{m};
                putdata(obj.AO,output);
            end
            
            obj.AO.ManualTriggerNextWF = 1;
            start(obj.AO);
        end
    end
end
