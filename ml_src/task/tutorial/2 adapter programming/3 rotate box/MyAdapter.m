classdef MyAdapter < mladapter
    properties
        endtime
    end
    properties (SetAccess = protected)
        id
    end
    methods
        function obj = MyAdapter(varargin)
            obj@mladapter(varargin{:});
        end
%         function delete(obj)
%         end
        
        function init(obj,p)
            init@mladapter(obj,p);
            
            obj.id = mgladdbox([1 1 1; 1 1 1], [100 100]);
            mglsetproperty(obj.id, ...
                'origin', obj.Tracker.Screen.SubjectScreenHalfSize);
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            
            mgldestroygraphic(obj.id);
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            elapsed = p.scene_time();
            continue_ = elapsed < obj.endtime;
            p.dashboard(1,sprintf('Elapsed time: %4.0f ms', elapsed));
            
            angle = mod(elapsed,360);              % Angle to rotate the box at
            mglsetproperty(obj.id,'angle',angle);  % Change the angle of the box
        end
%         function draw(obj,p)
%             draw@mladapter(obj,p);
%         end
    end
end
