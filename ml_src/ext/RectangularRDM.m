classdef RectangularRDM < mlgraphic
    properties
        Position   % [x,y] in degrees
        Zorder
        
        Size       % aperture size; [width heght] in degrees
        Coherence  % 0 - 100
        Direction  % degree
        Speed      % degrees per second
        
        NumDot
        DotSize    % in degrees
        DotColor
        DotShape   % 'square' or 'circle'
        Interleaf  % number of alternating frames
    end
    properties (Access = protected)
        DotPosition
        ScrPosition
        ScrHalfSize
        ScrDisplacement
        NumMovingDot
        Update
        PrevFrame
    end
    
    methods
        function obj = RectangularRDM(varargin)
            obj@mlgraphic(varargin{:});
            obj.List = { [0 0], [5 5], 70, 0, 5, 100, 0.15, [1 1 1], 'square', 3 };
        end

        function set.Position(obj,val), row = numchk(obj,val,'Position'); obj.Position = val; update_ScrPosition(obj,row); end %#ok<*MCSUP>
        function set.Zorder(obj,val),   row = numchk(obj,val,'Zorder'); obj.Zorder = val; for m=row, mglsetproperty(obj.GraphicID{m},'zorder',val(m,:)); end, end
        function val = get.Position(obj), val = obj.Position; end
        function val = get.Zorder(obj), val = obj.Zorder; end

        function set.Size(obj,val), if size(obj.Size,1)==numel(val), val = repmat(val(:),1,2); end, row = numchk(obj,val,'Size'); obj.Size = val; update_DotPosition(obj,row); end
        function set.Coherence(obj,val), row = numchk(obj,val,'Coherence'); obj.Coherence = val; update_ScrDisplacement(obj,row); end
        function set.Direction(obj,val), row = numchk(obj,val,'Direction'); obj.Direction = val; update_ScrDisplacement(obj,row); end
        function set.Speed(obj,val), row = numchk(obj,val,'Speed'); obj.Speed = val; update_ScrDisplacement(obj,row); end
        function set.NumDot(obj,val), row = numchk(obj,val,'NumDot'); obj.NumDot = val; update_DotID(obj,row); update_DotPosition(obj,row); update_ScrPosition(obj,row); update_ScrDisplacement(obj,row); end
        function set.DotSize(obj,val), row = numchk(obj,val,'DotSize'); obj.DotSize = val; update_DotSize(obj,row); end
        function set.DotColor(obj,val), row = numchk(obj,val,'DotColor'); obj.DotColor = val; update_DotColor(obj,row); end
        function set.DotShape(obj,val), [row,val] = strchk(obj,val,'DotShape'); obj.DotShape = val; update_DotID(obj,row); end
        function set.Interleaf(obj,val), row = numchk(obj,val,'Interleaf'); obj.Interleaf = val; update_DotPosition(obj,row); update_ScrDisplacement(obj,row); end

        function animate_init(obj,~,~)
			if 2<nargin, obj.Triggered = true; end
            obj.PrevFrame = NaN;
        end
        function animate_draw(obj,p,idx)
            CurrentFrame = p.scene_frame();
            if obj.PrevFrame==CurrentFrame, return, else, obj.PrevFrame = CurrentFrame; end  % draw only once in one frame
            
            if obj.Triggered
                if nargin<3, idx = 1:numel(obj.GraphicID); end
                for m=idx
                    % draw dots for the next frame
                    interleaf = mod(CurrentFrame,obj.Interleaf(m,1)) + 1;
                    mglsetorigin(obj.GraphicID{m,1},obj.DotPosition{m,1}{interleaf}+obj.ScrPosition{m});

                    % pick dots that will move coherently
                    random_order = randperm(obj.NumDot(m,1));
                    moving_dots = random_order(1:obj.NumMovingDot(m,1));
                    random_dots = random_order(obj.NumMovingDot(m,1)+1:obj.NumDot(m,1));

                    % move them to new positions
                    new_position = obj.DotPosition{m,1}{interleaf}(moving_dots,:) + obj.ScrDisplacement{m};
                    escaping_dots = new_position(:,1)<-obj.ScrHalfSize(m,1) | obj.ScrHalfSize(m,1)<new_position(:,1) | new_position(:,2)<-obj.ScrHalfSize(m,2) | obj.ScrHalfSize(m,2)<new_position(:,2);
                    new_position(escaping_dots,:) = obj.DotPosition{m,1}{interleaf}(moving_dots(escaping_dots),:) * [-1 0; 0 -1];
                    obj.DotPosition{m,1}{interleaf}(moving_dots,:) = new_position;

                    % move the rest of the dots to random positions
                    n = length(random_dots);
                    obj.DotPosition{m,1}{interleaf}(random_dots,:) = (rand(n,2) * 2 - 1) .* repmat(obj.ScrHalfSize(m,:),n,1);
                end
            end
        end

        function init(obj,p), init@mlgraphic(obj,p); animate_init(obj,p); end
        function draw(obj,p), draw@mlgraphic(obj,p); animate_draw(obj,p); end
    end
    
    methods (Access = protected)
        function create_graphic(obj)
            destroy_graphic(obj);
            
            [nobj,col] = size(obj.List);
            list = cell(nobj,10);
            list(:,1:col) = obj.List;
            obj.GraphicID = cell(nobj,1);
            
            Position = zeros(nobj,2); %#ok<*PROP>
            Size = 5*ones(nobj,2);
            Coherence = 100*ones(nobj,1);
            Direction = zeros(nobj,1);
            Speed = 5*ones(nobj,1);
            NumDot = 100*ones(nobj,1);
            DotSize = 0.15*ones(nobj,1);
            DotColor = ones(nobj,3);
            DotShape = repmat({'square'},nobj,1);
            Interleaf = 3*ones(nobj,1);
            for m=1:nobj
                if ~isempty(list{m,1}), Position(m,:) = list{m,1}; end
                if ~isempty(list{m,2}), Size(m,:) = list{m,2}; end
                if ~isempty(list{m,3}), Coherence(m,:) = list{m,3}; end
                if ~isempty(list{m,4}), Direction(m,:) = list{m,4}; end
                if ~isempty(list{m,5}), Speed(m,:) = list{m,5}; end
                if ~isempty(list{m,6}), NumDot(m,:) = list{m,6}; end
                if ~isempty(list{m,7}), DotSize(m,:) = list{m,7}; end
                if ~isempty(list{m,8}), DotColor(m,:) = list{m,8}; end
                if ~isempty(list{m,9}), if ischar(list{m,9}), DotShape{m} = list{m,9}; else, Interleaf(m,:) = list{m,9}; end, end
                if ~isempty(list{m,10}), Interleaf(m,:) = list{m,10}; end
            end
            obj.Update = false;
            obj.Enable = true(nobj,1);
            obj.Position = Position;
            obj.Zorder = zeros(nobj,1);
            obj.Size = Size;
            obj.Coherence = Coherence;
            obj.Direction = Direction;
            obj.Speed = Speed;
            obj.NumDot = NumDot;
            obj.DotSize = DotSize;
            obj.DotColor = DotColor;
            obj.DotShape = DotShape;
            obj.Interleaf = Interleaf;

            obj.DotPosition = cell(nobj,1);
            obj.ScrPosition = cell(nobj,1);
            obj.ScrHalfSize = zeros(nobj,2);
            obj.ScrDisplacement = cell(nobj,1);
            obj.NumMovingDot = zeros(nobj,1);

            obj.Update = true;
            update_DotID(obj,1:nobj);
            update_DotPosition(obj,1:nobj);
            update_ScrPosition(obj,1:nobj);
            update_ScrDisplacement(obj,1:nobj);
            
            for m=1:numel(obj.GraphicID), mglactivategraphic(obj.GraphicID{m},false); end
        end
        function update_DotSize(obj,row)  % DotSize
            if ~obj.Update, return, end
            for m=row, mglsetproperty(obj.GraphicID{m},'size',obj.Tracker.Screen.PixelsPerDegree*obj.DotSize(m,:)); end
        end
        function update_DotColor(obj,row)  % DotColor
            if ~obj.Update, return, end
            for m=row, mglsetproperty(obj.GraphicID{m},'color',obj.DotColor(m,:)); end
        end
        function update_DotID(obj,row)  % NumDot, DotShape
            if ~obj.Update, return, end
            for m=row
                mgldestroygraphic(obj.GraphicID{m});
                obj.GraphicID{m} = NaN(1,obj.NumDot(m,:));
                dotsize = obj.Tracker.Screen.PixelsPerDegree * obj.DotSize(m,:);
                for n=1:obj.NumDot(m,:)
                    switch lower(obj.DotShape{m}(1))
                        case 'c', obj.GraphicID{m}(n) = mgladdcircle([obj.DotColor(m,:); obj.DotColor(m,:)],dotsize);
                        otherwise, obj.GraphicID{m}(n) = mgladdbox([obj.DotColor(m,:); obj.DotColor(m,:)],dotsize);
                    end
                end
                mglactivategraphic(obj.GraphicID{m},false);
            end
        end
        function update_DotPosition(obj,row)  % Size, NumDot, Interleaf
            if ~obj.Update, return, end
            obj.ScrHalfSize = 0.5 * obj.Tracker.Screen.PixelsPerDegree * obj.Size;
            for m=row
                obj.DotPosition{m} = cell(1,obj.Interleaf(m,:));
                for n=1:obj.Interleaf(m,:)
                    obj.DotPosition{m}{n} = (rand(obj.NumDot(m,:),2) * 2 - 1) .* repmat(obj.ScrHalfSize(m,:),obj.NumDot(m,:),1);
                end
            end
        end
        function update_ScrPosition(obj,row)  % Position, NumDot
            if ~obj.Update, return, end
            for m=row, obj.ScrPosition{m} = repmat(obj.Tracker.CalFun.deg2pix(obj.Position(m,:)),obj.NumDot(m,:),1); end            
        end
        function update_ScrDisplacement(obj,row)  % Coherence, Direction, Speed, NumDot, Interleaf
            if ~obj.Update, return, end
            for m=row
                direction = mod(-obj.Direction(m,:),360);
                obj.NumMovingDot(m,:) = round(obj.NumDot(m,:) * obj.Coherence(m,:) / 100);
                d = obj.Tracker.Screen.PixelsPerDegree * obj.Speed(m,:) * obj.Interleaf(m,:) / obj.Tracker.Screen.RefreshRate;
                obj.ScrDisplacement{m} = repmat([d*cosd(direction) d*sind(direction)],obj.NumMovingDot(m,1),1);
            end
        end
    end
end
