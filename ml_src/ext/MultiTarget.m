classdef MultiTarget < mlaggregator
    properties
        Target
        Threshold
        WaitTime
        HoldTime
        Color = [0 1 0]
        AllowFixBreak = false
        TurnOffUnchosen = true
        AllowEarlyFix = true
    end
    properties (SetAccess = protected)
        Position
        Running = false
        Waiting = true
        AcquiredTime = NaN
        ChosenTarget = []
        RT = NaN
        ChoiceHistory
    end
    properties (Access = protected)
        SingleTarget
        Analyzer      % WaitThenHold or FreeThenHold
        nTarget = 0
        TargetID
        TargetToAnalyze
        WasGood       % for FreeThenHold
        TargetIsTaskObject
        Continue
        GraphicIdx
        PrevFrame
    end
    
    methods
        function obj = MultiTarget(varargin)
            obj@mlaggregator(varargin{:});
            % Do not initialze Target. It will reset obj.Adapter and make replay failed.
        end
        
        function set.Target(obj,val)
            if isobject(val)      % for the first graphic adapter
                if ~isa(val,'mlgraphic'), error('Target must be a graphic adapter.'); end
                obj.Adapter = obj.Adapter(1); obj.Adapter{2} = val;  % make it sure this is the only graphic adapter
                if isempty(obj.GraphicIdx), obj.Target = {1:length(val.GraphicID)}; else, obj.Target = {obj.GraphicIdx}; obj.GraphicIdx = []; end
                update_target(obj);  % update TargetID, Position, nTarget for adapters
            elseif iscell(val)    % for replay of graphic adapters or addTarget()
                if length(obj.Adapter) <= length(val), error('The number of graphic objects does not match!'); end
                obj.Target = val;
                update_target(obj);
            elseif ~isempty(val)
                obj.Adapter = obj.Adapter(1); [m,n] = size(val);
                if 1<m && 2==n  % for coordinates (an n-by-2 matrix)
                    obj.Target = val;
                    obj.TargetID = []; %#ok<*MCSUP> 
                    obj.Position = val;
                    obj.nTarget = size(val,1);
                else            % for TaskObjects
                    val = val(:)'; nonvisual = ~ismember(obj.Tracker.TaskObject.Modality(val),[1 2]);
                    if any(nonvisual), error('TaskObject#%d is not visual',val(find(nonvisual,1))); end
                    obj.Target = val;
                    obj.TargetID = num2cell(obj.Tracker.TaskObject.ID(val));
                    obj.Position = obj.Tracker.TaskObject.Position(val,:);
                    obj.nTarget = numel(val);
                end
            else
                error('Target cannot be empty!');
            end
            create_analyzer(obj);
        end
        function setTarget(obj,val,idx)
            if ~exist('idx','var'), idx = []; end
            obj.GraphicIdx = idx;
            obj.Target = val;
        end
        function add(obj,val,idx)
            if ~isa(val,'mlgraphic'), error('Target must be a graphic adapter.'); end
            if ~exist('idx','var'), idx = 1:length(val.GraphicID); end
            obj.Adapter{end+1} = val;
            obj.Target{end+1} = idx;  % We know that obj.Target is a cell.
            update_target(obj);
            create_analyzer(obj);
        end
        function addTarget(obj,varargin), add(obj,varargin{:}); end
        
        function set.Threshold(obj,val), obj.Threshold = val; create_analyzer(obj); end
        function set.WaitTime(obj,val), obj.WaitTime = val; create_analyzer(obj); end
        function set.HoldTime(obj,val), obj.HoldTime = val; create_analyzer(obj); end
        function set.Color(obj,val), obj.Color = val(:)'; create_analyzer(obj); end
        function set.AllowFixBreak(obj,val), obj.AllowFixBreak = logical(val); create_analyzer(obj); end
        function set.TurnOffUnchosen(obj,val), obj.TurnOffUnchosen = logical(val); end
        
        function init(obj,p)
            obj.Adapter{1}.init(p);
            obj.Success = false;
            obj.Running = true;
            obj.Waiting = true;
            obj.AcquiredTime = NaN;
            obj.ChosenTarget = [];
            obj.ChoiceHistory = [];
            obj.TargetToAnalyze = 1:obj.nTarget;
            obj.WasGood = false(1,obj.nTarget);
            obj.TargetIsTaskObject = ~iscell(obj.Target) && ~isempty(obj.TargetID);
            obj.PrevFrame = NaN;
            for m=1:obj.nTarget, obj.Analyzer{m}.init(p); end
            for m=1:numel(obj.TargetID), mglactivategraphic(obj.TargetID{m},true); end
            for m=2:length(obj.Adapter), obj.Adapter{m}.animate_init(p,true); end
        end
        function fini(obj,p)
            obj.Adapter{1}.fini(p);
            obj.RT = obj.AcquiredTime - p.FirstFlipTime; if obj.RT<0, obj.RT = 0; end
            for m=1:obj.nTarget, obj.Analyzer{m}.fini(p); end
            for m=1:numel(obj.TargetID), mglactivategraphic(obj.TargetID{m},false); end
            for m=2:length(obj.Adapter), obj.Adapter{m}.animate_fini(p); end
        end
        function continue_ = analyze(obj,p)
            obj.Adapter{1}.analyze(p);
            if ~obj.Running, continue_ = false; return, end
            CurrentFrame = p.scene_frame();
            if obj.PrevFrame==CurrentFrame, continue_ = obj.Continue; return, else, obj.PrevFrame = CurrentFrame; end  % draw only once in one frame

            continue_ = true;
            for m=obj.TargetToAnalyze
                continue_ = continue_ & obj.Analyzer{m}.analyze(p);
                if obj.AllowFixBreak  % FreeThenHold
                    if ~obj.WasGood(m) && obj.SingleTarget{m}.Success
                        obj.Waiting = false;
                        obj.AcquiredTime = obj.Analyzer{m}.AcquiredTime;
                        if ~obj.AllowEarlyFix && (isnan(p.FirstFlipTime) || obj.AcquiredTime<p.FirstFlipTime), continue_ = false; end

                        if obj.TargetIsTaskObject, chosen = obj.Target(m); else, chosen = m; end
                        obj.ChoiceHistory(end+1,1:2) = [chosen obj.AcquiredTime];
                    end
                    obj.WasGood(m) = obj.SingleTarget{m}.Success;
                else                  % WaitThenHold
                    if obj.Waiting && obj.SingleTarget{m}.Success
                        obj.Waiting = false;
                        obj.AcquiredTime = obj.Analyzer{m}.AcquiredTime;
                        if ~obj.AllowEarlyFix && (isnan(p.FirstFlipTime) || obj.AcquiredTime<p.FirstFlipTime), continue_ = false; end
                        obj.TargetToAnalyze = m;        % Once a target is chosen, there is no need to look at other ones.

                        if obj.TargetIsTaskObject, chosen = obj.Target(m); else, chosen = m; end
                        obj.ChoiceHistory(end+1,1:2) = [chosen obj.AcquiredTime];

                        unchosen = 1:obj.nTarget; unchosen(m) = [];  % turn off the unchosen
                        unchosen_off = obj.TurnOffUnchosen & ~isempty(obj.TargetID);
                        for n=unchosen
                            mglactivategraphic(obj.SingleTarget{n}.FixWindowID,false);
                            if unchosen_off, mglactivategraphic(obj.TargetID{n},false); end
                        end
                    end
                end
                if obj.Analyzer{m}.Success
                    if obj.TargetIsTaskObject, obj.ChosenTarget = obj.Target(m); else, obj.ChosenTarget = m; end
                    continue_ = false;
                    obj.Success = true;
                    obj.Running = false;
                    break
                end
            end
            obj.Continue = continue_;
        end
        function draw(obj,p)
            obj.Adapter{1}.draw(p);
            for m=2:length(obj.Adapter), obj.Adapter{m}.animate_draw(p,obj.Target{m-1}); end
        end
    end
    
    methods (Access = protected)
        function update_target(obj)  % update TargetID, Position, nTarget for adapters
            if ~iscell(obj.Target), return, end
            obj.TargetID = []; obj.Position = [];
            for m=1:numel(obj.Target)
                if iscell(obj.Adapter{m+1}.GraphicID)
                    obj.TargetID = [obj.TargetID obj.Adapter{m+1}.GraphicID(obj.Target{m})];
                else
                    obj.TargetID = [obj.TargetID num2cell(obj.Adapter{m+1}.GraphicID(obj.Target{m}))];
                end
                obj.Position = [obj.Position; obj.Adapter{m+1}.Position(obj.Target{m},:)];
            end
            obj.nTarget = numel(obj.TargetID);
        end
        function create_analyzer(obj)
            if isempty(obj.Target) || isempty(obj.Threshold) || isempty(obj.WaitTime) || isempty(obj.HoldTime) || isempty(obj.Color), return, end

            obj.SingleTarget = cell(1,obj.nTarget);
            obj.Analyzer = cell(1,obj.nTarget);
            if size(obj.Threshold,1) < obj.nTarget, threshold = repmat(obj.Threshold(1,:),obj.nTarget,1); else, threshold = obj.Threshold; end
            for m=1:obj.nTarget
                obj.SingleTarget{m} = SingleTarget(obj.Tracker); %#ok<CPROP>
                obj.SingleTarget{m}.Target = obj.Position(m,:);
                obj.SingleTarget{m}.Threshold = threshold(m,:);
                obj.SingleTarget{m}.Color = obj.Color;
                if obj.AllowFixBreak
                    obj.Analyzer{m} = FreeThenHold(obj.SingleTarget{m});
                else
                    obj.Analyzer{m} = WaitThenHold(obj.SingleTarget{m});
                end
                obj.Analyzer{m}.WaitTime = obj.WaitTime;
                obj.Analyzer{m}.HoldTime = obj.HoldTime;
            end
        end
    end
end
