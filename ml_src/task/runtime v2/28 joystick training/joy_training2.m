% This task delivers reward, if the joystick cursor touches the walls.

if SIMULATION_MODE, tracker = eye_; else, tracker = joy_; end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
dashboard(1,'This task delivers reward, if the joystick cursor touches the walls.');

bhv_code(90,'Reward');
showcursor(true);

if ~isfield(TrialRecord.User,'count'), TrialRecord.User.count = zeros(1,4); end

reward_num = 1;
reward_interval = 500;
force_to_release_first = true;
joy_threshold = 3;
error_color = [1 0.5 0];
show_touched_bar = true;
bar_enabled = true(1,4);  % [left right up down]
bar_distance = [5 5];     % [horizontal vertical]
bar_thickness = 2;
bar_color = [1 1 1];
trial_length = 10000;
ITI = 2000;
editable('reward_num','reward_interval','force_to_release_first','joy_threshold','error_color', ...
    'show_touched_bar','bar_enabled','bar_distance','bar_thickness','-color','bar_color','trial_length','ITI');

bar_size = [bar_thickness bar_distance(2)*2; bar_thickness bar_distance(2)*2;
    bar_distance(1)*2 bar_thickness; bar_distance(1)*2 bar_thickness];
bar_position = [-bar_distance(1) 0; bar_distance(1) 0; 0 bar_distance(2); 0 -bar_distance(2)];

if force_to_release_first  % joystick cursor has to be back to the center
    fix0 = SingleTarget(tracker);
    fix0.Target = [0 0];
    fix0.Threshold = joy_threshold;
    tc0 = TimeCounter(fix0);
    tc0.Duration = 0;
    run_scene(create_scene(tc0));
    
    if ~fix0.Success
        set_bgcolor(error_color);  % change the background color
        run_scene(create_scene(fix0));
        set_bgcolor();             % restore the original color
    end
end

% AllContinue -+- TimeCounter   --- NullTracker
%              +- SingleTarget1 --- BoxGraphic1 --- JoyTracker
%              +- SingleTarget2 --- BoxGraphic2 --- JoyTracker
%              +- SingleTarget3 --- BoxGraphic3 --- JoyTracker
%              +- SingleTarget4 --- BoxGraphic4 --- JoyTracker
tc = TimeCounter(null_);
tc.Duration = trial_length;
con = AllContinue(tc);
for m=1:4
    box(m) = BoxGraphic(tracker);
    box(m).List = { bar_color, bar_color, bar_size(m,:), bar_position(m,:) };
    fix(m) = SingleTarget(box(m));
    fix(m).Target = bar_position(m,:);
    fix(m).Threshold = bar_size(m,:);
    if bar_enabled(m), con.add(fix(m)); end
end
run_scene(create_scene(con));

error_type = 0;
touched_bar = 0;
if tc.Success
    error_type = 1;  % time out
else
    for m=find(bar_enabled)
        if fix(m).Success
            TrialRecord.User.count(m) = TrialRecord.User.count(m) + 1;
            touched_bar = m;
            break
        end
    end
end
dashboard(1,sprintf('Left: %3d, Right: %3d, Up: %3d, Down: %3d',TrialRecord.User.count));

if show_touched_bar  % show the touched bar
    tc2 = TimeCounter(null_);
    tc2.Duration = 50;
    con2 = AllContinue(tc2);
    if 0 < touched_bar, con2.add(box(touched_bar)); end
    run_scene(create_scene(con2));
end

if 0==error_type  % give reward
    goodmonkey(reward_dur,'eventmarker',90);
end

trialerror(error_type);
bhv_variable('touch_count',TrialRecord.User.count);
set_iti(ITI);
