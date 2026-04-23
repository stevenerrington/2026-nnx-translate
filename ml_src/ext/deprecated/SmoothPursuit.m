classdef SmoothPursuit < mlaggregator
    properties
        Target              % TaskObject number
        Threshold = 0;      % fixation window size in visual degrees
        Color = [0 1 0];    % fixation window color
        Origin              % [xdeg ydeg]
        Direction           % 0 to 360 deg
        Speed               % deg/s
        Duration            % msec
    end
    properties (SetAccess = protected)
        Time
    end
    properties (Access = protected)
        TargetID
        FixWindowID
        ThresholdInPixels
        ScrOrigin
        ScrDisplacement
        GraphicIdx
    end
    
    methods
        function obj = SmoothPursuit(varargin)
            obj@mlaggregator(varargin{:});
        end
        function delete(obj), destroy_fixwindow(obj); end
        
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
        function set.Threshold(obj,threshold)
            if ~isscalar(threshold), error('Threshold must be a scalar'); end
            if ~isempty(obj.Threshold) && threshold==obj.Threshold, return, end
            obj.Threshold = threshold;
            create_fixwindow(obj);
        end
        function set.Color(obj,color)
            if 3~=numel(color), error('Color must be a 1-by-3 vector'); end
            color = color(:)';
            if ~isempty(obj.Color) && all(color==obj.Color), return, end
            obj.Color = color;
            create_fixwindow(obj);
        end
        function set.Origin(obj,val)
            if 2~=length(val), error('Origin must be a 1-by-2 vector'); end
            obj.Origin = val(:)';
            calculate_displacement(obj);
        end
        function set.Direction(obj,val)
            if 1~=numel(val), error('Direction must be a scalar'); end
            obj.Direction = val;
            calculate_displacement(obj);
        end
        function set.Speed(obj,val)
            if 1~=numel(val), error('Speed must be a scalar'); end
            obj.Speed = val;
            calculate_displacement(obj);
        end
        
        function init(obj,p)
            obj.Adapter{1}.init(p);
            obj.Success = false;
            mglactivategraphic([obj.TargetID obj.FixWindowID],true);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_init(p,true); end
        end
        function fini(obj,p)
            obj.Adapter{1}.fini(p);
            mglactivategraphic([obj.TargetID obj.FixWindowID],false);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_fini(p); end
        end
        function continue_ = analyze(obj,p)
            obj.Adapter{1}.analyze(p);

            scr_pos = obj.ScrOrigin + p.scene_frame() * obj.ScrDisplacement;
            pos = obj.Tracker.CalFun.pix2deg(scr_pos);
            mglsetorigin(obj.FixWindowID,scr_pos);
            if isempty(obj.Target)
                obj.Adapter{1}.Position = pos;
            else
                if 1<length(obj.Adapter)
                    obj.Adapter{2}.Position(obj.Target{1},:) = pos;
                else
                    obj.Tracker.TaskObject.Position(obj.Target,:) = pos;
                end
            end

            continue_ = true;
            if p.scene_time() < obj.Duration
                data = obj.Tracker.XYData;
                ndata = size(data,1);
                if 0==ndata, return, end
                
                in = find(obj.ThresholdInPixels < sum((data-repmat(scr_pos,ndata,1)).^2,2),1);
                if ~isempty(in)
                    obj.Time = obj.Tracker.LastSamplePosition + in;
                    continue_ = false;
                    return
                end
            else
                obj.Success = true;
                continue_ = false;
            end
        end
        function draw(obj,p)
            obj.Adapter{1}.draw(p);
            if 1<length(obj.Adapter), obj.Adapter{2}.animate_draw(p,obj.Target{1}); end
        end
    end
    
    methods (Access = protected)
        function create_fixwindow(obj)
            if isempty(obj.Threshold), return, end
            destroy_fixwindow(obj);
            
            threshold_in_pixels = obj.Threshold * obj.Tracker.Screen.PixelsPerDegree;
            obj.FixWindowID = mgladdcircle(obj.Color,threshold_in_pixels*2,10);
            obj.ThresholdInPixels = threshold_in_pixels^2;
            mglactivategraphic(obj.FixWindowID,false);
        end
        function destroy_fixwindow(obj), mgldestroygraphic(obj.FixWindowID); obj.FixWindowID = []; end
        function calculate_displacement(obj)
            if isempty(obj.Origin) || isempty(obj.Direction) || isempty(obj.Speed), return, end
            obj.ScrOrigin = obj.Tracker.CalFun.deg2pix(obj.Origin);
            obj.ScrDisplacement = [cosd(obj.Direction) -sind(obj.Direction)] * obj.Speed * obj.Tracker.Screen.PixelsPerDegree / obj.Tracker.Screen.RefreshRate;
        end
    end
end
