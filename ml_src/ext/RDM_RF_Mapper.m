classdef RDM_RF_Mapper < RandomDotMotion
    properties
        CoherenceStep = 5;
        SpeedStep = 0.5
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
        function obj = RDM_RF_Mapper(varargin)
            obj@RandomDotMotion(varargin{:});
            obj.bOldTracker = isprop(obj.Tracker,'MouseData');
        end
        function init(obj,p)
            init@RandomDotMotion(obj,p);
            obj.LB_Hold = false;
            obj.Picked = false;
            obj.RB_Hold = false;
            obj.ApertureResize = false;
            obj.KB_Hold = false(1,4);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@RandomDotMotion(obj,p);
            
            % get the mouse position
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
            
            % calculate its polar coordinates
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

            if ~obj.Picked && ~obj.ApertureResize && 0<r, obj.Direction = theta; end
            
            % keyboard control
            if ~left && obj.KB_Hold(1)
                a = obj.Coherence - obj.CoherenceStep;
                if 0<=a, obj.Coherence = a; end
            end
            if ~up && obj.KB_Hold(2)
                obj.Speed = obj.Speed + obj.SpeedStep;
            end
            if ~right && obj.KB_Hold(3)
                a = obj.Coherence + obj.CoherenceStep;
                if a<=100, obj.Coherence = a; end
            end
            if ~down && obj.KB_Hold(4)
                a = obj.Speed - obj.SpeedStep;
                if 0<a, obj.Speed = a; end
            end
            obj.KB_Hold = [left up right down];
        end
        function draw(obj,p)
            draw@RandomDotMotion(obj,p);
            if obj.InfoDisplay
                % display some information on the control screen
                p.dashboard(1,sprintf('Position = [%.1f %.1f], Radius = %.1f, Direction = %.1f',obj.Position,obj.Radius,obj.Direction));
                p.dashboard(2,sprintf('Coherence = %d, Speed = %.1f',obj.Coherence,obj.Speed));
            end
        end
    end
end
