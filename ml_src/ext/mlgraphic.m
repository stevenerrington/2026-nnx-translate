classdef mlgraphic < mlstimulus
    properties
        Enable
        List
    end
    properties (SetAccess = protected)
        GraphicID
    end
    properties (Abstract)
        Position
        Zorder
    end
    methods (Abstract, Access = protected)
        create_graphic(obj)
    end

    methods
        function obj = mlgraphic(varargin)
            obj@mlstimulus(varargin{:});
        end
        function delete(obj), destroy_graphic(obj); end

        function set.Enable(obj,val), numchk(obj,val,'Enable'); obj.Enable = val; end
        function set.List(obj,val), obj.List = val; create_graphic(obj); end

        % These functions are supposed to be called by behavior-tracking
        % adapters that accepts graphic adapters as a target. They are for
        % updating animated graphics without moving through the adapter chain.
        function animate_init(~,~,~), end  % 3rd arg is given only when called from behavior-tracking adapters
        function animate_fini(~,~), end
        function animate_draw(~,~,~), end  % 3rd arg is indices of objects used as target in the graphic adapter

        function init(obj,p)
            init@mlstimulus(obj,p);
            if ~obj.Trigger
                obj.Triggered = true;
                if iscell(obj.GraphicID)
                    for m=1:numel(obj.GraphicID), mglactivategraphic(obj.GraphicID{m},obj.Enable(m)); end
                else
                    mglactivategraphic(obj.GraphicID,obj.Enable);
                end
            end
        end
        function fini(obj,p)
            fini@mlstimulus(obj,p);
            if iscell(obj.GraphicID)
                for m=1:numel(obj.GraphicID), mglactivategraphic(obj.GraphicID{m},false); end
            else
                mglactivategraphic(obj.GraphicID,false);
            end
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mlstimulus(obj,p);
            obj.Success = obj.Adapter.Success;
            if ~obj.Triggered && obj.Success
                obj.Triggered = true;
                if iscell(obj.GraphicID)
                    for m=1:numel(obj.GraphicID), mglactivategraphic(obj.GraphicID{m},obj.Enable(m)); end
                else
                    mglactivategraphic(obj.GraphicID,obj.Enable);
                end
                p.eventmarker(obj.EventMarker);
            end
        end
    end

    methods (Access = protected)
        function destroy_graphic(obj)
            if iscell(obj.GraphicID)
                for m=1:numel(obj.GraphicID), mgldestroygraphic(obj.GraphicID{m}); end
            else
                mgldestroygraphic(obj.GraphicID);
            end
            obj.GraphicID = [];
        end
        function row = numchk(obj,val,prop)
            if isempty(val), row = []; return, end
            sz = size(val); if numel(obj.GraphicID)~=sz(1), error('The length of %s doesn''t match the number of graphic objects.',prop); end
            old = obj.(prop); if any(size(old)~=sz), row = 1:sz(1); else, row = find(any(old~=val,2))'; end
        end
        function [row,val] = cellnumchk(obj,val,prop)
            if ~iscell(val), val = {val}; end
            if isempty(val{1}), row = []; return, end
            sz = size(val); if numel(obj.GraphicID)~=sz(1), error('The length of %s doesn''t match the number of graphic objects.',prop); end
            d = true(1,sz(1));
            if all(size(obj.(prop))==sz), for m=1:sz(1), d(m) = any(size(obj.(prop){m})~=size(val{m})) || any(any(obj.(prop){m}~=val{m})); end, end
            row = 1:sz(1); row = row(d);
        end
        function [row,val] = strchk(obj,val,prop)
            if ~iscell(val), val = {val}; end
            if isempty(val{1}), row = []; return, end
            sz = size(val); if numel(obj.GraphicID)~=sz(1), error('The length of %s doesn''t match the number of graphic objects.',prop); end
            if any(size(obj.(prop))~=sz), row = 1:sz(1); else, row = find(~strcmp(obj.(prop),val))'; end
        end
    end
end
