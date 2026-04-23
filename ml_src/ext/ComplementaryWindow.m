classdef ComplementaryWindow < mlaggregator
    properties
        Target
        Threshold
    end
    properties (Access = protected)
        ScreenPosition
        ThresholdInPixels
        GraphicIdx
    end
    
    methods
        function obj = ComplementaryWindow(varargin)
            obj@mlaggregator(varargin{:});
            if ~strcmpi(obj.Tracker.Signal,'Touch'), error('ComplementaryWindow requires TouchTracker (touch_)!'); end
        end
        
        function set.Target(obj,val)
            switch class(val)
                case 'SingleTarget'     % possible moving target
                    obj.Adapter{2} = val; obj.Target = {1}; obj.Threshold = val.Threshold;
                case 'MultiTarget'
                    obj.Adapter = obj.Adapter(1); obj.Target = val.Position; obj.Threshold = val.Threshold;
                    obj.ScreenPosition = obj.Tracker.CalFun.deg2pix(obj.Target);
                otherwise
                    if isobject(val)    % possible moving target
                        if ~isa(val,'mlgraphic'), error('Target must be a graphic adapter.'); end
                        obj.Adapter{2} = val;
                        if isempty(obj.GraphicIdx), obj.Target = {1:length(val.GraphicID)}; else, obj.Target = {obj.GraphicIdx}; obj.GraphicIdx = []; end
                    elseif iscell(val)  % for replay with adapters
                        obj.Target = val;
                    elseif ~isempty(val)
                        if 2~=obj.Tracker.DataSource, obj.Adapter = obj.Adapter(1); end
                        if isscalar(val), obj.Target = obj.Tracker.TaskObject.Position(val,:); else, obj.Target = val; end
                        obj.ScreenPosition = obj.Tracker.CalFun.deg2pix(obj.Target);
                    else
                        error('Target cannot be empty!');
                    end
            end
        end
        function setTarget(obj,val,idx)
            if ~exist('idx','var'), idx = []; end
            obj.GraphicIdx = idx;
            obj.Target = val;
        end
        function set.Threshold(obj,val)
            obj.Threshold = val;
            threshold_in_pixels = val * obj.Tracker.Screen.PixelsPerDegree;
            if isscalar(threshold_in_pixels)
                obj.ThresholdInPixels = threshold_in_pixels * threshold_in_pixels; %#ok<*MCSUP>
            else
                obj.ThresholdInPixels = 0.5*threshold_in_pixels;
            end
        end
        
        function init(obj,p)
            obj.Adapter{1}.init(p);
            if isempty(obj.Threshold), error('Threshold cannot be empty.'); end
        end
        function fini(obj,p), obj.Adapter{1}.fini(p); end
        function continue_ = analyze(obj,p)
            obj.Adapter{1}.analyze(p);

            if isempty(obj.Tracker.XYData), continue_ = true; return, end
            data = reshape(obj.Tracker.XYData(end,:)',2,[])';

            if 1<length(obj.Adapter)
                obj.ScreenPosition = obj.Tracker.CalFun.deg2pix(obj.Adapter{2}.Position(obj.Target{1},:));
            end

            obj.Success = true;
            for m=1:size(obj.ScreenPosition,1)
                if isscalar(obj.ThresholdInPixels)
                    out = obj.ThresholdInPixels < sum((data-repmat(obj.ScreenPosition(m,:),size(data,1),1)).^2,2);
                else
                    rc = [obj.ScreenPosition(m,:)-obj.ThresholdInPixels obj.ScreenPosition(m,:)+obj.ThresholdInPixels];
                    out = rc(1)>data(:,1) | data(:,1)>rc(3) | rc(2)>data(:,2) | data(:,2)>rc(4);
                end
                obj.Success = obj.Success & any(out);
            end
            continue_ = ~obj.Success;
        end
    end
end
