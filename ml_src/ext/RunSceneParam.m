classdef RunSceneParam < matlab.mixin.Copyable
    properties
        Screen
        DAQ
        TaskObject
        Mouse
        SimulationMode
        trialtime
        goodmonkey
        dashboard

        FrameNum = 0
        SceneStartTime = NaN
        SceneStartFrame = NaN
        EyeOffset = [0 0]
        Eye2Offset = [0 0]
        JoyOffset = [0 0]
        Joy2Offset = [0 0]
        PhotoDiodeStatus = false
        Cursor = struct('ShowJoy',[],'ShowJoy2',[],'ShowMouse',true,'ShowTouch',[])
        KeyStroke

        FirstFlipTime
        LastFlipTime
        SkippedFrame

        User
    end
    properties (SetAccess = protected)
        EventMarker
        EyeTargetRecord   % [xdeg ydeg start_time duration]
        Eye2TargetRecord  % [xdeg ydeg start_time duration]
        EyeTargetIndex = 0
        Eye2TargetIndex = 0
        SampleInterval
        StimulusFile
    end
    properties (Access = protected, Constant)
        MaxEyeTargetIndex = 10
    end

    methods
        function obj = RunSceneParam(MLConfig)
            obj@matlab.mixin.Copyable();
            reset(obj);
            obj.User = struct;
            obj.EyeTargetRecord = zeros(obj.MaxEyeTargetIndex,4);
            obj.Eye2TargetRecord = zeros(obj.MaxEyeTargetIndex,4);
            obj.SampleInterval = 1000 / MLConfig.AISampleRate;
            for m = {'JoystickCursorImage','JoystickCursorShape','JoystickCursorColor','JoystickCursorSize'}
                obj.Cursor.(m{1}) = MLConfig.(m{1});
            end
        end
        function reset(obj)
            obj.FirstFlipTime = NaN;
            obj.LastFlipTime = NaN;
            obj.SkippedFrame = 0;
            obj.EventMarker = [];
        end

        function [s,t] = scene_time(obj), t = obj.trialtime(); s = t-obj.SceneStartTime; end
        function f = scene_frame(obj), f = obj.FrameNum-obj.SceneStartFrame; end
        function eventmarker(obj,code), if ~isempty(code), obj.EventMarker = [obj.EventMarker code(:)']; end, end
        function clearmarker(obj), obj.EventMarker = []; end
        function stimfile(obj,val), obj.StimulusFile = [obj.StimulusFile val]; end

        function eyetargetrecord(obj,signal,val)
            if isempty(val), return, end
            try
                val = val(obj.SampleInterval*2 < val(:,4),:);
                switch signal
                    case 'Eye'
                        for m=1:size(val,1)
                            if obj.MaxEyeTargetIndex==obj.EyeTargetIndex, return, end
                            obj.EyeTargetIndex = obj.EyeTargetIndex + 1;
                            obj.EyeTargetRecord(obj.EyeTargetIndex,:) = val(m,:);
                        end
                    case 'Eye2'
                        for m=1:size(val,1)
                            if obj.MaxEyeTargetIndex==obj.Eye2TargetIndex, return, end
                            obj.Eye2TargetIndex = obj.Eye2TargetIndex + 1;
                            obj.Eye2TargetRecord(obj.Eye2TargetIndex,:) = val(m,:);
                        end
                end
            catch
                % do nothing
            end
        end
    end
end
