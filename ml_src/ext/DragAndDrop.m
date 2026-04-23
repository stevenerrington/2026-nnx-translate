classdef DragAndDrop < mlaggregator
    properties
        Destination        % [x y] in degrees
        Gravity = 5        % degrees per second
        GravityWindow = 3  % radius in degrees; [width height] for a rectangular window
        Color = [0 1 0]    % color of the gravity window
        Target = 1         % Target should be settable, for replay
    end
    properties (SetAccess = protected)
        DropTime
        DroppedDestination
    end
    properties (Access = protected)
        TargetID
        WindowID
        InitPosition
        nDestination
        DestinationOnDrop
        GravityWindowSize
        Dropped
        GraphicIdx
    end
    
    methods
        function obj = DragAndDrop(varargin)
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
            obj.GraphicIdx = idx(:)';
            obj.Target = val;
        end
        function reset(obj)
            if isempty(obj.Target), return, end
            if 1<length(obj.Adapter), obj.Adapter{2}.Position(obj.Target{1},:) = obj.InitPosition; else, obj.Tracker.TaskObject.Position(obj.Target,:) = obj.InitPosition; end
        end

        function init(obj,p)
            obj.Adapter{1}.init(p);
            
            if 1<length(obj.Adapter), obj.InitPosition = obj.Adapter{2}.Position(obj.Target{1},:); else, obj.InitPosition = obj.Tracker.TaskObject.Position(obj.Target,:); end
            obj.DestinationOnDrop = obj.InitPosition;
            destination_pix = round(obj.Tracker.CalFun.deg2pix(obj.Destination));
            gravity_win_pix = obj.GravityWindow * p.Screen.PixelsPerDegree;

            obj.nDestination = size(obj.Destination,1);
            obj.WindowID = NaN(1,obj.nDestination);
            if isscalar(obj.GravityWindow)
                for m=1:obj.nDestination, obj.WindowID(m) = mgladdcircle(obj.Color,2*gravity_win_pix,10); end
                mglsetorigin(obj.WindowID,destination_pix);
                obj.GravityWindowSize = obj.GravityWindow^2;
            else
                for m=1:obj.nDestination, obj.WindowID(m) = mgladdbox(obj.Color,gravity_win_pix,10); end
                mglsetorigin(obj.WindowID,destination_pix);
                d = repmat(0.5*obj.GravityWindow,obj.nDestination,1);
                obj.GravityWindowSize = [obj.Destination-d obj.Destination+d];
            end
            
            obj.Dropped = false;
            obj.DropTime = 0;
            obj.DroppedDestination = 0;
            
            mglactivategraphic(obj.TargetID,true);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_init(p,true); end
        end
        function fini(obj,p)
            obj.Adapter{1}.fini(p);
            mgldestroygraphic(obj.WindowID);
            mglactivategraphic(obj.TargetID,false);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_fini(p); end
        end
        function continue_ = analyze(obj,p)
            obj.Adapter{1}.analyze(p);

            xy_pix = obj.Tracker.XYData(end,1:2);
            if ~obj.Dropped && isnan(xy_pix(1))
                obj.Dropped = true;
                obj.DropTime = obj.Tracker.LastSamplePosition + find(isnan(obj.Tracker.XYData(:,1)),1) - 1;
            end
            
            if 1<length(obj.Adapter), pos = obj.Adapter{2}.Position(obj.Target{1},:); else, pos = obj.Tracker.TaskObject.Position(obj.Target,:); end
            if ~obj.Dropped
                xy = obj.Tracker.CalFun.pix2deg(xy_pix);  % degree
                if 1<length(obj.Adapter), obj.Adapter{2}.Position(obj.Target{1},:) = xy; else, obj.Tracker.TaskObject.Position(obj.Target,:) = xy; end
                if isscalar(obj.GravityWindow)
                    hover = find(sum((obj.Destination-repmat(xy,obj.nDestination,1)).^2,2) < obj.GravityWindowSize,1);
                else
                    rc = obj.GravityWindowSize;
                    hover = find(rc(:,1)<xy(1) & xy(1)<rc(:,3) & rc(:,2)<xy(2) & xy(2)<rc(:,4),1);
                end
                if isempty(hover)
                    obj.DestinationOnDrop = obj.InitPosition;
                    obj.DroppedDestination = 0;
                else
                    obj.DestinationOnDrop = obj.Destination(hover,:);
                    obj.DroppedDestination = hover;
                end
            elseif any(pos~=obj.DestinationOnDrop)
                d = obj.DestinationOnDrop - pos;
                theta = atan2(d(2),d(1)) * 180 / pi;  % atan2d is introduced in R2012b
                elapsed = (p.trialtime() - obj.DropTime) / 1000;  % in seconds
                delta = obj.Gravity * elapsed;
                if sum(d.^2) < delta*delta, next_pos = obj.DestinationOnDrop; pos = next_pos; else, next_pos = pos + delta * [cosd(theta) sind(theta)]; end
                if 1<length(obj.Adapter), obj.Adapter{2}.Position(obj.Target{1},:) = next_pos; else, obj.Tracker.TaskObject.Position(obj.Target,:) = next_pos; end
            end

            obj.Success = any(all(repmat(pos,obj.nDestination,1)==obj.Destination,2));
            continue_ = ~obj.Dropped || ~all(pos==obj.DestinationOnDrop);
        end
        function draw(obj,p)
            obj.Adapter{1}.draw(p);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_draw(p,obj.Target{1}); end
        end
    end
end
