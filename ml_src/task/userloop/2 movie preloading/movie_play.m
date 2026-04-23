hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

dashboard(1,TrialRecord.User.PreloadStatus);

toggleobject(1:4);
idle(1000);

% The code for the runtime v2 that run the same scene is like the following.
% tc1 = TimeCounter(null_);
% tc1.Duration = 1000;
% scene1 = create_scene(tc1,1:4);
% run_scene(scene1);

set_iti(0);
