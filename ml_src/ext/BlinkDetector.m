classdef BlinkDetector < mladapter
    properties
        XRange  % in degrees
        YRange  % in degrees
        StopOnDetection
    end
    properties (SetAccess = protected)
        Detected
    end
    properties (Access = protected)
        Rect
    end
    
    methods
        function obj = BlinkDetector(varargin)
            obj@mladapter(varargin{:});

            obj.XRange = NaN(1,2);
            obj.YRange = NaN(1,2);
            obj.StopOnDetection = true;
        end
        
        function set.XRange(obj,val)
            if 2~=numel(val), error('XRange must be a 1-by-2 vector.'); end
            if val(2)<val(1), val = val([2 1]); end
            obj.XRange = val;
        end
        function set.YRange(obj,val)
            if 2~=numel(val), error('YRange must be a 1-by-2 vector.'); end
            if val(2)<val(1), val = val([2 1]); end
            obj.YRange = val;
        end
        function set.StopOnDetection(obj,val)
            obj.StopOnDetection = logical(val);
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            obj.Detected = false;
            obj.Rect = [obj.Tracker.CalFun.deg2pix([obj.XRange(1) obj.YRange(1)]) obj.Tracker.CalFun.deg2pix([obj.XRange(2) obj.YRange(2)])];
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            xy = obj.Tracker.XYData;
            if isempty(xy), return, end
            
            state = obj.Rect(1)<xy(:,1) & xy(:,1)<obj.Rect(3) & obj.Rect(4)<xy(:,2) & xy(:,2)<obj.Rect(2);
            if any(state)
                obj.Detected = true;
                if obj.StopOnDetection, continue_ = false; end
            end
        end
    end
end
