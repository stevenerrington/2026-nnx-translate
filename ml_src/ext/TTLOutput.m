classdef TTLOutput < mlstimulus
    properties
        Port
        Delay = 0
        Duration = 0
    end
    properties (Access = protected)
        IsTimed
        Timer
        StartTime
        EndTime
    end

    methods
        function obj = TTLOutput(varargin)
            obj@mlstimulus(varargin{:});
        end

        function set.Port(obj,val)
            if ~isvector(val), error('TTL Port must be a vector'); end
            non_ttl = ~ismember(val,obj.Tracker.DAQ.ttl_available);
            if any(non_ttl), error('TTL #%d is not assigned',val(find(non_ttl,1))); end
            obj.Port = val;
        end

        function init(obj,p)
            init@mlstimulus(obj,p);
            obj.IsTimed = any(0<obj.Duration);
            nport = length(obj.Port);
            obj.StartTime = obj.Delay;
            obj.StartTime(end+1:nport) = obj.StartTime(end);
            obj.StartTime = obj.StartTime(1:nport);
            obj.EndTime = obj.Duration;
            obj.EndTime(end+1:nport) = obj.EndTime(end);
            obj.EndTime = obj.StartTime + obj.EndTime(1:nport);

            mglactivategraphic(obj.Tracker.Screen.TTL(1,obj.Port),true);
            if ~obj.Trigger
                obj.Triggered = true;
                obj.Timer = tic;
                if obj.IsTimed
                    register([p.DAQ.TTL{obj.Port}],'TimedTTL',p.DAQ.TTLInvert(obj.Port),obj.StartTime,obj.EndTime);
                    t = toc(obj.Timer)*1000; on = obj.StartTime<=t & t<obj.EndTime;
                    mglactivategraphic(obj.Tracker.Screen.TTL(2,obj.Port),on);
                else
                    register([p.DAQ.TTL{obj.Port}],'TTL',p.DAQ.TTLInvert(obj.Port));
                    mglactivategraphic(obj.Tracker.Screen.TTL(2,obj.Port),true);
                end
            end
        end
        function fini(obj,p)
            fini@mlstimulus(obj,p);
            mglactivategraphic(obj.Tracker.Screen.TTL(:,obj.Port),false);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mlstimulus(obj,p);
            obj.Success = obj.Adapter.Success;
            
            if ~obj.Triggered && obj.Success
                obj.Triggered = true;
                obj.Timer = tic;
                if obj.IsTimed
                    register([p.DAQ.TTL{obj.Port}],'TimedTTL',p.DAQ.TTLInvert(obj.Port),obj.StartTime,obj.EndTime);
                else
                    register([p.DAQ.TTL{obj.Port}],'TTL',p.DAQ.TTLInvert(obj.Port));
                    mglactivategraphic(obj.Tracker.Screen.TTL(2,obj.Port),true);
                    p.eventmarker(obj.EventMarker);
                end
            end
            if obj.IsTimed
                if obj.Triggered
                    t = toc(obj.Timer)*1000; on = obj.StartTime<=t & t<obj.EndTime;
                    mglactivategraphic(obj.Tracker.Screen.TTL(2,obj.Port),on);
                    obj.Success = all(obj.EndTime<=t);
                else
                    obj.Success = false;
                end
                continue_ = ~obj.Success;
            end
        end
    end
end
