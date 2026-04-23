classdef GraphicProperty < mlaggregator
    properties
        Target    % TaskObject number or graphic adapter
        Property
        Value
        Step = 1  % every n frames
        DurationUnit = 'frame'  % or 'msec'
        List
        Repetition = 1
    end
    properties (SetAccess = protected)
        Time
    end
    properties (Access = protected)
        CellVal
        Schedule
        MaxValIdx
        PrevValIdx
        bValChanged
        TimeIdx
        PrevFrame
        TargetID
        GraphicIdx
    end
    
    methods
        function obj = GraphicProperty(varargin)
            obj@mlaggregator(varargin{:});
        end
        function set.Target(obj,val)
            if isobject(val)  % graphic adapters
                if ~isa(val,'mlgraphic'), error('Target must be a graphic adapter.'); end
                obj.Adapter{2} = val;
                if isempty(obj.GraphicIdx), obj.Target = {1:length(val.GraphicID)}; else, obj.Target = {obj.GraphicIdx}; obj.GraphicIdx = []; end %#ok<*MCSUP>
            elseif iscell(val)  % replay with graphic adapters
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
            obj.GraphicIdx = idx(:)';
            obj.Target = val;
        end
        function set.Property(obj,val)
            switch class(val)
                case 'cell', for m=1:numel(val), val{m} = namechk(obj,val{m}); end
                case 'char', val = {namechk(obj,val)};
                otherwise, error('Property must be cell or char.');
            end
            obj.Property = val;
        end
        function set.Value(obj,val)
            if iscell(val)
                if ~any(1==size(val)), error('Value must be a 1-by-n cell array.'); end
                val = val(:)';
            end
            obj.Value = val;
        end
        
        function init(obj,p)
            obj.Adapter{1}.init(p);
            nprop = length(obj.Property);
            if ~isempty(obj.List)
                nextra = size(obj.List,2) - nprop;
                if iscell(obj.List)
                    obj.CellVal = obj.List(1,1:nprop);
                    obj.MaxValIdx = size(obj.List{1},1);
                    obj.Schedule = [ones(obj.MaxValIdx,1) NaN(obj.MaxValIdx,1)];
                    for m=1:nextra, obj.Schedule(:,m) = obj.List{1,nprop+m}; end
                else
                    obj.CellVal = cell(1,nprop); for m=1:nprop, obj.CellVal{m} = obj.List(:,m); end
                    obj.MaxValIdx = size(obj.List,1);
                    obj.Schedule = [ones(obj.MaxValIdx,1) NaN(obj.MaxValIdx,1)];
                    obj.Schedule(:,1:nextra) = obj.List(:,(1:nextra)+nprop);
                end
            elseif ~isempty(obj.Value)
                if iscell(obj.Value)
                    obj.CellVal = obj.Value;
                    obj.MaxValIdx = size(obj.Value{1},1);
                else
                    obj.CellVal = cell(1,nprop);
                    if 1==nprop
                        obj.CellVal{1} = obj.Value;
                    else
                        for m=1:nprop, obj.CellVal{m} = obj.Value(:,m); end
                    end
                    obj.MaxValIdx = size(obj.Value,1);
                end
                obj.Schedule = [ones(obj.MaxValIdx,1) NaN(obj.MaxValIdx,1)];
                obj.Schedule(:,1) = obj.Step;
            end

            obj.Time = NaN(obj.MaxValIdx*obj.Repetition,1);
            if strcmpi(obj.DurationUnit,'frame')
                obj.Schedule(:,1) = cumsum(obj.Schedule(:,1));
            else
                obj.Schedule(:,1) = cumsum(round(obj.Schedule(:,1) / obj.Tracker.Screen.FrameLength));
            end
            obj.PrevValIdx = NaN;
            obj.bValChanged = false;
            % obj.TimeIdx = 1;  % updated together with bValChanged
            obj.PrevFrame = NaN;

            mglactivategraphic(obj.TargetID,true);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_init(p,true); end
        end
        function fini(obj,p)
            obj.Adapter{1}.fini(p);
            if obj.bValChanged, obj.Time(obj.TimeIdx) = p.LastFlipTime; end
            mglactivategraphic(obj.TargetID,false);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_fini(p); end
        end
        function continue_ = analyze(obj,p)
            obj.Adapter{1}.analyze(p);
            CurrentFrame = p.scene_frame();
            if obj.PrevFrame==CurrentFrame, continue_ = ~obj.Success; return, else, obj.PrevFrame = CurrentFrame; end  % draw only once in one frame

            if obj.bValChanged, obj.Time(obj.TimeIdx) = p.LastFlipTime; end
            repetition = (CurrentFrame + [1 0]) / obj.Schedule(end,1);
            obj.Success = obj.Repetition <= repetition(1);
            continue_ = ~obj.Success;

            ValIdx  = find(mod(CurrentFrame,obj.Schedule(end,1)) < obj.Schedule(:,1),1);
            obj.bValChanged = obj.PrevValIdx ~= ValIdx && repetition(2) < obj.Repetition;
            if obj.bValChanged
                obj.PrevValIdx = ValIdx;
                obj.TimeIdx = floor(repetition(2)) * obj.MaxValIdx + ValIdx;
                p.eventmarker(obj.Schedule(ValIdx,2));

                for m=1:numel(obj.Property)
                    val = obj.CellVal{m}(ValIdx,:);
                    if 1<length(obj.Adapter)
                        for n=1:length(obj.Target{1}), obj.Adapter{2}.(obj.Property{m})(obj.Target{1}(n),:) = val; end
                    else
                        for n=1:length(obj.Target), obj.Tracker.TaskObject.(obj.Property{m})(obj.Target(n),:) = val; end
                    end
                end
            end
        end
        function draw(obj,p)
            obj.Adapter{1}.draw(p);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_draw(p,obj.Target{1}); end
        end
    end
    
    methods (Access = protected)
        function val = namechk(~,val)
            switch lower(val)
                case 'edgecolor', val = 'EdgeColor';
                case 'facecolor', val = 'FaceColor';
                case 'size', val = 'Size';
                case 'position', val = 'Position';
                case 'scale', val = 'Scale';
                case 'angle', val = 'Angle';
                case 'zorder', val = 'Zorder';
                otherwise, error('%s is not a property of graphic objects',val);
            end
        end
    end
end
