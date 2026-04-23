classdef FrameCounter < mladapter
    properties
        NumFrame = 0
    end
    properties (Access = protected)
        EndFrame
    end
    properties (Hidden)
        Duration
    end
    methods
        function obj = FrameCounter(varargin)
            obj@mladapter(varargin{:});
        end
        function set.NumFrame(obj,val)
            obj.NumFrame = val;
            obj.EndFrame = val - 2; %#ok<*MCSUP> 
        end
        function set.Duration(obj,val)
            obj.Duration = val;
            obj.NumFrame = ceil(val/obj.Tracker.Screen.FrameLength);
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            obj.Success = obj.EndFrame < p.scene_frame();
            continue_ = ~obj.Success;
        end
    end
end
