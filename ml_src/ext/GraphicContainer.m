classdef GraphicContainer < mlgraphic & mlaggregator
    properties
        Position
        Zorder
    end
    properties (Hidden)
        IdxList
    end
    properties (SetAccess = protected)
        Map
    end
    methods
        function obj = GraphicContainer(adapter)
            obj@mlgraphic(adapter);
            obj@mlaggregator(adapter);
            if isa(obj.Adapter{1},'mlgraphic'), add(obj,obj.Adapter{1}); obj.Adapter{1} = obj.Tracker; end
        end
        function val = fieldnames(obj), val = ['IdxList'; mlsetdiff(fieldnames@mlgraphic(obj),'List')]; end

        function set.Position(obj,val), n = size(val,1); for m=1:n, obj.Adapter{obj.Map(m,1)+1}.Position(obj.Map(m,2),:) = val(m,:); end, end %#ok<*MCSUP>
        function set.Zorder(obj,val), n = size(val,1); for m=1:n, obj.Adapter{obj.Map(m,1)+1}.Zorder(obj.Map(m,2),:) = val(m,:); end, end
        function val = get.Position(obj), n = size(obj.Map,1); val = zeros(n,2); for m=1:n, val(m,:) = obj.Adapter{obj.Map(m,1)+1}.Position(obj.Map(m,2),:); end, end
        function val = get.Zorder(obj), n = size(obj.Map,1); val = zeros(n,1); for m=1:n, val(m,:) = obj.Adapter{obj.Map(m,1)+1}.Zorder(obj.Map(m,2),:); end, end

        function set.IdxList(obj,val)  % set.List cannot be overridden because obj.List is not defined in this class
            if isempty(val)     % clear()
                obj.Adapter = obj.Adapter(1); obj.GraphicID = []; obj.IdxList = []; obj.Enable = [];
            elseif iscell(val)  % add() and replay
                obj.GraphicID = cell(1,length([val{:}]));
                obj.Map = []; idx = 1;
                for m=1:numel(val)
                    for n=val{m}(:)'
                        if iscell(obj.Adapter{m+1}.GraphicID)
                            obj.GraphicID{idx} = obj.Adapter{m+1}.GraphicID{n};
                        else
                            obj.GraphicID{idx} = obj.Adapter{m+1}.GraphicID(n);
                        end
                        obj.Map = [obj.Map; m n];
                        idx = idx + 1;
                    end
                end
                obj.IdxList = val; 
            end
        end
        function add(obj,adapter,idx)
            if ~isa(adapter,'mlgraphic'), error('Not graphic adapter!!!'); end
            if ~exist('idx','var'), idx = 1:numel(adapter.GraphicID); end
            if any(numel(adapter.GraphicID)<idx), error('Index cannot be larger than the number of graphic objects!'); end
            obj.Adapter{end+1} = adapter;
            obj.IdxList{end+1} = idx;
            obj.Enable(end+1:end+length(idx),1) = true;
        end

        function animate_init(obj,p,~)
            for m=2:length(obj.Adapter), obj.Adapter{m}.animate_init(p,true); end
        end
        function animate_fini(obj,p)
            for m=2:length(obj.Adapter), obj.Adapter{m}.animate_fini(p); end
        end
        function animate_draw(obj,p,idx)
            if nargin<3, idx = 1:numel(obj.IdxList); else, idx = unique(obj.Map(idx,1))'; end
            for m=idx, obj.Adapter{m+1}.animate_draw(p,obj.IdxList{m}); end
        end

        function init(obj,p)
            obj.Adapter{1}.init(p);
            obj.Triggered = false;
            if ~obj.Trigger
                obj.Triggered = true;
                for m=1:numel(obj.GraphicID), mglactivategraphic(obj.GraphicID{m},obj.Enable(m)); end
            end
            animate_init(obj,p);
        end
        function fini(obj,p)
            obj.Adapter{1}.fini(p);
            for m=1:numel(obj.GraphicID), mglactivategraphic(obj.GraphicID{m},false); end
            animate_fini(obj,p);
        end
        function continue_ = analyze(obj,p)
            continue_ = obj.Adapter{1}.analyze(p);
            obj.Success = obj.Adapter{1}.Success;
            if ~obj.Triggered && obj.Success
                obj.Triggered = true;
                for m=1:numel(obj.GraphicID), mglactivategraphic(obj.GraphicID{m},obj.Enable(m)); end
                p.eventmarker(obj.EventMarker);
            end
        end
        function draw(obj,p), obj.Adapter{1}.draw(p); animate_draw(obj,p); end
    end
    methods (Access = protected)
        function create_graphic(~), error('List cannot be used in GraphicContainer!'); end
    end
end