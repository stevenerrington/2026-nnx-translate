classdef TriggerTimer < mladapter
    properties
        Delay
    end
    properties (Access = protected)
        EndTime
    end
    methods
        function obj = TriggerTimer(varargin)
            obj@mladapter(varargin{:});
        end
        
        function set.Delay(obj,val)
            obj.Delay = val;
            obj.EndTime = val - obj.Tracker.Screen.FrameLength; %#ok<*MCSUP>
        end
        
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            obj.Success = 0==obj.Delay || obj.EndTime < p.trialtime() - p.FirstFlipTime;  % p.FirstFlipTime is NaN at Frame 0, which makes Success false.
            continue_ = ~obj.Success;
        end
    end
end
