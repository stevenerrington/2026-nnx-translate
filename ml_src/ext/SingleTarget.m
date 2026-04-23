classdef SingleTarget < mlaggregator
    properties
        Target
        Threshold
        Color = [0 1 0]
    end
    properties (SetAccess = protected)
        Position
        In
        Time
    end
    properties (SetAccess = protected, Hidden)
        TouchID
        FixWindowID
    end
    properties (Access = protected)
        LastData
        LastCrossingTime
        TargetID
        ThresholdInPixels
        TouchMode
        GraphicIdx
        PrevFrame
    end
    
    methods
        function obj = SingleTarget(varargin)
            obj@mlaggregator(varargin{:});
            obj.TouchMode = strcmp(obj.Tracker.Signal,'Touch');
        end
        function delete(obj), destroy_fixwindow(obj);end

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
                obj.Adapter = obj.Adapter(1); val = val(:)';
                switch length(val)
                    case {0,2}, obj.Target = val;  % empty or coordinates
                    case 1  % TaskObject
                        if ~ismember(obj.Tracker.TaskObject.Modality(val),[1 2]), error('TaskObject#%d is not visual',val); end
                        obj.Target = val;
                    otherwise, error('Target must be a TaskObject or [x y].');
                end
            end
            
            if 1<length(obj.Adapter)
                id = obj.Adapter{2}.GraphicID; if iscell(id), obj.TargetID = id{obj.Target{1}}; else, obj.TargetID = id(obj.Target{1}); end
                obj.Position = obj.Adapter{2}.Position(obj.Target{1},:);
            else
                if 1==length(obj.Target)
                    obj.TargetID = obj.Tracker.TaskObject.ID(obj.Target);
                    obj.Position = obj.Tracker.TaskObject.Position(obj.Target,:);
                else
                    obj.TargetID = [];
                    obj.Position = obj.Target;
                end
            end
        end
        function setTarget(obj,val,idx)
            if ~exist('idx','var'), idx = []; end
            obj.GraphicIdx = idx;
            obj.Target = val;
        end
        function set.Threshold(obj,val)
            nval = numel(val); if nval<1 || 2<nval,  error('Threshold must be a scalar or a 1-by-2 vector'); end
            obj.Threshold = val(:)'; create_fixwindow(obj);
        end
        function set.Color(obj,val), obj.Color = val(:)'; create_fixwindow(obj); end

        function init(obj,p)
            if isempty(obj.Threshold), error('Threshold is not set.'); end
            obj.Adapter{1}.init(p);
            obj.Success = false;
            obj.Time = [];
            obj.TouchID = [];  % for touch
            obj.LastData = [];
            obj.PrevFrame = NaN;
            mglactivategraphic([obj.FixWindowID obj.TargetID],true);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_init(p,true); end
        end
        function fini(obj,p)
            obj.Adapter{1}.fini(p);
            mglactivategraphic([obj.FixWindowID obj.TargetID],false);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_fini(p); end
        end
        function continue_ = analyze(obj,p)
            obj.Adapter{1}.analyze(p);
            CurrentFrame = p.scene_frame();
            if obj.PrevFrame==CurrentFrame, continue_ = ~obj.Success; return, else, obj.PrevFrame = CurrentFrame; end  % draw only once in one frame
            
            data = obj.Tracker.XYData;
            [a,b] = size(data); b = b/2;
            if 0==a, continue_ = true; return, end  % early exit, if there is no data
            
            if isempty(obj.Target), obj.Position = obj.Adapter{1}.Position; end
            ScrPosition = obj.Tracker.CalFun.deg2pix(obj.Position);
            mglsetorigin(obj.FixWindowID,ScrPosition);
            
            % determine 'in' or 'out'
            idx = 1;
            obj.In = false(a,b);
            for m=1:b
                xy = data(:,idx:idx+1);
                if isscalar(obj.ThresholdInPixels)
                    obj.In(:,m) = sum((xy-repmat(ScrPosition,a,1)).^2,2) < obj.ThresholdInPixels;
                else
                    rc = [ScrPosition ScrPosition] + obj.ThresholdInPixels;
                    obj.In(:,m) = rc(1)<xy(:,1) & xy(:,1)<rc(3) & rc(2)<xy(:,2) & xy(:,2)<rc(4);
                end
                idx = idx + 2;
            end

            % check crossing
            if isempty(obj.LastData)
                obj.LastData = obj.In(1,:);
                obj.LastCrossingTime = repmat(obj.Tracker.LastSamplePosition,1,b);
            end
            c = diff([obj.LastData; obj.In]);  % 0: no crossing, 1: cross in, -1: cross out
            obj.LastData = obj.In(end,:);      % keep the last 'in' state for next cycle

            for m=1:b
                d = find(0~=c(:,m),1,'last');  % empty when there is no crossing
                if ~isempty(d), obj.LastCrossingTime(m) = obj.Tracker.LastSamplePosition + d; end
            end

            if obj.TouchMode  % update status immediately
                on = find(obj.LastData,1);  % multiple XYs
                if isempty(on)
                    obj.Success = false;
                    if ~isempty(obj.TouchID), obj.Time = obj.LastCrossingTime(obj.TouchID); end
                    obj.TouchID = [];
                else
                    obj.Success = true;
                    obj.Time = obj.LastCrossingTime(on);
                    obj.TouchID = on;
                end
            else
                if 1~=b, error('%s cannot have multiple XYs.',obj.Tracker.Signal); end
                if isempty(d)  % update status after the signal becomes stable
                    obj.Success = obj.LastData;
                    obj.Time = obj.LastCrossingTime;
                end
            end
            continue_ = ~obj.Success;
        end
        function draw(obj,p)
            obj.Adapter{1}.draw(p);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_draw(p,obj.Target{1}); end
        end
    end
    
    methods (Access = protected)
        function create_fixwindow(obj)
            if isempty(obj.Threshold) || isempty(obj.Color), return, end
            destroy_fixwindow(obj);
            
            threshold_in_pixels = obj.Threshold * obj.Tracker.Screen.PixelsPerDegree;
            if isscalar(obj.Threshold)
                if threshold_in_pixels < min(obj.Tracker.Screen.SubjectScreenHalfSize)
                    obj.FixWindowID = mgladdcircle(obj.Color,threshold_in_pixels*2,10);
                end
                obj.ThresholdInPixels = threshold_in_pixels^2;
            else
                if all(threshold_in_pixels < obj.Tracker.Screen.SubjectScreenFullSize)
                    obj.FixWindowID = mgladdbox(obj.Color,threshold_in_pixels,10);
                end
                obj.ThresholdInPixels = 0.5*[-threshold_in_pixels threshold_in_pixels];  % [left bottom right top]
            end
            mglactivategraphic(obj.FixWindowID,false);
        end
        function destroy_fixwindow(obj), mgldestroygraphic(obj.FixWindowID); obj.FixWindowID = []; end
    end
end
