classdef mlscalable < mlgraphic
    properties
        Position
        Zorder
        Scale
        Angle
    end

    methods
        function obj = mlscalable(varargin)
            obj@mlgraphic(varargin{:});
        end

        function set.Position(obj,val), row = numchk(obj,val,'Position'); mglsetorigin(obj.GraphicID(row),obj.Tracker.CalFun.deg2pix(val(row,:))); end  % no point in assining to obj.Position; it will be overwritten by get.Position()
        function set.Zorder(obj,val),   row = numchk(obj,val,'Zorder');   mglsetproperty(obj.GraphicID(row),'zorder',val(row,:)); end
        function val = get.Position(obj), nid = numel(obj.GraphicID); val = NaN(nid,2); for m=1:nid, val(m,:) = mglgetproperty(obj.GraphicID(m),'origin'); end, val = obj.Tracker.CalFun.pix2deg(val); end
        function val = get.Zorder(obj),   nid = numel(obj.GraphicID); val = NaN(nid,1); for m=1:nid, val(m,:) = mglgetproperty(obj.GraphicID(m),'zorder'); end, end

        function set.Scale(obj,val),   if numel(obj.GraphicID)==numel(val), val = repmat(val(:),1,2); end  % for replaying old files in which Scale was a scalar
                                       row = numchk(obj,val,'Scale'); mglsetproperty(obj.GraphicID(row),'scale',val(row,:)); end
        function set.Angle(obj,val),   row = numchk(obj,val,'Angle'); mglsetproperty(obj.GraphicID(row),'angle',val(row,:)); end
        function val = get.Scale(obj), nid = numel(obj.GraphicID); val = NaN(nid,2); for m=1:nid, val(m,:) = mglgetproperty(obj.GraphicID(m),'scale');  end, end
        function val = get.Angle(obj), nid = numel(obj.GraphicID); val = NaN(nid,1); for m=1:nid, val(m,:) = mglgetproperty(obj.GraphicID(m),'angle');  end, end
    end
end
