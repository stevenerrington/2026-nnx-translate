classdef BrickBreaker < mladapter
    properties
        WallThickness  % in pixels
        WallColor      % [R G B]
        BallSize       % in pixels
        BallPos        % in pixels
        BallColor      % [R G B]
        PaddleSize
        PaddlePos
        PaddleColor
        Brick1Size
        Brick1Pos
        Brick1Color
        Brick2Size
        Brick2Pos
        Brick2Color
        BallDirection  % degrees in the clockwise direction
        BallSpeed      % pixels per sec
        BounceJitter   % degrees
        
        RandomNumberPool
        RandomNumberIndex = 0
        LastUpdateTime
    end
    properties (SetAccess = protected)
        CollidedBrick
    end
    properties (Access = protected)
        ScrSize
        Ball
        Paddle
        Brick1
        Brick2
        Wall
    end
    
    methods
        function obj = BrickBreaker(varargin)
            obj@mladapter(varargin{:});
            
            % default values
            obj.WallThickness = 20;
            obj.WallColor = [0.5 0.5 0.5];
            obj.BallSize = [20 20];
            obj.BallColor = [1 1 1];
            obj.PaddleSize = [120 8];
            obj.PaddleColor = [0 1 0];
            obj.Brick1Size = [120 60];
            obj.Brick1Color = [1 0 0];
            obj.Brick2Size = [120 60];
            obj.Brick2Color = [0 0 1];
            obj.BallSpeed = 400;
            obj.BounceJitter = 30;

            obj.ScrSize = obj.Tracker.Screen.SubjectScreenFullSize;
            if rand < 0.5, obj.BallDirection = 210 + rand*30; else obj.BallDirection = 300 + rand*30; end

            % create graphic objects and set initial positions
            obj.BallPos = [rand*(obj.ScrSize(1)-obj.BallSize(1)-2*obj.WallThickness) + obj.WallThickness + 0.5*obj.BallSize(1) ...
                0.75*(obj.ScrSize(2)-2*obj.WallThickness) + obj.WallThickness];
            obj.PaddlePos = [0.5*obj.ScrSize(1) obj.ScrSize(2)-obj.WallThickness];
            obj.Brick1Pos = new_brick_position(obj,obj.Brick1Size);
            obj.Brick2Pos = new_brick_position(obj,obj.Brick2Size);
            
            obj.Ball = mgladdcircle([obj.BallColor; obj.BallColor],obj.BallSize);
            obj.Paddle = mgladdbox([obj.PaddleColor; obj.PaddleColor],obj.PaddleSize);
            obj.Brick1 = mgladdbox([obj.Brick1Color; obj.Brick1Color],obj.Brick1Size);
            obj.Brick2 = mgladdbox([obj.Brick2Color; obj.Brick2Color],obj.Brick2Size);
            obj.Wall(1) = mgladdbox([obj.WallColor; obj.WallColor],[obj.WallThickness obj.ScrSize(2)]);
            obj.Wall(2) = mgladdbox([obj.WallColor; obj.WallColor],[obj.WallThickness obj.ScrSize(2)]);
            obj.Wall(3) = mgladdbox([obj.WallColor; obj.WallColor],[obj.ScrSize(1) obj.WallThickness]);
            mglactivategraphic([obj.Ball obj.Paddle obj.Brick1 obj.Brick2 obj.Wall],false);
            
            mglsetorigin(obj.Ball,obj.BallPos);
            mglsetorigin(obj.Paddle,obj.PaddlePos);
            mglsetorigin(obj.Brick1,obj.Brick1Pos);
            mglsetorigin(obj.Brick2,obj.Brick2Pos);
            mglsetorigin(obj.Wall(1),0.5*[obj.WallThickness obj.ScrSize(2)]);
            mglsetorigin(obj.Wall(2),[obj.ScrSize(1)-0.5*obj.WallThickness 0.5*obj.ScrSize(2)]);
            mglsetorigin(obj.Wall(3),0.5*[obj.ScrSize(1) obj.WallThickness]);
            
            while collision_test(obj,obj.Brick1,obj.Brick2)
                obj.Brick2Pos = new_brick_position(obj,obj.Brick2Size);
                mglsetorigin(obj.Brick2,obj.Brick2Pos);
            end
       end
        function delete(obj)
            mgldestroygraphic([obj.Ball obj.Paddle obj.Brick1 obj.Brick2 obj.Wall]);
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            mglsetorigin(obj.Ball,obj.BallPos);
            mglsetorigin(obj.Paddle,obj.PaddlePos);
            mglsetorigin(obj.Brick1,obj.Brick1Pos);
            mglsetorigin(obj.Brick2,obj.Brick2Pos);
            mglactivategraphic([obj.Ball obj.Paddle obj.Brick1 obj.Brick2 obj.Wall],true);
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic([obj.Ball obj.Paddle obj.Brick1 obj.Brick2 obj.Wall],false);
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            
            elapsed = p.trialtime();
            if isempty(obj.LastUpdateTime), obj.LastUpdateTime = elapsed; end
            
            % move the paddle
            if ~isempty(obj.Tracker.XYData)
                xpos = obj.Tracker.XYData(end,1);
                min_xpos = obj.WallThickness + 0.5*obj.PaddleSize(1);
                max_xpos = obj.ScrSize(1) - obj.WallThickness - 0.5*obj.PaddleSize(1);
                obj.PaddlePos = [min(max_xpos,max(min_xpos,xpos)) obj.PaddlePos(2)];
                mglsetorigin(obj.Paddle,obj.PaddlePos);
            end
            
            % move the ball
            for n=1:round(0.001 * (elapsed-obj.LastUpdateTime) * obj.BallSpeed)
                already_collided = collision_test(obj,obj.Ball,obj.Paddle);
                next_pos = obj.BallPos + [cosd(obj.BallDirection) sind(obj.BallDirection)];
                mglsetorigin(obj.Ball,next_pos);  % need to move the stimuli temporarily to do the collision test
                
                [tf,rc] = collision_test(obj,obj.Ball,[obj.Brick1 obj.Brick2 obj.Paddle obj.Wall]);  % collision test
                for m=find(tf')
                    switch m
                        case 1  % brick 1
                            obj.CollidedBrick = m;
                            obj.Success = true;
                            obj.Brick1Pos = new_brick_position(obj,obj.Brick1Size);
                            mglsetorigin(obj.Brick1,obj.Brick1Pos);
                            while any(collision_test(obj,obj.Brick1,[obj.Ball obj.Brick2]))
                                obj.Brick1Pos = new_brick_position(obj,obj.Brick1Size);
                                mglsetorigin(obj.Brick1,obj.Brick1Pos);
                            end
                        case 2  % brick 2
                            obj.CollidedBrick = m;
                            obj.Success = true;
                            obj.Brick2Pos = new_brick_position(obj,obj.Brick2Size);
                            mglsetorigin(obj.Brick2,obj.Brick2Pos);
                            while any(collision_test(obj,obj.Brick2,[obj.Ball obj.Brick1]))
                                obj.Brick2Pos = new_brick_position(obj,obj.Brick2Size);
                                mglsetorigin(obj.Brick2,obj.Brick2Pos);
                            end
                        case 3  % paddle
                            if already_collided, continue, end  % The ball is passing through the paddle. Do not let the ball bounce.
                    end
                    
                    sz = rc(m,3:4) - rc(m,1:2);        % size of collision area
                    ct = 0.5*(rc(m,1:2) + rc(m,3:4));  % center of collision area
                    if ct(1)==obj.BallPos(1) || ct(2)==obj.BallPos(2)  % perpendicular hit
                        obj.BallDirection = obj.BallDirection + 180;
                    elseif sz(1) < sz(2)     % x-direction hit
                        if ct(1) < obj.BallPos(1)
                            if ct(2) < obj.BallPos(2)  % target on the top-left
                                obj.BallDirection = obj.BallDirection + 2*(270-obj.BallDirection);
                            else                 % target on the bottom-left
                                obj.BallDirection = obj.BallDirection - 2*(obj.BallDirection-90);
                            end
                        else
                            if ct(2) < obj.BallPos(2)  % target on the top-right
                                obj.BallDirection = obj.BallDirection - 2*(obj.BallDirection-270);
                            else                 % target on the botton-right
                                obj.BallDirection = obj.BallDirection + 2*(90-obj.BallDirection);
                            end
                        end
                    else  % y-direction hit
                        if ct(2) < obj.BallPos(2)
                            if ct(1) < obj.BallPos(1)  % target on the top-left
                                obj.BallDirection = obj.BallDirection - 2*(obj.BallDirection-180);
                            else                 % target on the top-right
                                obj.BallDirection = obj.BallDirection + 2*(360-obj.BallDirection);
                            end
                        else
                            if ct(1) < obj.BallPos(1)  % target on the bottom-left
                                obj.BallDirection = obj.BallDirection + 2*(180-obj.BallDirection);
                            else                 % target on the botton-right
                                obj.BallDirection = obj.BallDirection - 2*obj.BallDirection;
                            end
                        end
                    end
                    
                    if m<4  % add some jitter to the bounce angle if it is not the wall
                        obj.BallDirection = mod(obj.BallDirection,360);
                        if 0==obj.BallDirection || 90==obj.BallDirection || 90==obj.BallDirection || 270==obj.BallDirection
                            obj.BallDirection = obj.BallDirection + (rand(obj)-0.5) * obj.BounceJitter;
                        else
                            if 0<obj.BallDirection && obj.BallDirection<90
                                range = [0 90];
                            elseif 90<obj.BallDirection && obj.BallDirection<180
                                range = [90 190];
                            elseif 180<obj.BallDirection && obj.BallDirection<270
                                range = [180 270];
                            else
                                range = [270 360];
                            end
                            new_dir = obj.BallDirection + (rand(obj)-0.5) * obj.BounceJitter;
                            while new_dir<=range(1) || range(2)<=new_dir
                                new_dir = obj.BallDirection + (rand(obj)-0.5) * obj.BounceJitter;
                            end
                            obj.BallDirection = new_dir;
                        end
                    end
                    obj.BallDirection = mod(obj.BallDirection,360);
                end
                
                obj.BallPos = obj.BallPos + [cosd(obj.BallDirection) sind(obj.BallDirection)];
            end
            mglsetorigin(obj.Ball,obj.BallPos);
            
            continue_ = ~obj.Success && obj.BallPos(2) < obj.ScrSize(2);  % stop when a brick is hit or the paddle fails to bounce the ball
            obj.LastUpdateTime = elapsed;
        end
    end
    
    methods (Access = protected)
        function pos = new_brick_position(obj,sz)
            pos = rand(obj,1,2).*(obj.ScrSize-sz-2*obj.WallThickness).*[1 0.5] + obj.WallThickness + 0.5*sz;
        end
        function [tf,rc] = collision_test(~,me,target)  % me & target are MGL object IDs
            me_pos = mglgetproperty(me,'rect');
            target_pos = zeros(length(target),4);
            for m=1:length(target), target_pos(m,:) = mglgetproperty(target(m),'rect'); end
            rc = IntersectRect(me_pos,target_pos);
            tf = 0 < rc(:,1);
        end
        function val = rand(obj,m,n)
            if ~exist('m','var'), m = 1; end
            if ~exist('n','var'), n = m; end
            if isempty(obj.RandomNumberPool), val = rand(m,n); return, end
            nr = m * n;
            if numel(obj.RandomNumberPool) <= obj.RandomNumberIndex + nr, obj.RandomNumberIndex = 0; end
            val = reshape(obj.RandomNumberPool((1:n) + obj.RandomNumberIndex),m,n);
            obj.RandomNumberIndex = obj.RandomNumberIndex + nr;
        end
    end
end
