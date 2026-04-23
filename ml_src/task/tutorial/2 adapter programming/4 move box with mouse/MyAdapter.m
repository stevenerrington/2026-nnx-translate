% draw() is called, after analyze() of all adapters in the chain is called
% first. So the code dependent on the analysis of the other adapters can be
% put in draw(). Otherwise, it is okay to run all the code in analyze()
% without using draw().

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
            
            angle = mod(elapsed,360);
            mglsetproperty(obj.id,'angle',angle);
        end
        function draw(obj,p)
            draw@mladapter(obj,p);

            data = obj.Tracker.XYData;  % Get XY data from the tracker of the adapter chain
            if ~isempty(data)           % Move the box to the last position of the XY tracker
                mglsetproperty(obj.id,'origin',data(end,:));
            end
            p.dashboard(2,sprintf('Sample count: %d',size(data,1)));  % Display the number of XY samples
        end
    end
end
