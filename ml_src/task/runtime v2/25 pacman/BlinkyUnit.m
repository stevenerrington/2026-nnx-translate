classdef BlinkyUnit < mladapter
    properties
        State
        Position
    end
    properties (SetAccess = protected)
        GraphicID
        CurrentGraphic
    end
    properties (Access = protected)
        Speed
        Direction
    end

    methods
        function obj = BlinkyUnit(varargin)
            obj@mladapter(varargin{:});

            load('graphicdata.mat','blinky_left_graphic','blinky_up_graphic','blinky_right_graphic','blinky_down_graphic','ghost_graphic');
            obj.GraphicID(1) = mgladdmovie(blinky_left_graphic,100);
            obj.GraphicID(2) = mgladdmovie(blinky_up_graphic,100);
            obj.GraphicID(3) = mgladdmovie(blinky_right_graphic,100);
            obj.GraphicID(4) = mgladdmovie(blinky_down_graphic,100);
            obj.GraphicID(5) = mgladdmovie(ghost_graphic,500);
            mglsetproperty(obj.GraphicID,'active',false,'looping',true);

            obj.State = 1;
            obj.Position = obj.Tracker.Screen.SubjectScreenHalfSize + [100 0];
            obj.Speed = round([270 135] / obj.Tracker.Screen.RefreshRate);
            obj.Direction = 5;
            obj.CurrentGraphic = 3;
        end
        function delete(obj), mgldestroygraphic(obj.GraphicID); end

        function init(obj,p)
            init@mladapter(obj,p);
            mglsetproperty(obj.GraphicID,'origin',obj.Position);
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.GraphicID,false);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
        end
        function draw(obj,p)
            draw@mladapter(obj,p);

            switch obj.State  % 1: chasing, 2: scared
                case 1, if obj.Direction<5, obj.CurrentGraphic = obj.Direction; end
                case 2, obj.CurrentGraphic = 5;
            end
            mglactivategraphic(obj.GraphicID,false);
            mglsetproperty(obj.GraphicID(obj.CurrentGraphic),'active',true,'origin',obj.Position);
        end
        
        function next_position(obj,wall)
            % speed
            speed = obj.Speed(obj.State);
            d = [-speed 0; 0 -speed; speed 0; 0 speed];

            me_rc = mglgetproperty(obj.GraphicID(obj.CurrentGraphic),'rect');
            rc = cell(1,4);
            collided = false(1,4);
            open = zeros(4,4);
            gap = zeros(4,4);
            for m=1:4  % 1: left, 2: up, 3: right, 4: down, 5: undertermined
                rc{m} = collision_test(obj,me_rc + repmat(d(m,:),1,2),wall);
                row = find(0 < rc{m}(:,3)-rc{m}(:,1));
                if isempty(row), continue, end
                collided(m) = true;
                overlap = [min(rc{m}(row,1:2),[],1) max(rc{m}(row,3:4),[],1)];
                open(m,:) = abs(diff([me_rc + repmat(d(m,:),1,2);overlap]));
                gap(m,:) = abs(diff([me_rc;overlap([3 4 1 2])]));
            end
            idx = find(~collided);
            if 5==obj.Direction, obj.Direction = idx(ceil(rand*length(idx))); end
            
            switch obj.Direction
                case 1  % left
                    if collided(1)
                        obj.Direction = 5; obj.Position = obj.Position + [-gap(1,1) 0];
                    elseif 0<open(4,1) && gap(4,3)<=speed
                        obj.Direction = 5; obj.Position = obj.Position + [-gap(4,3) 0];
                    elseif 0<open(2,1) && gap(2,3)<=speed
                        obj.Direction = 5; obj.Position = obj.Position + [-gap(2,3) 0];
                    else
                        obj.Position = obj.Position + d(obj.Direction,:);
                    end
                case 2  % up
                    if collided(2)
                        obj.Direction = 5; obj.Position = obj.Position + [0 -gap(2,2)];
                    elseif 0<open(1,2) && gap(1,4)<=speed
                        obj.Direction = 5; obj.Position = obj.Position + [0 -gap(1,4)];
                    elseif 0<open(3,2) && gap(3,4)<=speed
                        obj.Direction = 5; obj.Position = obj.Position + [0 -gap(3,4)];
                    else
                        obj.Position = obj.Position + d(obj.Direction,:);
                    end
                case 3  % right
                    if collided(3)
                        obj.Direction = 5; obj.Position = obj.Position + [gap(3,3) 0];
                    elseif 0<open(2,3) && gap(2,1)<=speed
                        obj.Direction = 5; obj.Position = obj.Position + [gap(2,1) 0];
                    elseif 0<open(4,3) && gap(4,1)<=speed
                        obj.Direction = 5; obj.Position = obj.Position + [gap(4,1) 0];
                    else
                        obj.Position = obj.Position + d(obj.Direction,:);
                    end
                case 4  % down
                    if collided(4)
                        obj.Direction = 5; obj.Position = obj.Position + [0 gap(4,4)];
                    elseif 0<open(3,4) && gap(3,2)<=speed
                        obj.Direction = 5; obj.Position = obj.Position + [0 gap(3,2)];
                    elseif 0<open(1,4) && gap(1,2)<=speed
                        obj.Direction = 5; obj.Position = obj.Position + [0 gap(1,2)];
                    else
                        obj.Position = obj.Position + d(obj.Direction,:);
                    end
            end
        end
        function rc = collision_test(~,me_rc,target)
            ntarget = numel(target);
            target_rc = zeros(ntarget,4);
            for m=1:ntarget, target_rc(m,:) = mglgetproperty(target(m),'rect'); end
            rc = IntersectRect(me_rc,target_rc);
        end
    end
end
