classdef BackgroundColorChanger < mladapter
    properties
        DurationUnit = 'frame'  % or 'msec'
        List
        Repetition = 1
    end
    properties (SetAccess = protected)
        Time
    end
    properties (Access = protected)
        InitColor
        ColorSchedule
        PrevColorIdx
        bColorChanged
        TimeIdx
        PrevFrame
    end
    
    methods
        function obj = BackgroundColorChanger(varargin)
            obj@mladapter(varargin{:});
        end
        function set.List(obj,val)
            sz = size(val);
            if ~isnumeric(val) || sz(2)<4, error('List must be an n-by-4 or n-by-5 numeric matrix.'); end
            obj.List = NaN(sz(1),5);
            obj.List(:,1:sz(2)) = val;
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            obj.Time = NaN(size(obj.List,1)*obj.Repetition,1);
            obj.InitColor = obj.Tracker.Screen.BackgroundColor;
            if strcmpi(obj.DurationUnit,'frame')
                obj.ColorSchedule = cumsum(obj.List(:,4));
            else
                obj.ColorSchedule = cumsum(round(obj.List(:,4) / obj.Tracker.Screen.FrameLength));
            end
            obj.PrevColorIdx = NaN;
            obj.bColorChanged = false;
            % obj.TimeIdx = 1;  % updated together with bColorChanged
            obj.PrevFrame = NaN;
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            if obj.bColorChanged, obj.Time(obj.TimeIdx) = p.LastFlipTime; end
            obj.Tracker.Screen.BackgroundColor = obj.InitColor;
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            CurrentFrame = p.scene_frame();
            if obj.PrevFrame==CurrentFrame, continue_ = ~obj.Success; return, else, obj.PrevFrame = CurrentFrame; end  % draw only once in one frame
            
            if obj.bColorChanged, obj.Time(obj.TimeIdx) = p.LastFlipTime; end
            repetition = (CurrentFrame + [1 0]) / obj.ColorSchedule(end);
            obj.Success = obj.Repetition <= repetition(1);
            continue_ = ~obj.Success;

            ColorIdx = find(mod(CurrentFrame,obj.ColorSchedule(end)) < obj.ColorSchedule,1);
            obj.bColorChanged = obj.PrevColorIdx ~= ColorIdx && repetition(2) < obj.Repetition;
            if obj.bColorChanged
                obj.PrevColorIdx = ColorIdx;
                obj.TimeIdx = floor(repetition(2)) * size(obj.List,1) + ColorIdx;
                obj.Tracker.Screen.BackgroundColor = obj.List(ColorIdx,1:3);
                p.eventmarker(obj.List(ColorIdx,5));
            end
        end
    end
end
