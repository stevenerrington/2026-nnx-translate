classdef GameManager < mlaggregator
    properties
        PacmanInitPosition = [500 590]
        BlinkyInitPosition = [410 320]
        ClydeInitPosition = [590 320]
        EnergizingDuration = 5000
    end
    properties (SetAccess = protected)
        Pacman
        Blinky
        Clyde
    end
    properties (Access = protected)
        State
        EnergizingEndTime
        CatchCriterion
        CatchFlag
        DyingAnimationStartTime
        DyingAnimationDuration = 3000;
        BlinkyBackToBase
        ClydeBackToBase
    end

    methods
        function obj = GameManager(varargin)
            obj@mlaggregator(varargin{:});
        end
        
        function init(obj,p)
            obj.Pacman = obj.Adapter{1};
            obj.Blinky = obj.Adapter{2};
            obj.Clyde = obj.Adapter{3};

            obj.Pacman.Position = obj.PacmanInitPosition;
            obj.Blinky.Position = obj.BlinkyInitPosition;
            obj.Clyde.Position = obj.ClydeInitPosition;
            obj.EnergizingEndTime = p.trialtime();
            obj.CatchCriterion = prod(obj.Pacman.Size(1:2)) * 0.3;
            obj.CatchFlag = false(1,3);

            init@mlaggregator(obj,p);
        end
        function fini(obj,p)
            fini@mlaggregator(obj,p);
        end
        function continue_ = analyze(obj,p)
            analyze@mlaggregator(obj,p);
            dots = obj.Adapter{6}.GraphicID;
            energizer = obj.Adapter{7}.GraphicID;
            obj.Success = isempty(dots) && isempty(energizer);
            continue_ = ~obj.Success;
            
            % energizing state
            if obj.EnergizingEndTime < p.trialtime(), obj.State = 1; else obj.State = 2; end
            obj.Pacman.State = obj.State;
            obj.Blinky.State = obj.State;
            obj.Clyde.State = obj.State;

            % move units
            wall = obj.Adapter{4}.GraphicID;
            base = obj.Adapter{5}.GraphicID;
            if obj.CatchFlag(2)
                if ~isempty(obj.BlinkyBackToBase)
                    obj.Blinky.Position = obj.BlinkyBackToBase(1,:);
                    obj.BlinkyBackToBase(1,:) = [];
                else
                    obj.CatchFlag(2) = false;
                end
            else
                obj.Blinky.next_position(wall);
            end
            if obj.CatchFlag(3)
                if ~isempty(obj.ClydeBackToBase)
                    obj.Clyde.Position = obj.ClydeBackToBase(1,:);
                    obj.ClydeBackToBase(1,:) = [];
                else
                    obj.CatchFlag(3) = false;
                end
            else
                obj.Clyde.next_position(wall,obj.Pacman);
            end
            if obj.CatchFlag(1)
                elapsed = p.trialtime() - obj.DyingAnimationStartTime;
                if elapsed < obj.DyingAnimationDuration
                    mglsetproperty(obj.Pacman.GraphicID,'angle',obj.Pacman.Angle + 0.36*elapsed);
                else
                    continue_ = false;
                end
            else
                obj.Pacman.next_position([wall base]);
            end
        end
        function draw(obj,p)
            draw@mlaggregator(obj,p);

            if obj.CatchFlag(1), return, end  % return early, if pacman died

            dot = obj.Adapter{6}.GraphicID;
            energizer = obj.Adapter{7}.GraphicID;
            idx = collision_test(obj,obj.Pacman.GraphicID,dot);
            if ~isempty(idx)
                p.goodmonkey(50,'nonblocking',2);
                obj.Adapter{6}.remove_graphic(idx);
            end
            idx = collision_test(obj,obj.Pacman.GraphicID,energizer);
            if ~isempty(idx)
                obj.EnergizingEndTime = p.trialtime() + obj.EnergizingDuration;
                obj.Adapter{7}.remove_graphic(idx);
            end
            
            [idx,rc] = collision_test(obj,obj.Pacman.GraphicID,obj.Blinky.GraphicID(obj.Blinky.CurrentGraphic));
            if ~isempty(idx) && obj.CatchCriterion < calculate_area(obj,rc)
                if 1==obj.State
                    obj.CatchFlag(1) = true; obj.DyingAnimationStartTime = p.trialtime(); obj.Pacman.Direction = 5;
                else
                    obj.CatchFlag(2) = true;
                    obj.BlinkyBackToBase = [linspace(obj.Blinky.Position(1),obj.BlinkyInitPosition(1),obj.Tracker.Screen.RefreshRate*2)' ...
                        linspace(obj.Blinky.Position(2),obj.BlinkyInitPosition(2),obj.Tracker.Screen.RefreshRate*2)'];
                end
            end
            [idx,rc] = collision_test(obj,obj.Pacman.GraphicID,obj.Clyde.GraphicID(obj.Clyde.CurrentGraphic));
            if ~isempty(idx) && obj.CatchCriterion < calculate_area(obj,rc)
                if 1==obj.State
                    obj.CatchFlag(1) = true; obj.DyingAnimationStartTime = p.trialtime(); obj.Pacman.Direction = 5;
                else
                    obj.CatchFlag(3) = true;
                    obj.ClydeBackToBase = [linspace(obj.Clyde.Position(1),obj.ClydeInitPosition(1),obj.Tracker.Screen.RefreshRate*2)' ...
                        linspace(obj.Clyde.Position(2),obj.ClydeInitPosition(2),obj.Tracker.Screen.RefreshRate*2)'];
                end
            end
        end
        function [idx,rc] = collision_test(~,me,target)
            me_rc = mglgetproperty(me,'rect');
            ntarget = numel(target);
            target_rc = zeros(ntarget,4);
            for m=1:ntarget, target_rc(m,:) = mglgetproperty(target(m),'rect'); end
            rc = IntersectRect(me_rc,target_rc);
            idx = find(0 < rc(:,3)-rc(:,1));
        end
        function area = calculate_area(~,rc), area = (rc(3)-rc(1))*(rc(4)-rc(2)); end
    end
end
