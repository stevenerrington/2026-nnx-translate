classdef FreeThenHold < mladapter
    properties
        WaitTime = 0
        HoldTime = 0
        AllowEarlyFix = true
    end
    properties (SetAccess = protected)
        Running = false
        BreakCount = 0
        AcquiredTime = NaN
        RT = NaN
    end
    properties (Access = protected)
        SingleTarget
        TimeProducer
        WasGood
        EndTime
    end
    properties (Hidden)
        MaxTime = 0
    end
    
    methods
        function obj = FreeThenHold(varargin)
            obj@mladapter(varargin{:});
            obj.SingleTarget = get_adapter(obj,'SingleTarget');
            obj.TimeProducer = get_adapter_with_prop(obj,'Time');
        end
        function val = importnames(obj), val = [fieldnames(obj); 'MaxTime']; end
        
        function set.MaxTime(obj,val), obj.WaitTime = val; end %#ok<MCSUP> 
        function val = get.MaxTime(obj), val = obj.WaitTime; end

        function init(obj,p)
            init@mladapter(obj,p);
            obj.Running = true;
            obj.BreakCount = 0;
            obj.AcquiredTime = NaN;
            obj.WasGood = false;
            obj.EndTime = 0;
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            obj.RT = obj.AcquiredTime - p.FirstFlipTime; if obj.RT<0, obj.RT = 0; end
            if obj.Success && ~isempty(obj.SingleTarget)
                p.eyetargetrecord(obj.Tracker.Signal,[obj.SingleTarget.Position [obj.AcquiredTime 0]+obj.HoldTime*0.5]);
            end
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            if ~obj.Running, continue_ = false; return, end
            continue_ = true;

            good = obj.Adapter.Success;
            elapsed = p.scene_time();

            if ~good && ~obj.WasGood
                obj.Running = elapsed < obj.WaitTime;
                continue_ = obj.Running;
                return
            end
            
            if ~good && obj.WasGood
                obj.BreakCount = obj.BreakCount + 1;
                obj.WasGood = false;
                obj.Running = elapsed < obj.WaitTime;
                continue_ = obj.Running;
                return
            end
            
            if good && ~obj.WasGood
                if ~isempty(obj.TimeProducer), obj.AcquiredTime = obj.TimeProducer.Time; end
                if ~obj.AllowEarlyFix && (isnan(p.FirstFlipTime) || obj.AcquiredTime<p.FirstFlipTime), continue_ = false; end
                obj.WasGood = true;
                obj.EndTime = elapsed + obj.HoldTime;
            end
            
            if good && obj.WasGood
                if obj.EndTime <= elapsed
                    obj.Success = true;
                    obj.Running = false;
                    continue_ = false;
                    return
                end
            end
        end
    end
end
