classdef mlpaintable < mlscalable
    properties
        EdgeColor
        FaceColor
        Size
    end

    methods
        function obj = mlpaintable(varargin)
            obj@mlscalable(varargin{:});
        end

        function set.EdgeColor(obj,val), row = numchk(obj,val,'EdgeColor'); mglsetproperty(obj.GraphicID(row),'edgecolor',val(row,:)); obj.EdgeColor = val; end
        function set.FaceColor(obj,val), row = numchk(obj,val,'FaceColor'); mglsetproperty(obj.GraphicID(row),'facecolor',val(row,:)); obj.FaceColor = val; end
        function set.Size(obj,val),      row = numchk(obj,val,'Size');      mglsetproperty(obj.GraphicID(row),'size',val(row,:).*obj.Tracker.Screen.PixelsPerDegree); obj.Size = val; end

        function val = get.EdgeColor(obj), nid = numel(obj.GraphicID); val = NaN(nid,3); for m=1:nid, val(m,:) = mglgetproperty(obj.GraphicID(m),'edgecolor'); end, end
        function val = get.FaceColor(obj), nid = numel(obj.GraphicID); val = NaN(nid,3); for m=1:nid, val(m,:) = mglgetproperty(obj.GraphicID(m),'facecolor'); end, end
        function val = get.Size(obj),      nid = numel(obj.GraphicID); val = NaN(nid,2); for m=1:nid, val(m,:) = mglgetproperty(obj.GraphicID(m),'size');      end, val = val./obj.Tracker.Screen.PixelsPerDegree; end
    end
end
