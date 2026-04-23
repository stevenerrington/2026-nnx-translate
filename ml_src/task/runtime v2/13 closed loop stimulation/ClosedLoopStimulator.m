classdef ClosedLoopStimulator < mladapter
    properties
        Channel
        Waveform
        Frequency
    end
    properties (SetAccess = protected)
    end
    properties (Access = protected)
        AO
        Replaying
    end
    
    methods
        function obj = ClosedLoopStimulator(varargin)
            obj@mladapter(varargin{:});
            obj.Replaying = 2==obj.Tracker.DataSource;
        end
        
        function set.Channel(obj,val)
            if ~isscalar(val), error('Channel must be a scalar.'); end
            non_stim = ~ismember(val,obj.Tracker.DAQ.stimulation_available);
            if any(non_stim), error('Stimulation #%d is not assigned.',val(find(non_stim,1))); end
            obj.Channel = val;
        end
        function set.Waveform(obj,val)
            obj.Waveform = val(:);
        end
        function set.Frequency(obj,val)
            if ~isscalar(val), error('Frequency must be a scalar.'); end
            obj.Frequency = val;
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            if ~obj.Replaying
                obj.AO = p.DAQ.Stimulation{obj.Channel};
                chan = strcmp(obj.AO.Channel.ChannelName,sprintf('Stimulation%d',obj.Channel));
                nchan = length(obj.AO.Channel);
                obj.AO.SampleRate = obj.Frequency;
                obj.AO.RepeatOutput = Inf;
                obj.AO.RegenerationMode = 1;
                output = zeros(size(obj.Waveform,1),nchan);
                output(:,chan) = obj.Waveform;
                putdata(obj.AO,output);
                start(obj.AO);
            end
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.Tracker.Screen.Stimulation(:,obj.Channel),false);
            if ~obj.Replaying, stop(obj.AO,22); end
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            if obj.Replaying, return, end
            if obj.Success
                if ~obj.AO.Sending, trigger(obj.AO); end
            else
                if obj.AO.Sending, stop(obj.AO,24); end
            end
        end
        function draw(obj,p)
            draw@mladapter(obj,p);
            if obj.Success
                mglactivategraphic(obj.Tracker.Screen.Stimulation(:,obj.Channel),true);
            else
                mglactivategraphic(obj.Tracker.Screen.Stimulation(:,obj.Channel),false);
            end
        end
    end
end
