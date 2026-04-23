hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

dashboard(1,'This task requires both eye fixation and button #1 to be held for 0.5 s within 2 s.',[0 1 0]);
dashboard(2,'Press ''x'' to quit.',[1 0 0]);

fixation_point = 1;  % TaskObject #1

% create scenes
fix = SingleTarget(eye_);
fix.Target = fixation_point;
fix.Threshold = 3;
btn = SingleButton(button_);
btn.Button = 1;
and = AndAdapter(fix);
and.add(btn);
wth = WaitThenHold(and);
wth.WaitTime = 2000;
wth.HoldTime = 500;
scene = create_scene(wth);

% run the task
dashboard(3,'');
run_scene(scene,fixation_point);
set_iti(2000);

% display result
if wth.Success
    dashboard(3,'Success!!!');
else
    if fix.Success && ~btn.Success
        dashboard(3,'Button is not pressed!');
    elseif ~fix.Success && btn.Success
        dashboard(3,'Eye fixation is not acquired!');
    else
        dashboard(3,'No eye fixation & no button press!');
    end
end
rt = wth.RT;
