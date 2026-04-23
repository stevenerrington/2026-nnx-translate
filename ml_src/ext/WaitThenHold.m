classdef WaitThenHold < mladapter
    properties
        WaitTime = 0        % time to wait for fixation
        HoldTime = 0        % time to hold fixation
        AllowEarlyFix = true
    end
    properties (SetAccess = protected)
        Running = false     % whether we are still tracking. true or false
        Waiting = true      % whether we are still waiting for fixation. true or false
        AcquiredTime = NaN  % trialtime when fixation was acquired
        RT = NaN
    end
    properties (Access = protected)
        SingleTarget
        TimeProducer
        EndTime
    end
    
    methods
        function obj = WaitThenHold(varargin)
            obj@mladapter(varargin{:});
            obj.SingleTarget = get_adapter(obj,'SingleTarget');
            obj.TimeProducer = get_adapter_with_prop(obj,'Time');
        end
        function init(obj,p)
            init@mladapter(obj,p);
            obj.Running = true;
            obj.Waiting = true;
            obj.AcquiredTime = NaN;
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            obj.RT = obj.AcquiredTime - p.FirstFlipTime;
            if obj.RT<0, obj.RT = 0; end  % RT can be negative if fixation was acquired already before the scene start
            if obj.Success && ~isempty(obj.SingleTarget)  % for auto drift correction
                p.eyetargetrecord(obj.Tracker.Signal,[obj.SingleTarget.Position [obj.AcquiredTime 0]+obj.HoldTime*0.5]);
            end
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            if ~obj.Running, continue_ = false; return, end  % If we are not tracking, return early.
            continue_ = true;                                % By default, keep tracking to the next frame.
            
            % The child adapter (obj.Adapter) of this adapter is SingleTarget
            % and its Success property is true when fixation is acquired.
            good = obj.Adapter.Success;  % whether fixation was acquired during the last frame. true or false
            elapsed = p.scene_time();    % time elapsed from the scene start
            
            % If we were waiting for fixation and it is not acquired yet,
            % check if the wait time has passed. If so, stop tracking and end the scene.
            if obj.Waiting && ~good
                obj.Running = elapsed < obj.WaitTime;
                continue_ = obj.Running;
                return
            end
            
            % If we were waiting for fixation and it is acquired,
            % set Waiting to false and calculate when the hold time should end.
            if obj.Waiting && good
                if ~isempty(obj.TimeProducer), obj.AcquiredTime = obj.TimeProducer.Time; end
                if ~obj.AllowEarlyFix && (isnan(p.FirstFlipTime) || obj.AcquiredTime<p.FirstFlipTime), continue_ = false; end
                obj.Waiting = false;
                obj.EndTime = elapsed + obj.HoldTime;
            end
            
            % If the subject fixated but not anymore (i.e., broke the fixation),
            % then stop tracking and end the scene.
            if ~obj.Waiting && ~good
                obj.Running = false;
                continue_ = obj.Running;
                return
            end
            
            % If the subject fixated and is maintaining it,
            % check if the hold time has passed. If so, set Success to true and end the scene.
            if ~obj.Waiting && good
                if obj.EndTime <= elapsed
                    obj.Success = true;
                    obj.Running = false;
                    continue_ = obj.Running;
                    return
                end
            end
        end
    end
end
