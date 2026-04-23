if ~exist('eye_','var'), error('This demo requires eye input. Please enable it in the main menu or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

% event codes
FIX_CUE_ON = 10;
FIX_ACQUIRED = 20;
FIX_BREAK = 25;
PURSUIT_START = 30;
REWARD = 90;
bhv_code(FIX_CUE_ON,'Fix cue on',FIX_ACQUIRED,'Fix acquired',FIX_BREAK,'Fix break',PURSUIT_START,'Pursuit start',REWARD,'Reward');

% editables
fix_window_size = 3;
fix_wait_time = 5000;
fix_hold_time = 1000;
pursuit_speed = 3;
pursuit_duration = 2000;
editable('fix_window_size','fix_wait_time','fix_hold_time','pursuit_speed','pursuit_duration');

% random parameter
pursuit_direction = round(rand * 360);

% create scenes
fix1 = SingleTarget(eye_);
fix1.Target = 1;
fix1.Threshold = fix_window_size;
mrk1 = OnOffMarker(fix1);
mrk1.OnMarker = FIX_ACQUIRED;
mrk1.OffMarker = FIX_BREAK;
wth1 = WaitThenHold(mrk1);
wth1.WaitTime = fix_wait_time;
wth1.HoldTime = fix_hold_time;
scene1 = create_scene(wth1,1);

pur2 = SmoothPursuit(eye_);
pur2.Target = 1;
pur2.Threshold = fix_window_size;
pur2.Origin = [0 0];
pur2.Direction = pursuit_direction;
pur2.Speed = pursuit_speed;
pur2.Duration = pursuit_duration;
scene2 = create_scene(pur2);

% task
dashboard(1,'Pursuit Eye Movement Demo',[0 1 0]);
dashboard(2,sprintf('Direction: %.0f deg',pursuit_direction));
dashboard(3,'Press ''x'' to quit.',[1 0 0]);

error_type = 0;

run_scene(scene1,FIX_CUE_ON);
rt = wth1.RT;
if ~wth1.Success
    if wth1.Waiting
        error_type = 4;
    else
        error_type = 3;
    end
end

if 0==error_type
    run_scene(scene2,PURSUIT_START);
    if ~pur2.Success
        eventmarker(FIX_BREAK);
        error_type = 3;
    end
end

if 0==error_type
    goodmonkey(100,'eventmarker',REWARD);
end

trialerror(error_type);
