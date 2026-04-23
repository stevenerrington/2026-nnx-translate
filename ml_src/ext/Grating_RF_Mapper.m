classdef Grating_RF_Mapper < SineGrating
    properties
        SpatialFrequencyStep = 0.2
        TemporalFrequencyStep = 0.2
        InfoDisplay = false
    end
    properties (Access = protected)
        LB_Hold
        Picked
        PickedPosition
        RB_Hold
        ApertureResize
        PickedRadius
        KB_Hold
        bOldTracker
    end
    methods
        function obj = Grating_RF_Mapper(varargin)
            obj@SineGrating(varargin{:});
            obj.bOldTracker = isprop(obj.Tracker,'MouseData');
            obj.WindowType = 'circular';
        end
        
        function init(obj,p)
            init@SineGrating(obj,p);
            obj.LB_Hold = false;
            obj.Picked = false;
            obj.RB_Hold = false;
            obj.ApertureResize = false;
            obj.KB_Hold = false(1,4);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@SineGrating(obj,p);
            
            % get the mouse and keyboard input
            if obj.bOldTracker
                xydeg = obj.Tracker.CalFun.pix2deg(obj.Tracker.MouseData(end,:));
                left  = mglgetkeystate(37);  % left arrow
                up    = mglgetkeystate(38);  % up arrow
                right = mglgetkeystate(39);  % right arrow
                down  = mglgetkeystate(40);  % down arrow
            else 
                xydeg = obj.Tracker.CalFun.pix2deg(obj.Tracker.XYData(end,:));
                left  = obj.Tracker.KeyInput(end,1);
                up    = obj.Tracker.KeyInput(end,2);
                right = obj.Tracker.KeyInput(end,3);
                down  = obj.Tracker.KeyInput(end,4);
            end
            LB_Down = obj.Tracker.ClickData{1}(end);
            RB_Down = obj.Tracker.ClickData{2}(end);
            
            % mouse control
            r = sqrt(sum((xydeg-obj.Position).^2));
            theta = acosd((xydeg(1)-obj.Position(1))/r);
			if xydeg(2)-obj.Position(2)<0, theta = 360-theta; end
            
            if ~obj.LB_Hold && LB_Down, obj.Picked = true;  obj.LB_Hold = true; obj.PickedPosition = xydeg - obj.Position; end
            if obj.LB_Hold && ~LB_Down, obj.Picked = false; obj.LB_Hold = false; end
            if obj.Picked, obj.Position = xydeg - obj.PickedPosition; end
            
            if ~obj.RB_Hold && RB_Down, obj.ApertureResize = true;  obj.RB_Hold = true; obj.PickedRadius = r - obj.Radius; end
            if obj.RB_Hold && ~RB_Down, obj.ApertureResize = false; obj.RB_Hold = false; end
            if obj.ApertureResize
                apsize = r - obj.PickedRadius;
                if 0<apsize, obj.Radius = apsize; end
            end
            
            if ~obj.Picked && ~obj.ApertureResize && 0<r, obj.Direction = mod(theta,360); end
            
            % keyboard control
            if ~left && obj.KB_Hold(1)
                a = obj.SpatialFrequency - obj.SpatialFrequencyStep;
                if 0<a, obj.SpatialFrequency = a; end
            end
            if ~up && obj.KB_Hold(2)
                obj.TemporalFrequency = obj.TemporalFrequency + obj.TemporalFrequencyStep;
            end
            if ~right && obj.KB_Hold(3)
                obj.SpatialFrequency = obj.SpatialFrequency + obj.SpatialFrequencyStep;
            end
            if ~down && obj.KB_Hold(4)
                a = obj.TemporalFrequency - obj.TemporalFrequencyStep;
                if 0<a, obj.TemporalFrequency = a; end
            end
            obj.KB_Hold = [left up right down];
        end
        function draw(obj,p)
            draw@SineGrating(obj,p);
            if obj.InfoDisplay
                % display some information on the control screen
                p.dashboard(1,sprintf('Position = [%.1f %.1f], Radius = %.1f, Direction = %.1f',obj.Position,obj.Radius,obj.Direction));
                p.dashboard(2,sprintf('SpatialFrequency = %.1f, TemporalFrequency = %.1f',obj.SpatialFrequency,obj.TemporalFrequency));
            end
        end
    end
end
