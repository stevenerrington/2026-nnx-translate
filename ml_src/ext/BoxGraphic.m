classdef BoxGraphic < mlpaintable
    methods
        function obj = BoxGraphic(varargin)
            obj@mlpaintable(varargin{:});
            obj.List = { [1 1 1], [NaN NaN NaN], [10 10], [0 0], 1, 0 };  % edgecolor, facecolor, size, position, scale, angle
        end
    end
    methods (Access = protected)
        function create_graphic(obj)
            destroy_graphic(obj);
            obj.EdgeColor = [];  % To ensure new property values are applied to all newly created graphics
            obj.FaceColor = [];
            obj.Size = [];
            obj.Position = [];
            obj.Scale = [];
            obj.Angle = [];
            obj.Zorder = [];

            [nobj,col] = size(obj.List);
            list = cell(nobj,6);
            list(:,1:col) = obj.List;
            obj.GraphicID = NaN(1,nobj);

            EdgeColor = NaN(nobj,3);
            FaceColor = NaN(nobj,3);
            Size = zeros(nobj,2);
            Position = zeros(nobj,2);
            Scale = ones(nobj,2);
            Angle = zeros(nobj,1);
            for m=1:nobj
                if ~isempty(list{m,1}), EdgeColor(m,:) = list{m,1}(1:3); end
                if ~isempty(list{m,2}), FaceColor(m,:) = list{m,2}; end
                if ~isempty(list{m,3}), Size(m,:) = list{m,3}; end
                if ~isempty(list{m,4}), Position(m,:) = list{m,4}; end
                if ~isempty(list{m,5}), Scale(m,:) = list{m,5}; end
                if ~isempty(list{m,6}), Angle(m,:) = list{m,6}; end

                obj.GraphicID(m) = mgladdbox([EdgeColor(m,:); FaceColor(m,:)],Size(m,:));
            end
            obj.Enable = true(nobj,1);
            obj.EdgeColor = EdgeColor;
            obj.FaceColor = FaceColor;
            obj.Size = Size;
            obj.Position = Position;
            obj.Scale = Scale;
            obj.Angle = Angle;
            obj.Zorder = zeros(nobj,1);

            mglactivategraphic(obj.GraphicID,false);
        end
    end
end
