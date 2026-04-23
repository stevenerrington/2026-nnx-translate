classdef CircularOpticalFlow < mladapter
    properties
        AngularSpeed = 180   % degees per sec
        ApertureRadius = 10  % in degrees
        DotColor = [1 1 1]   % [r g b]
        DotSize = 0.5        % in degrees
        NumDot = 100
    end
    properties (SetAccess = protected)
        GraphicID
    end
    properties (Access = protected)
        Pos
        Rot
    end
    
    methods
        function obj = CircularOpticalFlow(varargin)
            obj@mladapter(varargin{:});
            create_graphic(obj);
        end
        function delete(obj), mgldestroygraphic(obj.GraphicID); end
        function set.NumDot(obj,val), obj.NumDot = val; create_graphic(obj); end
        
        function init(obj,p)
            init@mladapter(obj,p);

            % initial dot positions
            r = obj.ApertureRadius * rand(obj.NumDot,1);
            t = 360 * rand(obj.NumDot,1);
            obj.Pos = [r.*cosd(t) r.*sind(t)];

            % adjust dot size and color for depth effect
            depth = sort(rand(obj.NumDot,1));
            sz = round(depth * obj.DotSize * obj.Tracker.Screen.PixelsPerDegree);
            color = repmat(depth,1,3) .* repmat(obj.DotColor,obj.NumDot,1);
            mglsetproperty(obj.GraphicID,'active',true,'size',sz,'color',color);

            % trigonometric function values for rotation
            angle = depth * obj.AngularSpeed / obj.Tracker.Screen.RefreshRate;
            obj.Rot = [cosd(angle) sind(angle)];
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.GraphicID,false);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            obj.Pos = [obj.Pos(:,1).*obj.Rot(:,1)-obj.Pos(:,2).*obj.Rot(:,2) obj.Pos(:,1).*obj.Rot(:,2)+obj.Pos(:,2).*obj.Rot(:,1)];
            mglsetproperty(obj.GraphicID,'origin',obj.Tracker.CalFun.deg2pix(obj.Pos));
        end
    end
    methods (Access = protected)
        function create_graphic(obj)
            mgldestroygraphic(obj.GraphicID);
            for m=obj.NumDot:-1:1, obj.GraphicID(m) = mgladdcircle([1 1 1; 1 1 1],5); end
        end
    end
end
