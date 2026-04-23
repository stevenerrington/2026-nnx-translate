classdef TouchMarker < mladapter
    properties
        Polygon = { [1 1 1], [1 1 1], 0.5, [0 0], ...  % edgecolor, facecolor, size, position
            [0.5 1; 0.375 0.625; 0 0.625; 0.25 0.375; 0.125 0; 0.5 0.25; 0.875 0; 0.75 0.375; 1 0.625; 0.625 0.625], ...  % vertex
            1, 0 }  % scale, angle
    end
    properties (SetAccess = protected)
        Position  % degree positions of touches
    end
    properties (Access = protected)
        GraphicID
        LastData
    end

    methods
        function obj = TouchMarker(varargin)
            obj@mladapter(varargin{:});
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            obj.Position = [];
            obj.LastData = [];
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mgldestroygraphic(obj.GraphicID);
            obj.GraphicID = [];
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            data = obj.Tracker.XYData;
            if isempty(data), return, end
            
            data = [obj.LastData; data];
            lift_off = find(1==diff(isnan(data(:,1))),1,'last');
            if ~isempty(lift_off)
                xy = data(lift_off,1:2);                                   % xy position in pixels
                obj.Position(end+1,1:2) = obj.Tracker.CalFun.pix2deg(xy);  % convert to degrees and store

                color = [obj.Polygon{1}; obj.Polygon{2}];
                sz = obj.Polygon{3} * obj.Tracker.Screen.PixelsPerDegree;
                vertex = obj.Polygon{5};
                id = mgladdpolygon(color,sz,vertex);
                mglsetproperty(id,'origin',xy);
                obj.GraphicID(end+1) = id;
            end
            
            obj.LastData = data(end,:);
        end
    end
end
