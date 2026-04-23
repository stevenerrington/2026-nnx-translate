classdef TextGraphic < mlscalable
    properties
        Text = {''}
        FontFace = {''}
        FontSize                    % in points
        FontColor                   % [r g b]
        FontStyle = {''}            % bold, italic, underline, strikeout
        HorizontalAlignment = {''}  % center, right
        VerticalAlignment = {''}    % middle, bottom
    end
    properties (SetAccess = protected)
        Size
    end
    methods
        function obj = TextGraphic(varargin)
            obj@mlscalable(varargin{:});
            obj.List = { '', [0 0], 'Arial', 10, [1 1 1], 'normal', 'left', 'top', 1, 0 };  % text, position, fontface, fontsize, color, style, halign, valign, scale, angle
        end

        function set.Text(obj,val), [row,val] = strchk(obj,val,'Text'); for m=row, mglsetproperty(obj.GraphicID(m),'text',val{m}); end, obj.Text = val; end
        function set.FontFace(obj,val), [row,val] = strchk(obj,val,'FontFace'); for m=row, mglsetproperty(obj.GraphicID(m),'fontface',val{m}); end, obj.FontFace = val; end
        function set.FontSize(obj,val), row = numchk(obj,val,'FontSize'); mglsetproperty(obj.GraphicID(row),'fontsize',val(row,:)); obj.FontSize = val; end
        function set.FontColor(obj,val), row = numchk(obj,val,'FontColor'); mglsetproperty(obj.GraphicID(row),'color',val(row,:)); obj.FontColor = val; end
        function set.FontStyle(obj,val), [row,val] = strchk(obj,val,'FontStyle'); for m=row, mglsetproperty(obj.GraphicID(m),val{m}); end, obj.FontStyle = val; end
        function set.HorizontalAlignment(obj,val)
            [row,val] = strchk(obj,val,'HorizontalAlignment');
            for m=row
                switch lower(val{m})
                    case {2,'center'}, val{m} = 'center';
                    case {3,'right'}, val{m} = 'right';
                    otherwise, val{m} = 'left';  % {1,'left'}
                end
                mglsetproperty(obj.GraphicID(m),'halign',val{m});
            end
            obj.HorizontalAlignment = val;
        end
        function set.VerticalAlignment(obj,val)
            [row,val] = strchk(obj,val,'VerticalAlignment');
            for m=row
                switch lower(val{m})
                    case {2,'middle'}, val{m} = 'middle';
                    case {3,'bottom'}, val{m} = 'bottom';
                    otherwise, val{m} = 'top';  % {1,'top'}
                end
                mglsetproperty(obj.GraphicID(m),'valign',val{m});
            end
            obj.VerticalAlignment = val;
        end

        function val = get.Size(obj), nobj = numel(obj.GraphicID); val = zeros(nobj,2); for m=1:nobj, val(m,:) = mglgetproperty(obj.GraphicID(m),'size'); end, val = val ./ obj.Tracker.Screen.PixelsPerDegree; end
    end

    methods (Access = protected)
        function create_graphic(obj)
            destroy_graphic(obj);
            obj.Text = '';  % To ensure new property values are applied to all newly created graphics
            obj.Position = [];
            obj.FontFace = '';
            obj.FontSize = [];
            obj.FontColor = [];
            obj.FontStyle = '';
            obj.HorizontalAlignment = '';
            obj.VerticalAlignment = '';
            obj.Scale = [];
            obj.Angle = [];
            obj.Zorder = [];

            [nobj,col] = size(obj.List);
            list = cell(nobj,10);
            list(:,1:col) = obj.List;
            obj.GraphicID = NaN(1,nobj);

            Text = cell(nobj,1); %#ok<*PROP>
            Position = zeros(nobj,2);
            FontFace = repmat({'Arial'},nobj,1);
            FontSize = 10 * ones(nobj,1);
            FontColor = ones(nobj,3);
            FontStyle = repmat({'normal'},nobj,1);
            HorizontalAlignment = repmat({'left'},nobj,1);
            VerticalAlignment = repmat({'top'},nobj,1);
            Scale = ones(nobj,2);
            Angle = zeros(nobj,1);
            for m=1:nobj
                if ~isempty(list{m,1}), Text{m} = list{m,1}; end
                if ~isempty(list{m,2}), Position(m,:) = list{m,2}; end
                if ~isempty(list{m,3}), FontFace{m} = list{m,3}; end
                if ~isempty(list{m,4}), FontSize(m,:) = list{m,4}; end
                if ~isempty(list{m,5}), FontColor(m,:) = list{m,5}; end
                if ~isempty(list{m,6}), FontStyle{m} = list{m,6}; end
                if ~isempty(list{m,7}), HorizontalAlignment{m} = list{m,7}; end
                if ~isempty(list{m,8}), VerticalAlignment{m} = list{m,8}; end
                if ~isempty(list{m,9}), Scale(m,:) = list{m,9}; end
                if ~isempty(list{m,10}), Angle(m,:) = list{m,10}; end

                obj.GraphicID(m) = mgladdtext(Text{m});
            end
            obj.Enable = true(nobj,1);
            obj.Text = Text;
            obj.Position = Position;
            obj.FontFace = FontFace;
            obj.FontSize = FontSize;
            obj.FontColor = FontColor;
            obj.FontStyle = FontStyle;
            obj.HorizontalAlignment = HorizontalAlignment;
            obj.VerticalAlignment = VerticalAlignment;
            obj.Scale = Scale;
            obj.Angle = Angle;
            obj.Zorder = zeros(nobj,1);

            mglactivategraphic(obj.GraphicID,false);
        end
    end
end
