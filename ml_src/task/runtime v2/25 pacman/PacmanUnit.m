classdef PacmanUnit < mladapter
    properties
        State
        Position
        Direction
    end
    properties (SetAccess = protected)
        Size
        Angle
        GraphicID
    end
    properties (Access = protected)
        JoystickRestingArea = 1  % radius in degrees
        Speed
        LastDirection
    end

    methods
        function obj = PacmanUnit(varargin)
            obj@mladapter(varargin{:});
            
            load('graphicdata.mat','pacman_graphic');
            obj.Size = size(pacman_graphic);
            obj.Angle = 0;
            obj.GraphicID = mgladdmovie(pacman_graphic,250);
            mglsetproperty(obj.GraphicID,'active',false,'looping',true);

            obj.State = 1;
            obj.Position = obj.Tracker.Screen.SubjectScreenHalfSize;
            obj.Speed = round([270 540] / obj.Tracker.Screen.RefreshRate);
            obj.Direction = 5;
            obj.LastDirection = 3;
        end
        function delete(obj), mgldestroygraphic(obj.GraphicID); end
        
        function init(obj,p)
            init@mladapter(obj,p);
            mglactivategraphic(obj.GraphicID,true);
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
            
            switch obj.Direction  % 1: left, 2: up, 3: right, 4: down, 5: neutral
                case 1, obj.Angle = 180; mglsetproperty(obj.GraphicID,'angle',obj.Angle,'resume');
                case 2, obj.Angle = 90;  mglsetproperty(obj.GraphicID,'angle',obj.Angle,'resume');
                case 3, obj.Angle = 0;   mglsetproperty(obj.GraphicID,'angle',obj.Angle,'resume');
                case 4, obj.Angle = 270; mglsetproperty(obj.GraphicID,'angle',obj.Angle,'resume');
                case 5, mglsetproperty(obj.GraphicID,'pause');
            end
            mglsetproperty(obj.GraphicID,'origin',obj.Position);
        end
        
        function next_position(obj,wall)
            data = obj.Tracker.XYData;
            if isempty(data), return, end
            
            % speed
            speed = obj.Speed(obj.State);
            displacement = [-speed 0; 0 -speed; speed 0; 0 speed; 0 0];

            % joystick position
            xydeg = obj.Tracker.CalFun.pix2deg(data(end,1:2));
            r = sqrt(sum(xydeg.^2));
            theta = acosd(xydeg(1)/r);
            if xydeg(2)<0, theta = 360-theta; end
            
            if r<obj.JoystickRestingArea || isnan(theta)
                new_direction = 5;
            elseif 135<=theta && theta<225
                new_direction = 1;
            elseif 45<=theta && theta<135
                new_direction = 2;
            elseif 225<=theta && theta<315
                new_direction = 4;
            else
                new_direction = 3;
            end

            % move pacman
            for m=1:2
                d = displacement(new_direction,:);
                me_rc = mglgetproperty(obj.GraphicID,'rect');
                rc = collision_test(obj,me_rc + [d d],wall);
                row = find(0 < rc(:,3)-rc(:,1));
                if isempty(row)  % no wall to the moving direction
                    obj.Direction = new_direction;
                    obj.Position = obj.Position + d;
                else
                    overlap = [min(rc(row,1:2),[],1) max(rc(row,3:4),[],1)];
                    open = abs(diff([me_rc + [d d];overlap]));
                    gap = abs(diff([me_rc;overlap([3 4 1 2])]));
                    switch obj.Direction
                        case 1  % left
                            switch new_direction
                                case 1, obj.Direction = 5; obj.Position = obj.Position + [-gap(1) 0];
                                case 4, if speed<gap(3), new_direction = 1; continue, else obj.Direction = 4; obj.Position = obj.Position + [-gap(3) speed-gap(3)]; end
                                case 2, if speed<gap(3), new_direction = 1; continue, else obj.Direction = 2; obj.Position = obj.Position + [-gap(3) gap(3)-speed]; end
                            end
                        case 2  % up
                            switch new_direction
                                case 2, obj.Direction = 5; obj.Position = obj.Position + [0 -gap(2)];
                                case 1, if speed<gap(4), new_direction = 2; continue, else obj.Direction = 1; obj.Position = obj.Position + [gap(4)-speed -gap(4)]; end
                                case 3, if speed<gap(4), new_direction = 2; continue, else obj.Direction = 3; obj.Position = obj.Position + [speed-gap(4) -gap(4)]; end
                            end
                        case 3  % right
                            switch new_direction
                                case 3, obj.Direction = 5; obj.Position = obj.Position + [gap(3) 0];
                                case 2, if speed<gap(1), new_direction = 3; continue, else obj.Direction = 2; obj.Position = obj.Position + [gap(1) gap(1)-speed]; end
                                case 4, if speed<gap(1), new_direction = 3; continue, else obj.Direction = 4; obj.Position = obj.Position + [gap(1) speed-gap(1)]; end
                            end
                        case 4  % down
                            switch new_direction
                                case 4, obj.Direction = 5; obj.Position = obj.Position + [0 gap(4)];
                                case 3, if speed<gap(2), new_direction = 4; continue, else obj.Direction = 3; obj.Position = obj.Position + [speed-gap(2) gap(2)]; end
                                case 1, if speed<gap(2), new_direction = 4; continue, else obj.Direction = 1; obj.Position = obj.Position + [gap(2)-speed gap(2)]; end
                            end
                        case 5  % neutral
                            switch new_direction
                                case {1,3}, if 2==obj.LastDirection && 0<open(2) || 4==obj.LastDirection && 0<open(4), new_direction = obj.LastDirection; continue, end
                                case {2,4}, if 1==obj.LastDirection && 0<open(3) || 3==obj.LastDirection && 0<open(1), new_direction = obj.LastDirection; continue, end
                            end
                    end
                end
                break
            end
            if 5~=obj.Direction, obj.LastDirection = obj.Direction; end
        end
        function rc = collision_test(~,me_rc,target)
            ntarget = numel(target);
            target_rc = zeros(ntarget,4);
            for m=1:ntarget, target_rc(m,:) = mglgetproperty(target(m),'rect'); end
            rc = IntersectRect(me_rc,target_rc);
        end
    end
end
