classdef mladapter < handle
    properties (SetAccess = protected)
        Success = false
    end
    properties (Access = protected)
        Adapter
        Tracker
    end
    properties (SetAccess = protected, Hidden)
        AdapterID  % import can overwrite this, irrespective of SetAccess, but not in the derived classes
    end
    methods
        function obj = mladapter(adapter)
            if isa(obj,'mltracker') || isa(obj,'mlaggregator'), return, end  % to avoid the deault constructor
            if 0==nargin || ~isa(adapter,'mladapter'), error('The 1st argument must be mladapter'); end
            obj.Adapter = adapter;
            obj.Tracker = obj.tracker();
            obj.AdapterID = tic;
        end
        function obj = replace(obj,adapter), obj.Adapter = adapter; end  % for reconstruct_adapter()

        function init(obj,p)
            obj.Adapter.init(p);
            obj.Success = false;
        end
        function fini(obj,p)
            obj.Adapter.fini(p);
        end
        function continue_ = analyze(obj,p)
            continue_ = obj.Adapter.analyze(p);
        end
        function draw(obj,p)
            obj.Adapter.draw(p);
        end

        function o = get_adapter_with_prop(obj,prop)
            if isprop(obj,prop), o = obj; else, o = obj.Adapter.get_adapter_with_prop(prop); end
        end
        function o = get_adapter(obj,name)
            if isa(obj,name), o = obj; else, o = obj.Adapter.get_adapter(name); end
        end
        function o = tracker(obj)
            o = obj.Adapter.tracker();
        end
        function val = export(obj)
            val = exportnames(obj);
            for m=1:size(val,1), val{m,2} = obj.(val{m,1}); end
        end
        function import(obj,val)
            if isempty(val), return, end
            fn = importnames(obj);
            idx = strcmp(fn,'List'); fn = [fn(idx); fn(~idx)];  % move List to the top
            for m=1:size(fn,1)
                idx = strcmp(fn(m),val(:,1));
                if ~any(idx), continue, end
                obj.(fn{m}) = val{idx,2};
            end
        end
        function info(obj,s)
            obj.Adapter.info(s);
            s.AdapterList{end+1} = class(obj);
            s.AdapterArgs{end+1} = obj.export();
        end
        function val = fieldnames(obj)
            val = properties(obj); l = length(val); s = false(l,1);
            for m=1:l, s(m) = strcmp(obj.findprop(val{m}).SetAccess,'public'); end
            val = [val(s); 'AdapterID'];
        end
        function val = exportnames(obj), val = fieldnames(obj); end
        function val = importnames(obj), val = fieldnames(obj); end
    end
end
