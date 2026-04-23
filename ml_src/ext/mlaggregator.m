classdef mlaggregator < mladapter
    methods
        function obj = mlaggregator(adapter)  % The default constructor will be called anyway
            if iscell(adapter), obj.Adapter = adapter; else, obj.Adapter{1} = adapter; end
            obj.Tracker = obj.tracker();
            obj.AdapterID = tic;
        end
        
        function add(obj,adapter)
            if iscell(adapter)
                obj.Adapter(end+1:end+length(adapter)) = adapter;
            else
                obj.Adapter{end+1} = adapter;
            end
        end
        function val = length(obj), val = length(obj.Adapter); end
        function erase(obj,chain_no), obj.Adapter(chain_no) = []; end
        function clear(obj), obj.Adapter = []; end
        
        function init(obj,p)
            for m=1:length(obj.Adapter), obj.Adapter{m}.init(p); end
            obj.Success = false;
        end
        function fini(obj,p)
            for m=1:length(obj.Adapter), obj.Adapter{m}.fini(p); end
        end
        function continue_ = analyze(obj,p)
            for m=1:length(obj.Adapter), obj.Adapter{m}.analyze(p); end
            continue_ = ~obj.Success;
        end
        function draw(obj,p)
            for m=1:length(obj.Adapter), obj.Adapter{m}.draw(p); end
        end
        
        function o = get_adapter_with_prop(obj,prop)
            if isprop(obj,prop)
                o = obj;
            else
                for m=1:length(obj.Adapter)
                    o = obj.Adapter{m}.get_adapter_with_prop(prop);
                    if ~isempty(o), break, end
                end
            end
        end
        function o = get_adapter(obj,name)
            if isa(obj,name)
                o = obj;
            else
                for m=1:length(obj.Adapter)
                    o = obj.Adapter{m}.get_adapter(name);
                    if ~isempty(o), break, end
                end
            end
        end
        function o = get_adapters(obj,name)
            if isa(obj,name)
                o = obj;
            else
                nanalyzer = length(obj.Adapter);
                o = cell(1,nanalyzer);
                for m=1:nanalyzer
                    o{m} = obj.Adapter{m}.get_adapter(name);
                end
            end
        end
        function o = tracker(obj)
            for m=1:length(obj.Adapter)
                o = obj.Adapter{m}.tracker();
                if ~isempty(o), break, end
            end
        end
        function o = trackers(obj)
            nanalyzer = length(obj.Adapter);
            o = cell(1,nanalyzer);
            for m=1:nanalyzer
                o{m} = obj.Adapter{m}.tracker();
            end
        end
        function info(obj,s)
            nadapter = length(obj.Adapter);
            Args = cell(1,nadapter+1);
            for m=1:nadapter
                a = SceneParam;
                obj.Adapter{m}.info(a);
                Args{m} = a;
            end
            Args{m+1} = obj.export();
            s.AdapterList{end+1} = class(obj);
            s.AdapterArgs{end+1} = Args;
        end
    end
end
