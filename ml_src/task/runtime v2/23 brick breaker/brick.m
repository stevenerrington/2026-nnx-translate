hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');  % early exit
if SIMULATION_MODE, tracker = eye_; else, tracker = joy_; end  % use mouse for simulation

dashboard(1,'Brick Breaker',[1 0 0]);
dashboard(2,'Break 5 bricks to complete a trial',[0 1 0]);

bb = BrickBreaker(tracker);
% BrickBreaker uses random numbers to determine brick positions, bounce
% angles, etc. Generating random numbers on the fly makes the data file
% difficult to replay, because initial parameters are undetermined when the
% scene is created. To resolve this, you can provide a pre-determined
% random number pool. If the pool is not provided, random numbers are
% generated on the fly.
bb.RandomNumberPool = rand(1,1000);

running = true;
brick1_count = 0;
brick2_count = 0;

dashboard(3,sprintf('Large reward: %d',brick1_count));
dashboard(4,sprintf('Small reward: %d',brick2_count));

while running
    scene = create_scene(bb);
    run_scene(scene);
    
    if bb.Success
        if 1==bb.CollidedBrick
            brick1_count = brick1_count + 1;
            goodmonkey(200,'nonblocking',2);
        else
            brick2_count = brick2_count + 1;
            goodmonkey(100,'nonblocking',2);
        end
    end
    
    dashboard(3,sprintf('Large reward: %d',brick1_count));
    dashboard(4,sprintf('Small reward: %d',brick2_count));
    
    running = fi(bb.Success && brick1_count+brick2_count<5,true,false);  % end the task after 5 hits
end

trialerror(fi(5==brick1_count+brick2_count,0,9));
idle(500);
