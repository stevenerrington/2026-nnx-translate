if ~exist('mouse_','var'), error('This demo requires the mouse input. Please enable it in the main menu.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
bhv_code(10,'Scene 1',20,'Scene 2',90,'Reward',95,' Large Reward');

dashboard(3,'This task allows you to change the grating with mouse and keyboard while tracking eye.',[0 1 0]);
dashboard(4,'Press ''x'' to quit.',[1 0 0]);

mouse_.showcursor(false);  % hide the mouse cursor from the subject

% parameters for grating
if isfield(TrialRecord.User,'position'), position = TrialRecord.User.position; else position = [0 0]; end
if isfield(TrialRecord.User,'radius'), radius = TrialRecord.User.radius; else radius = 1; end
if isfield(TrialRecord.User,'direction'), direction = TrialRecord.User.direction; else direction = 0; end
if isfield(TrialRecord.User,'sfreq'), sfreq = TrialRecord.User.sfreq; else sfreq = 1; end
if isfield(TrialRecord.User,'tfreq'), tfreq = TrialRecord.User.tfreq; else tfreq = 1; end

% editables
SpatialFrequencyStep = 0.1;
TemporalFrequencyStep = 0.1;
editable('SpatialFrequencyStep','TemporalFrequencyStep');

% scene1
fix1 = SingleTarget(eye_);
fix1.Target = 1;
fix1.Threshold = 3;
wth1 = WaitThenHold(fix1);
wth1.WaitTime = 5000;
wth1.HoldTime = 0;
scene1 = create_scene(wth1,1);

% scene2
rwd2a = RewardScheduler(fix1);  
rwd2a.Schedule = [0 1000 1000 100 90;  % during fixation, give a 100-ms reward every seconds
    5000 1000 1000 150 95];            % if fix is maintained longer than 5000 ms, increase the reward to 150 ms
lh2a = LooseHold(rwd2a);  % lh2a stops when fixation is maintained for 10 s or broken longer than 300 ms.
lh2a.HoldTime = 10000;
lh2a.BreakTime = 300;

grat2b = Grating_RF_Mapper(mouse_);
grat2b.Position = position;
grat2b.Radius = radius;
grat2b.Direction = direction;
grat2b.SpatialFrequency = sfreq;
grat2b.TemporalFrequency = tfreq;
grat2b.SpatialFrequencyStep = SpatialFrequencyStep;
grat2b.TemporalFrequencyStep = TemporalFrequencyStep;
grat2b.InfoDisplay = true;

con2 = Concurrent(lh2a);   % The Concurrent adapter continues, if lh2a continues, and run grat2b additionally.
con2.add(grat2b);          % grat2b does not stop the scene.

scene2 = create_scene(con2,1);

% run the task
error_type = 0;
run_scene(scene1,10);

if wth1.Success
    run_scene(scene2,20);
    if ~lh2a.Success
        error_type = 3;  % fix break
    end
else
    error_type = 4;  % no fixation
end
idle(50);

trialerror(error_type);
set_iti(500);

% record keeping
trialerror(error_type);
TrialRecord.User.position = grat2b.Position;
TrialRecord.User.radius = grat2b.Radius;
TrialRecord.User.direction = grat2b.Direction;
TrialRecord.User.sfreq = grat2b.SpatialFrequency;
TrialRecord.User.tfreq = grat2b.TemporalFrequency;
