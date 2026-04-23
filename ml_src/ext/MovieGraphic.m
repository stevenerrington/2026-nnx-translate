classdef MovieGraphic < ImageGraphic
    properties
        Looping
        PlayPosition
        BaseMarker
    end
    properties (SetAccess = protected)
        Duration
    end
    properties (Hidden)
        MovieList
        PlaybackPosition
    end
    properties (Access = protected)
        MarkerIdx
        PrevMarker
    end
    
    methods
        function obj = MovieGraphic(varargin)
            obj@ImageGraphic(varargin{:});
        end
        function val = importnames(obj), val = ['MovieList'; fieldnames(obj); 'PlaybackPosition']; end
        
        function set.Looping(obj,val), row = numchk(obj,val,'Looping'); mglsetproperty(obj.GraphicID(row),'looping',val(row,:)); obj.Looping = val; end
        function val = get.Looping(obj), nobj = numel(obj.GraphicID); val = NaN(nobj,1); for m=1:nobj, val(m) = mglgetproperty(obj.GraphicID(m),'looping'); end, end
        function set.PlayPosition(obj,val), row = numchk(obj,val,'PlayPosition'); mglsetproperty(obj.GraphicID(row),'seek',val(row,:)/1000); end
        function val = get.PlayPosition(obj), nobj = numel(obj.GraphicID); val = NaN(nobj,1); for m=1:nobj, val(m) = mglgetproperty(obj.GraphicID(m),'currentposition')*1000; end, end
        function set.BaseMarker(obj,val), numchk(obj,val,'BaseMarker'); obj.BaseMarker = val; end

        function val = get.Duration(obj), nobj = numel(obj.GraphicID); val = NaN(nobj,1); for m=1:nobj, val(m) = mglgetproperty(obj.GraphicID(m),'duration'); end, val = val * 1000; end
        
        function set.MovieList(obj,val), obj.List = val; end %#ok<*MCSUP>
        function val = get.MovieList(obj), val = obj.List; end
        function set.PlaybackPosition(obj,val), obj.PlayPosition = val; end
        function val = get.PlaybackPosition(obj), val = obj.PlayPosition; end

        function init(obj,p)
            init@ImageGraphic(obj,p);
            obj.MarkerIdx = find(~isnan(obj.BaseMarker'));
            obj.PrevMarker = NaN(1,length(obj.MarkerIdx));
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@ImageGraphic(obj,p);
            if ~isempty(obj.MarkerIdx)
                marker = obj.PrevMarker;
                for m=1:length(obj.MarkerIdx), marker(m) = mglgetproperty(obj.GraphicID(obj.MarkerIdx(m)),'framecount'); end
                idx = marker~=obj.PrevMarker;
                p.eventmarker(obj.BaseMarker(obj.MarkerIdx(idx))' + marker(idx));
                obj.PrevMarker = marker;
            end
        end
    end
    
    methods (Access = protected)
        function create_graphic(obj)
            destroy_graphic(obj);
            obj.Position = [];  % To ensure new property values are applied to all newly created graphics
            obj.Looping = [];
            obj.Scale = [];
            obj.Angle = [];
            obj.Zorder = [];
            obj.Filepath = [];
            
            [nobj,col] = size(obj.List);
            list = cell(nobj,5);
            list(:,1:col) = obj.List;
            obj.GraphicID = NaN(1,nobj);

            Position = zeros(nobj,2); %#ok<*PROP>
            Looping = false(nobj,1);
            Scale = ones(nobj,2);
            Angle = zeros(nobj,1);
            for m=1:nobj
                if isempty(list{m,1}), continue, end
                if iscell(list{m,1})
                   if 1<length(list{m,1}), error('Too many movies in Row #%d. Please put one movie per row.',m); end
                   list{m,1} = list{m,1}{1};
                end                    
                if ~isempty(list{m,2}), Position(m,:) = list{m,2}; end
                if ~isempty(list{m,3}), Looping(m,:) = logical(list{m,3}); end
                if ~isempty(list{m,4}), Scale(m,:) = list{m,4}; end
                if ~isempty(list{m,5}), Angle(m,:) = list{m,5}; end
                
                switch class(list{m,1})
                    case {'double','uint8'}
                        if isa(list{m,1},'double') && isscalar(list{m,1})
                            obj.GraphicID(m) = list{m,1};  % MGL ID
                            try mglgetproperty(list{m,1},'origin'); catch, error('Invalid argument! MovieGraphic does not accept TaskObjects!'); end
                        else
                            obj.GraphicID(m) = mgladdmovie(list{m,1},obj.Tracker.Screen.FrameLength);
                        end                            
                    case 'char'
                        err = []; try mvdata = eval(list{m,1}); catch err, end
                        if isempty(err)
                            obj.GraphicID(m) = mgladdmovie(mvdata,obj.Tracker.Screen.FrameLength);
                        else
                            obj.Filepath{end+1} = obj.Tracker.validate_path(list{m,1});
                            obj.GraphicID(m) = mgladdmovie(obj.Filepath{end});
                        end
                    otherwise
                        error('Unknown input type!!!');
                end
            end
            obj.Enable = true(nobj,1);
            obj.Position = Position;
            obj.Looping = Looping;
            obj.BaseMarker = NaN(nobj,1);
            obj.Scale = Scale;
            obj.Angle = Angle;
            obj.Zorder = zeros(nobj,1);
            
            mglactivategraphic(obj.GraphicID,false);
        end
    end
end
