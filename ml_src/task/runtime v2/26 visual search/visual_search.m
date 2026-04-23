showcursor('off');  % turn off joystick cursors for simulation mode
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

% task parameters
editable('fix_window','fix_wait','fix_hold','cue_period','delay_period','search_period', ...
    'target_window','target_hold','reward','iti','max_trial');
fix_window = 3;
fix_wait = 5000;
fix_hold = 500;
cue_period = 1000;
delay_period = 800;
search_period = 8000;
target_window = 2;
target_hold = 800;
reward = 150;  % solenoid open duration
iti = 2000;
max_trial = 16;

% event codes
FIX_POINT = 10;
CUE_ON = 20;
DELAY_START = 30;
SEARCH_START = 40;
REWARD = 90;
bhv_code(10,'FP',20,'Cue',30,'Delay',40,'Search',90,'Reward');

% create scenes

fix1 = SingleTarget(eye_);  % fixation period
fix1.Target = 1;
fix1.Threshold = fix_window;
wth1 = WaitThenHold(fix1);
wth1.WaitTime = fix_wait;
wth1.HoldTime = fix_hold;
scene1 = create_scene(wth1,1);

fix2 = SingleTarget(eye_);  % cue period
fix2.Target = 2;
fix2.Threshold = fix_window;
wth2 = WaitThenHold(fix2);
wth2.WaitTime = 0;
wth2.HoldTime = cue_period;
scene2 = create_scene(wth2,2);

fix3 = SingleTarget(eye_);  % delay period
fix3.Target = 1;
fix3.Threshold = fix_window;
wth3 = WaitThenHold(fix3);
wth3.WaitTime = 0;
wth3.HoldTime = delay_period;
scene3 = create_scene(wth3,1);

fix4 = SingleTarget(eye_);  % search period
fix4.Target = 3;            % target Taskobject#
fix4.Threshold = target_window;
fth4 = FreeThenHold(fix4);
fth4.MaxTime = search_period;
fth4.HoldTime = target_hold;
mul4 = MyMultiTarget(eye_);
mul4.Target = TrialRecord.User.location(2:end,:); % distractor locations
mul4.HoldTime = target_hold;
mul4.Threshold = target_window;
all4 = AllContinue(fth4);  % fix4 and fth4 are for the target
all4.add(mul4);            % mul4 is for distractors
scene4 = create_scene(all4,3:length(TaskObject));

% run task
error_type = 0;
dashboard(1,sprintf('Target: %d (%s)',TrialRecord.User.image_no(1),TrialRecord.User.images{1}));
dashboard(2,'');

idle(500);

run_scene(scene1,FIX_POINT);
if ~wth1.Success, error_type = fi(wth1.Waiting,4,3); end  % no fix or fix break

if 0==error_type
    run_scene(scene2,CUE_ON);
    if ~wth2.Success, error_type = 3; end  % fix break
end

if 0==error_type
    run_scene(scene3,DELAY_START);
    if ~wth3.Success, error_type = 3; end  % fix break
end

distractor_choice_history = [];
if 0==error_type
    run_scene(scene4,SEARCH_START);
    if fth4.Success                        % target is chosen
        rt = fth4.RT;
        if mul4.Success
            distractor_chosen = TrialRecord.User.image_no(mul4.Order+1);
            distractor_choice_history = [distractor_chosen' mul4.Time];
            chosen_image = sprintf(' %d',[distractor_chosen TrialRecord.User.image_no(1)]);
        else
            chosen_image = sprintf(' %d',TrialRecord.User.image_no(1));
        end
        dashboard(2,['Chosen:' chosen_image],[0 1 0]);
    else                                   % target is not chosen
        if mul4.Success
            error_type = 6;                % incorrect
            distractor_chosen = TrialRecord.User.image_no(mul4.Order+1);
            distractor_choice_history = [distractor_chosen' mul4.Time];
            dashboard(2,['Chosen:' sprintf(' %d',distractor_chosen)],[1 0 0]);
        else
            error_type = 1;                % no response
            dashboard(2,'Nothing chosen',[1 0 0]);
        end
    end
end

if 0==error_type
    goodmonkey(reward,'numreward',1,'eventmarker',REWARD);
end

idle(500);

% record results
trialerror(error_type);
bhv_variable('cond',TrialRecord.User.cond);
bhv_variable('image_no',TrialRecord.User.image_no);
bhv_variable('images',TrialRecord.User.images);
bhv_variable('location_no',TrialRecord.User.location_no);
bhv_variable('location',TrialRecord.User.location);
bhv_variable('reward',reward);
bhv_variable('distractor_choice_history',distractor_choice_history);

% stop when completed
if max_trial==sum(0==[TrialRecord.TrialErrors error_type]), TrialRecord.Pause = true; end
