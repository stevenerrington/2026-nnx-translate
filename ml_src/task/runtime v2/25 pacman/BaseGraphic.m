classdef BaseGraphic < mladapter
    properties
        Rect
        Color = [1 0.6824 0.7882]
    end
    properties (SetAccess = protected)
        GraphicID
    end
    properties (Access = protected)
    end

    methods
        function obj = BaseGraphic(varargin)
            obj@mladapter(varargin{:});
        end
        function delete(obj), destroy_graphic(obj); end
        
        function set.Rect(obj,val)
            obj.Rect = val;
            create_graphic(obj);
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            if isempty(obj.GraphicID), error('Base walls are not set.'); end
            mglactivategraphic(obj.GraphicID,true);
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.GraphicID,false);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
        end
        function draw(obj,p)
            draw@mladapter(obj,p);
        end
        
        function create_graphic(obj)
            destroy_graphic(obj);
            n = size(obj.Rect,1);
            obj.GraphicID = NaN(1,n);
            for m=1:n
                rc = obj.Rect(m,:);
                obj.GraphicID(m) = mgladdbox([obj.Color; obj.Color],rc(3:4));
                mglsetorigin(obj.GraphicID(m),rc(1:2)+0.5*rc(3:4));
            end
        end
        function destroy_graphic(obj), mgldestroygraphic(obj.GraphicID); end
    end
end
