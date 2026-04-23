classdef KeyChecker < mladapter
    properties
        KeyNum = 1
    end
    properties (SetAccess = protected)
        Count
        Time
    end
    properties (Access = protected)
        LastData
    end
    
    methods
        function obj = KeyChecker(varargin)
            obj@mladapter(varargin{:});
            if ~strcmp(obj.Tracker.Signal,'Mouse'), error('KeyChecker needs MouseTracker.'); end
        end
        function set.KeyNum(obj,keynum)
            if ~isscalar(keynum), error('Please assign a single key number.'); end
            if keynum<1 || obj.Tracker.DAQ.nKey<keynum, error('KeyNum must be 1-%d.',obj.Tracker.DAQ.nKey); end %#ok<*MCSUP>
            obj.KeyNum = keynum;
        end
        function init(obj,p)
            init@mladapter(obj,p);
            obj.Count = 0;
            obj.Time = [];
            obj.LastData = [];
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            
            data = obj.Tracker.KeyInput(:,obj.KeyNum);
            if isempty(data), continue_ = true; return, end
            
            stroke = find(1==diff([obj.LastData; data]));
            if ~isempty(stroke), obj.Time = [obj.Time; obj.Tracker.LastSamplePosition + stroke]; end

            obj.Count = obj.Count + length(stroke);
            obj.Success = 0 < obj.Count;
            continue_ = ~obj.Success;
            obj.LastData = data(end);
        end
    end
end
