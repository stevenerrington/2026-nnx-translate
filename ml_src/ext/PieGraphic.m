classdef PieGraphic < mlpaintable
    properties
        StartDegree
        CenterAngle
    end

    methods
        function obj = PieGraphic(varargin)
            obj@mlpaintable(varargin{:});
            obj.List = { [1 1 1], [NaN NaN NaN], [10 10], [0 0], 45, 90, 1, 0 };  % edgecolor, facecolor, size, position, startdegree, centerangle, scale, angle
        end

        function set.StartDegree(obj,val), row = numchk(obj,val,'StartDegree'); mglsetproperty(obj.GraphicID(row),'startdegree',val(row,:)); obj.StartDegree = val; end
        function set.CenterAngle(obj,val), row = numchk(obj,val,'CenterAngle'); mglsetproperty(obj.GraphicID(row),'centerangle',val(row,:)); obj.CenterAngle = val; end
    end

    methods (Access = protected)
        function create_graphic(obj)
            destroy_graphic(obj);
            obj.EdgeColor = [];  % To ensure new property values are applied to all newly created graphics
            obj.FaceColor = [];
            obj.Size = [];
            obj.Position = [];
            obj.StartDegree = [];
            obj.CenterAngle = [];
            obj.Scale = [];
            obj.Angle = [];
            obj.Zorder = [];

            [nobj,col] = size(obj.List);
            list = cell(nobj,8);
            list(:,1:col) = obj.List;
            obj.GraphicID = NaN(1,nobj);

            EdgeColor = NaN(nobj,3);
            FaceColor = NaN(nobj,3);
            Size = zeros(nobj,2);
            Position = zeros(nobj,2);
            StartDegree = zeros(nobj,1); %#ok<*PROP>
            CenterAngle = zeros(nobj,1);
            Scale = ones(nobj,2);
            Angle = zeros(nobj,1);
            for m=1:nobj
                if ~isempty(list{m,1}), EdgeColor(m,:) = list{m,1}(1:3); end
                if ~isempty(list{m,2}), FaceColor(m,:) = list{m,2}; end
                if ~isempty(list{m,3}), Size(m,:) = list{m,3}; end
                if ~isempty(list{m,4}), Position(m,:) = list{m,4}; end
                if ~isempty(list{m,5}), StartDegree(m,:) = list{m,5}; end
                if ~isempty(list{m,6}), CenterAngle(m,:) = list{m,6}; end
                if ~isempty(list{m,7}), Scale(m,:) = list{m,7}; end
                if ~isempty(list{m,8}), Angle(m,:) = list{m,8}; end

                obj.GraphicID(m) = mgladdpie([EdgeColor(m,:); FaceColor(m,:)],Size(m,:),StartDegree(m,:),CenterAngle(m,:));
            end
            obj.Enable = true(nobj,1);
            obj.EdgeColor = EdgeColor;
            obj.FaceColor = FaceColor;
            obj.Size = Size;
            obj.Position = Position;
            obj.StartDegree = StartDegree;
            obj.CenterAngle = CenterAngle;
            obj.Scale = Scale;
            obj.Angle = Angle;
            obj.Zorder = zeros(nobj,1);

            mglactivategraphic(obj.GraphicID,false);
        end
    end
end
