% If the SetAccess of a property is set to protected, the property becomes
% read-only. The value of a read-only property cannot be changed in the
% timing script.
%
% The initial values of writable properties are stored when create_scene()
% is called so that the scene can be reconstructed later.

% The constructor is called when the class is declared in the timing
% script; delete(), when the class is destroyed at the end of the timing
% script.
%
% init() and fini() are called only once, when a scene starts and ends,
% respectively.
%
% analyze() and draw() are called every frame during run_scene(). If
% analyze() returns false (i.e., when continue_ is false), the scene ends
% after the current frame.

classdef MyAdapter < mladapter
    properties                          % readable and writable
        endtime
    end
    properties (SetAccess = protected)  % read-only property
        id  % MGL object ID of the box; should not be overwritten.
    end
    methods
        function obj = MyAdapter(varargin)
            obj@mladapter(varargin{:});
        end
%         function delete(obj)
%         end
        
        function init(obj,p)
            init@mladapter(obj,p);
            
            obj.id = mgladdbox([1 1 1; 1 1 1], [100 100]);  % Add a white box of 100px x 100px
            mglsetproperty(obj.id, ...                      % Move the box to the center
                'origin', obj.Tracker.Screen.SubjectScreenHalfSize);
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            
            mgldestroygraphic(obj.id);                      % Destroy the box
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            elapsed = p.scene_time();
            continue_ = elapsed < obj.endtime;
            p.dashboard(1,sprintf('Elapsed time: %4.0f ms', elapsed));
        end
%         function draw(obj,p)
%             draw@mladapter(obj,p);
%         end
    end
end
