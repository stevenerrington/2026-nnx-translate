classdef MyTube < mladapter
    properties
        Color = [1 1 1]
        Fill = false
        Size = 200
        DepthLevel = 10
    end
    properties (SetAccess = protected)
        GraphicID
    end
    
    methods
        function obj = MyTube(varargin)
            obj@mladapter(varargin{:});
            create_graphic(obj);
       end
        function delete(obj), mgldestroygraphic(obj.GraphicID); end
        function set.Color(obj,val), obj.Color = val; create_graphic(obj); end
        function set.Fill(obj,val), obj.Fill = val; create_graphic(obj); end
        function set.Size(obj,val), obj.Size = val; create_graphic(obj); end
        function set.DepthLevel(obj,val), obj.DepthLevel = val; create_graphic(obj); end
        
        function init(obj,p)
            init@mladapter(obj,p);
            mglactivategraphic(obj.GraphicID,true);
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.GraphicID,false);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            data = obj.Tracker.XYData;
            if isempty(data), return, end
            
            deg = obj.Tracker.CalFun.pix2deg(data(end,:));
            x = linspace(deg(1),0,obj.DepthLevel)';
            y = linspace(deg(2),0,obj.DepthLevel)';
            pos = obj.Tracker.CalFun.deg2pix([x y]);
            mglsetorigin(obj.GraphicID,pos);
        end
    end
    methods (Access = protected)
        function create_graphic(obj)
            mgldestroygraphic(obj.GraphicID);
            color = [linspace(obj.Color(1),0,obj.DepthLevel)' linspace(obj.Color(2),0,obj.DepthLevel)' linspace(obj.Color(3),0,obj.DepthLevel)'];
            sz = linspace(obj.Size,0,obj.DepthLevel);
            for m=1:obj.DepthLevel
                if obj.Fill, c = [color(m,:); color(m,:)]; else, c = color(m,:); end
                obj.GraphicID(m) = mgladdcircle(c,sz(m));
            end
        end
    end
end
