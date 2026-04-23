% This task delivers reward, if the joystick cursor is moved away from the center.

if SIMULATION_MODE, tracker = eye_; else, tracker = joy_; end  % use mouse for simulation
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');  % exit early when 'x' is pressed
dashboard(1,'This task delivers reward, if the joystick cursor is moved away from the center.');

bhv_code(90,'Reward');  % label the code 90
showcursor(true);       % show the joystick cursor to the subject

reward_interval = 500;
joy_threshold = 1;
trial_length = 10000;
editable('reward_interval','joy_threshold','trial_length');  % register variables to the edit menu

fix = SingleTarget(tracker);        % check the distance from the center
fix.Target = [0 0];
fix.Threshold = joy_threshold;
not = NotAdapter(fix);           % test if the cursor moved out of the window (NOT moved in)
rwd = RewardScheduler(not);      % deliver multiple rewards while fixation is maintained
rwd.Schedule = [0 reward_interval reward_interval reward_dur 90];
tc = TimeCounter(rwd);           % stop the trial after 10 s
tc.Duration = trial_length;

run_scene(create_scene(tc));

set_iti(0);                      % set ITI to 0
