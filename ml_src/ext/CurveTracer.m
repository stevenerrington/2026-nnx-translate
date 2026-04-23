classdef CurveTracer < mlaggregator
    properties
        Target      % graphic adapter or TaskObject#
        Trajectory  % [x y], n-by-2
        Step = 1    % every n frames
        DurationUnit = 'frame'  % or 'msec'
        List
        Repetition = 1
    end
    properties (SetAccess = protected)
        Position
        Time
    end
    properties (Access = protected)
        PosSchedule
        MaxPosIdx
        PrevPosIdx
        bPosChanged
        TimeIdx
        PrevFrame
        TargetID
        GraphicIdx
    end
    
    methods
        function obj = CurveTracer(varargin)
            obj@mlaggregator(varargin{:});
        end
        function set.Target(obj,val)
            if isobject(val)  % graphic adapter
                if ~isa(val,'mlgraphic'), error('Target must be a graphic adapter.'); end
                obj.Adapter{2} = val;
                if isempty(obj.GraphicIdx) %#ok<*MCSUP> 
                    obj.Target = {1};
                else
                    if ~isscalar(obj.GraphicIdx), error('Target must be a single object.'); end
                    obj.Target = {obj.GraphicIdx}; obj.GraphicIdx = [];
                end
            elseif iscell(val)  % replay with a graphic adapter
                obj.Target = val;
            else
                if 1<length(obj.Adapter) && 2==obj.Tracker.DataSource  % for compatibility 
                    obj.Target = {val};
                else  % This adapter does not take [x y]
                    obj.Adapter = obj.Adapter(1);
                    obj.Target = val(:)';  % TaskObject
                end
            end

            if 1<length(obj.Adapter)
                id = obj.Adapter{2}.GraphicID; if iscell(id), obj.TargetID = id{obj.Target{1}}; else, obj.TargetID = id(obj.Target{1}); end
            else
                obj.TargetID = obj.Tracker.TaskObject.ID(obj.Target);
            end
        end
        function setTarget(obj,val,idx)
            if ~exist('idx','var'), idx = []; end
            obj.GraphicIdx = idx;
            obj.Target = val;
        end

        function init(obj,p)
            obj.Adapter{1}.init(p);
            if ~isempty(obj.List)
                sz = size(obj.List);
                obj.PosSchedule = NaN(sz(1),4);
                obj.PosSchedule(:,3) = 1;
                obj.PosSchedule(:,1:sz(2)) = obj.List;
            elseif ~isempty(obj.Trajectory)
                sz = size(obj.Trajectory);
                obj.PosSchedule = NaN(sz(1),4);
                obj.PosSchedule(:,1:2) = obj.Trajectory;
                obj.PosSchedule(:,3) = obj.Step;
            else
                error('Either List or Trajectory must not be empty.');
            end
            obj.MaxPosIdx = sz(1);
            
            obj.Position = NaN(1,2);
            obj.Time = NaN(obj.MaxPosIdx*obj.Repetition,1);
            if strcmpi(obj.DurationUnit,'frame')
                obj.PosSchedule(:,3) = cumsum(obj.PosSchedule(:,3));
            else
                obj.PosSchedule(:,3) = cumsum(round(obj.PosSchedule(:,3) / obj.Tracker.Screen.FrameLength));
            end
            obj.PrevPosIdx = NaN;
            obj.bPosChanged = false;
            % obj.TimeIdx = 1;  % updated together with bPosChanged
            obj.PrevFrame = NaN;
            
            mglactivategraphic(obj.TargetID,true);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_init(p,true); end
        end
        function fini(obj,p)
            obj.Adapter{1}.fini(p);
            if obj.bPosChanged, obj.Time(obj.TimeIdx) = p.LastFlipTime; end
            mglactivategraphic(obj.TargetID,false);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_fini(p); end
        end
        function continue_ = analyze(obj,p)
            obj.Adapter{1}.analyze(p);
            CurrentFrame = p.scene_frame();
            if obj.PrevFrame==CurrentFrame, continue_ = ~obj.Success; return, else, obj.PrevFrame = CurrentFrame; end  % draw only once in one frame
            
            if obj.bPosChanged, obj.Time(obj.TimeIdx) = p.LastFlipTime; end
            repetition = (CurrentFrame + [1 0]) / obj.PosSchedule(end,3);
            obj.Success = obj.Repetition <= repetition(1);
            continue_ = ~obj.Success;

            PosIdx = find(mod(CurrentFrame,obj.PosSchedule(end,3)) < obj.PosSchedule(:,3),1);
            obj.bPosChanged = obj.PrevPosIdx ~= PosIdx && repetition(2) < obj.Repetition;
            if obj.bPosChanged
                obj.PrevPosIdx = PosIdx;
                obj.TimeIdx = floor(repetition(2)) * obj.MaxPosIdx + PosIdx;
                p.eventmarker(obj.PosSchedule(PosIdx,4));

                obj.Position = obj.PosSchedule(PosIdx,1:2);
                if ~isempty(obj.Target)
                    if 1<length(obj.Adapter)
                        obj.Adapter{2}.Position(obj.Target{1},:) = obj.Position;
                    else
                        obj.Tracker.TaskObject.Position(obj.Target,:) = obj.Position;
                    end
                end
            end
        end
        function draw(obj,p)
            obj.Adapter{1}.draw(p);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_draw(p,obj.Target{1}); end
        end
    end
end
