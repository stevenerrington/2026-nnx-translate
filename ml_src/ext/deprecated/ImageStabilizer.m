classdef ImageStabilizer < mlaggregator
    properties
        Target = []
        FixPoint = [0 0]
        Axis = 3  % 0: none, 1: X axis, 2: Y axis, 3: X & Y
    end
    properties (Access = protected)
        TargetID
        GraphicIdx
        ImagePosition
    end

    methods
        function obj = ImageStabilizer(varargin)
            obj@mlaggregator(varargin{:});
        end
        function set.Target(obj,val)
            if isobject(val)  % graphic adapters
                if ~isa(val,'mlgraphic'), error('Target must be a graphic adapter.'); end
                obj.Adapter{2} = val;
                if isempty(obj.GraphicIdx) %#ok<*MCSUP> 
                    obj.Target = {1};
                else
                    if ~isscalar(obj.GraphicIdx), error('Target must be a single object.'); end
                    obj.Target = {obj.GraphicIdx}; obj.GraphicIdx = [];
                end
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
            obj.GraphicIdx = idx;
            obj.Target = val;
        end
        
        function init(obj,p)
            obj.Adapter{1}.init(p);
            if isempty(obj.Target)
                obj.ImagePosition = obj.Adapter{1}.Position;
            else
                if 1<length(obj.Adapter)
                    obj.ImagePosition = obj.Adapter{2}.Position(obj.Target{1},:);
                else
                    obj.ImagePosition = obj.Tracker.TaskObject.Position(obj.Target,:);
                end
            end
            mglactivategraphic(obj.TargetID,true);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_init(p,true); end
        end
        function fini(obj,p)
            obj.Adapter{1}.fini(p);
            if isempty(obj.Target)
                obj.Adapter{1}.Position = obj.ImagePosition;
            else
                if 1<length(obj.Adapter)
                    obj.Adapter{2}.Position(obj.Target{1},:) = obj.ImagePosition;
                else
                    obj.Tracker.TaskObject.Position(obj.Target,:) = obj.ImagePosition;
                end
            end
            mglactivategraphic(obj.TargetID,false);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_fini(p); end
        end
        function continue_ = analyze(obj,p)
            continue_ = obj.Adapter{1}.analyze(p);
            obj.Success = obj.Adapter{1}.Success;

            data = obj.Tracker.XYData;
            if isempty(data), return, end
            
            displacement = obj.Tracker.CalFun.pix2deg(median(data(:,1:2),1)) - obj.FixPoint;
            switch obj.Axis
                case 0, displacement(1:2) = 0;
                case 1, displacement(2) = 0;
                case 2, displacement(1) = 0;
            end
            
            img_pos = obj.ImagePosition + repmat(displacement,size(obj.ImagePosition,1),1);
            if isempty(obj.Target)
                obj.Adapter{1}.Position = img_pos;
            else
                if 1<length(obj.Adapter)
                    obj.Adapter{2}.Position(obj.Target{1},:) = img_pos;
                else
                    obj.Tracker.TaskObject.Position(obj.Target,:) = img_pos;
                end
            end
        end
        function draw(obj,p)
            obj.Adapter{1}.draw(p);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_draw(p,obj.Target{1}); end
        end
    end
end
