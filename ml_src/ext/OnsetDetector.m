classdef OnsetDetector < mladapter
    properties (SetAccess = protected)
        AcquiredTime = NaN
        RT = NaN
    end
    properties (Access = protected)
        LastSuccess
        bTracker
        TimeProducer
    end
    properties (SetAccess = protected, Hidden)
        Time  % alternative access to AcquiredTime
    end
    
    methods
        function obj = OnsetDetector(varargin)
            obj@mladapter(varargin{:});
            obj.bTracker = isa(obj.Adapter,'mltracker');
            obj.TimeProducer = obj.Adapter.get_adapter_with_prop('Time');  % begin iteration from the child, since this adapter, too, has the Time property
        end
        function val = get.Time(obj), val = obj.AcquiredTime; end
        function init(obj,p)
            init@mladapter(obj,p);
            obj.AcquiredTime = NaN;
            obj.LastSuccess = [];
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            obj.RT = obj.AcquiredTime - p.FirstFlipTime; if obj.RT<0, obj.RT = 0; end
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            if isempty(obj.LastSuccess), obj.LastSuccess = obj.Adapter.Success & ~obj.bTracker; end
            if ~obj.Success && ~obj.LastSuccess && obj.Adapter.Success
                if ~isempty(obj.TimeProducer), obj.AcquiredTime = obj.TimeProducer.Time(1); else, obj.AcquiredTime = p.scene_time(); end
                obj.Success = true;
            end
            obj.LastSuccess = obj.Adapter.Success;
        end
    end
end
