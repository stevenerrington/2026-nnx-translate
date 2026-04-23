classdef Sequential < mlaggregator
    properties
        EventMarker
        ContinueOnFailure = false
    end
    properties (SetAccess = protected)
        CurrentChain
    end
    properties (Access = protected)
        Param
        Update
        UpdateFirstFlip
        Running
        DoNotContinue
    end
    methods
        function obj = Sequential(varargin)
            obj@mlaggregator(varargin{:});
        end
        
        function init(obj,p)
            obj.Success = false;
            obj.CurrentChain = 0;
            obj.Param = copy(p);
            obj.Update = true;
            obj.UpdateFirstFlip = false;
            obj.Running = true;
            obj.DoNotContinue = false;
        end
        function fini(obj,p)
            if 0==obj.CurrentChain, return, end
            if obj.Running, obj.Adapter{obj.CurrentChain}.fini(obj.Param); end
            p.eyetargetrecord('Eye',obj.Param.EyeTargetRecord(p.EyeTargetIndex+1:obj.Param.EyeTargetRecord,:));
            p.eyetargetrecord('Eye2',obj.Param.Eye2TargetRecord(p.Eye2TargetIndex+1:obj.Param.Eye2TargetRecord,:));
            for m=fieldnames(obj.Param.User)', p.User.(m{1}) = obj.Param.User.(m{1}); end
        end
        function continue_ = analyze(obj,p)
            continue_ = false;
            if ~obj.Running, return, end
            if obj.UpdateFirstFlip, obj.Param.FirstFlipTime = p.LastFlipTime; obj.UpdateFirstFlip = false; end
            if obj.Update
                if 0<obj.CurrentChain, obj.Adapter{obj.CurrentChain}.fini(obj.Param); end
                if obj.DoNotContinue, obj.Running = false; return, end

                obj.CurrentChain = obj.CurrentChain + 1;
                obj.Param.reset();
                obj.Adapter{obj.CurrentChain}.init(obj.Param);
                obj.Param.SceneStartTime = p.trialtime();
                obj.Param.SceneStartFrame = p.FrameNum;
                obj.Update = false;
                obj.UpdateFirstFlip = true;
                if obj.CurrentChain<=length(obj.EventMarker), p.eventmarker(obj.EventMarker(obj.CurrentChain)); end
            end
            obj.Param.FrameNum = p.FrameNum;
            obj.Param.LastFlipTime = p.LastFlipTime;

            continue_ = true;
            if ~obj.Adapter{obj.CurrentChain}.analyze(obj.Param)
                obj.Update = true;
                if length(obj.Adapter)==obj.CurrentChain
                    obj.Success = true;
                    continue_ = false;
                    obj.DoNotContinue = true;
                else
                    if ~obj.Adapter{obj.CurrentChain}.Success && ~obj.ContinueOnFailure
                        continue_ = false;
                        obj.DoNotContinue = true;
                    end
                end
            end
        end
        function draw(obj,p)
            if 0==obj.CurrentChain, return, end
            if ~obj.Running, return, end
            obj.Adapter{obj.CurrentChain}.draw(obj.Param);
            p.eventmarker(obj.Param.EventMarker); clearmarker(obj.Param);
        end
    end
end
