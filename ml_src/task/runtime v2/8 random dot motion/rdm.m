if ~exist('eye_','var'), error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

% rdm variables
num_dot = 100;
dot_size = 0.15;
dot_color = [1 1 1];
dot_shape = {'Square','Circle','Square'};
editable('num_dot','dot_size','-color','dot_color','-category','dot_shape');

% give names to the TaskObjects defined in the conditions file:
fixation_point = 1;

coherence = ceil(rand(1)*100);
direction = rand(1)*360;
speed = 1 + rand(1)*19;

% scene 1: fixation
fix1 = SingleTarget(eye_);
fix1.Target = fixation_point;
fix1.Threshold = 3;
wth1 = WaitThenHold(fix1);
wth1.WaitTime = 5000;
wth1.HoldTime = 0;
scene1 = create_scene(wth1,fixation_point);

% scene 2: sample
fix2 = SingleTarget(eye_);
fix2.Target = fixation_point;
wth2 = WaitThenHold(fix2);
wth2.WaitTime = 0;
wth2.HoldTime = 5000;
if strcmp(TrialRecord.User.ApertureShape,'Circle')
    rdm2 = RandomDotMotion(wth2);
    rdm2.Radius = 5;
    fix2.Threshold = 6;
else
    rdm2 = RectangularRDM(wth2);
    rdm2.Size = [9 9];
    fix2.Threshold = [10 10];
end
rdm2.NumDot = num_dot;
rdm2.DotSize = dot_size;
rdm2.DotColor = dot_color;
rdm2.DotShape = dot_shape{end};
rdm2.Position = [0 0];
rdm2.Coherence = coherence;
rdm2.Direction = direction;
rdm2.Speed = speed;
scene2 = create_scene(rdm2,fixation_point);

% task
dashboard(1,sprintf('Coherence = %d',coherence));
dashboard(2,sprintf('Direction = %.1f deg',direction));
dashboard(3,sprintf('Speed = %.1f deg/sec',speed));
dashboard(4,sprintf('Dot shape = %s',dot_shape{end}));

error_type = 0;
run_scene(scene1);
if ~wth1.Success
    if wth1.Waiting
        error_type = 4;  % no fixation
    else
        error_type = 3;  % broke fixation
    end
end

if 0==error_type
    run_scene(scene2);
    if ~wth2.Success
        error_type = 3;  % broke fixation
    end
end

rt = wth1.RT;
trialerror(error_type);

dashboard(1,'');
dashboard(2,'');
dashboard(3,'');
dashboard(4,'');
idle(50);  % clear screen

set_iti(500);
