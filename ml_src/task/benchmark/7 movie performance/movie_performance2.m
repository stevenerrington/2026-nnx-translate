% give names to the TaskObjects defined in the conditions file:
fixation_point = 1;
target = 2;
distractor = 3;

% define time intervals (in ms):
wait_for_fix = 5000;
initial_fix = 500;
sample_time = 2000;
delay = 1000;
max_reaction_time = 2000;
hold_target_time = 500;

% fixation window (in degrees):
fix_radius = 2;
hold_radius = 2.5;

% create scenes
fix1 = SingleTarget(eye_);
fix1.Target = fixation_point;
fix1.Threshold = fix_radius;
wth1 = WaitThenHold(fix1);
wth1.WaitTime = wait_for_fix;
wth1.HoldTime = initial_fix;
scene1 = create_scene(wth1,fixation_point);

fix2 = SingleTarget(eye_);
fix2.Target = fixation_point;
fix2.Threshold = hold_radius;
wth2 = WaitThenHold(fix2);
wth2.WaitTime = 0;
wth2.HoldTime = sample_time;
rdm2 = RandomDotMotion(wth2);
rdm2.DotSize = 0.069;
rdm2.Radius = 2.5;
rdm2.Direction = Info.deg;
rdm2.Coherence = Info.coh;
pd2 = PhotoDiode(rdm2);
scene2 = create_scene(pd2,fixation_point);

fix3 = SingleTarget(eye_);
fix3.Target = fixation_point;
fix3.Threshold = hold_radius;
wth3 = WaitThenHold(fix3);
wth3.WaitTime = 0;
wth3.HoldTime = delay;
scene3 = create_scene(wth3,fixation_point);

mul4 = MultiTarget(eye_);
mul4.Target = [target distractor];
mul4.Threshold = fix_radius;
mul4.WaitTime = max_reaction_time;
mul4.HoldTime = hold_target_time;
scene4 = create_scene(mul4,[target distractor]);

% run scenes
error_type = 0;

run_scene(scene1,10);
if ~wth1.Success
    error_type = fi(wth1.Waiting,4,3);
end

if 0==error_type
    run_scene(scene2,20);
    if ~wth2.Success
        error_type = 3;
    end
end

if 0==error_type
    run_scene(scene3,30);
    if ~wth3.Success
        error_type = 3;
    end
end

if 0==error_type
    run_scene(scene4,40);
    if ~mul4.Success
        error_type = fi(mul4.Waiting,2,3);
    elseif 2~=mul4.ChosenTarget
        error_type = 6;
    end
end

% reward
if 0==error_type
    idle(0);
    goodmonkey(100, 'juiceline',1, 'numreward',2, 'pausetime',500); % 100 ms of juice x 2
else
    idle(700);
end

trialerror(error_type);
