classdef TimeCounter < mladapter
    properties
        Duration = 0
    end
    properties (Access = protected)
        EndTime
    end
    methods
        function obj = TimeCounter(varargin)
            obj@mladapter(varargin{:});
        end
        function set.Duration(obj,val)
            obj.Duration = val;
            obj.EndTime = val - 2*obj.Tracker.Screen.FrameLength; %#ok<MCSUP> 
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            if isnan(p.FirstFlipTime)  % p.FirstFlipTime is NaN at Frame 0
                obj.Success = obj.Duration <= obj.Tracker.Screen.FrameLength;
            else
                obj.Success = obj.EndTime < p.trialtime() - p.FirstFlipTime;
            end
            continue_ = ~obj.Success;
        end
    end
end
