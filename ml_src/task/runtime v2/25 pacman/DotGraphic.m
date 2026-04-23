classdef DotGraphic < mladapter
    properties
        Position
        Size = 8
        Color = [1 0.7882 0.0549]
    end
    properties (SetAccess = protected)
        GraphicID
    end
    properties (Access = protected)
    end

    methods
        function obj = DotGraphic(varargin)
            obj@mladapter(varargin{:});
        end
        function delete(obj), destroy_graphic(obj); end
        
        function set.Position(obj,val)
            obj.Position = val;
            create_graphic(obj);
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            if isempty(obj.GraphicID), error('Dots are not set.'); end
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
            n = size(obj.Position,1);
            obj.GraphicID = NaN(1,n);
            for m=1:n
                obj.GraphicID(m) = mgladdcircle([obj.Color; obj.Color],obj.Size);
                mglsetorigin(obj.GraphicID(m),obj.Position(m,:));
            end
        end
        function destroy_graphic(obj), mgldestroygraphic(obj.GraphicID); end
        function remove_graphic(obj,idx)
            idx(length(obj.GraphicID)<idx) = [];
            mgldestroygraphic(obj.GraphicID(idx));
            obj.GraphicID(idx) = [];
        end
    end
end
