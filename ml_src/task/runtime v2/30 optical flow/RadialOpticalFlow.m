classdef RadialOpticalFlow < mladapter
    properties
        ApertureRadius = 10  % in degrees
        DotColor = [1 1 1]   % [r g b]
        DotSize = 0.5        % in degrees
        NumDot = 100
        Speed = 0.1          % -1 to 1
    end
    properties (SetAccess = protected)
        GraphicID
    end
    properties (Access = protected)
        r
        t
        Depth
    end
    
    methods
        function obj = RadialOpticalFlow(varargin)
            obj@mladapter(varargin{:});
            create_graphic(obj);
        end
        function delete(obj), mgldestroygraphic(obj.GraphicID); end
        function set.NumDot(obj,val), obj.NumDot = val; create_graphic(obj); end
        
        function init(obj,p)
            init@mladapter(obj,p);

            % initial dot positions
            obj.r = obj.ApertureRadius * (1-rand(obj.NumDot,1).^2);
            obj.t = 360 * rand(obj.NumDot,1);
            obj.Depth = sort(rand(obj.NumDot,1));

            mglactivategraphic(obj.GraphicID,true);
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.GraphicID,false);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            obj.Depth = obj.Depth + obj.Speed / obj.Tracker.Screen.RefreshRate;
            row = obj.Depth<0; obj.Depth(row) = obj.Depth(row) + 1;
            row = 1<obj.Depth; obj.Depth(row) = obj.Depth(row) - 1;
            
            % adjust dot properties for depth effect
            sz = round(obj.Depth * obj.DotSize * obj.Tracker.Screen.PixelsPerDegree);
            color = repmat(obj.Depth,1,3) .* repmat(obj.DotColor,obj.NumDot,1);
            zorder = round(obj.Depth*obj.NumDot);
            radius = obj.r .* obj.Depth;
            pos = obj.Tracker.CalFun.deg2pix([radius.*cosd(obj.t) radius.*sind(obj.t)]);

            mglsetproperty(obj.GraphicID,'size',sz,'color',color,'zorder',zorder,'origin',pos);
        end
    end
    methods (Access = protected)
        function create_graphic(obj)
            mgldestroygraphic(obj.GraphicID);
            for m=obj.NumDot:-1:1, obj.GraphicID(m) = mgladdcircle([1 1 1; 1 1 1],5); end
        end
    end
end
