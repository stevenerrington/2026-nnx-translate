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

            click = obj.Tracker.ClickData;  % Get button click data from the tracker
            if click{1}(end)                % If the last data point of the first button is true ("clicked"),
                angle = mod(elapsed,360);   % then rotate the box.
                mglsetproperty(obj.id,'angle',angle);
            end
        end
        function draw(obj,p)
            draw@mladapter(obj,p);

            data = obj.Tracker.XYData;
            if ~isempty(data)
                mglsetproperty(obj.id,'origin',data(end,:));
            end
            p.dashboard(2,sprintf('Sample count: %d',size(data,1)));
        end
    end
end
