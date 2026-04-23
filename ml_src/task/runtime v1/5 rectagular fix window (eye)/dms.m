if ~ML_eyepresent, error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
bhv_code(10,'Fix Cue',20,'Sample',30,'Delay',40,'Go',50,'Reward');  % behavioral codes

% give names to the TaskObjects defined in the conditions file:
fixation_point = 1;
sample = 2;
target = 3;
distractor = 4;

% define time intervals (in ms):
wait_for_fix = 5000;
initial_fix = 500;
sample_time = 1000;
delay = 1000;
max_reaction_time = 2000;
hold_target_time = 500;

% fixation window (in degrees):
fix_rect = [4 4];  % [width height] of the fixation rectangle
hold_rect = [5 5];

% TASK:
error_type = 0;

% initial fixation:
toggleobject(fixation_point, 'eventmarker',10);
ontarget = eyejoytrack('acquirefix', fixation_point, fix_rect, wait_for_fix);
if ~ontarget
    error_type = 4;  % no fixation
end
if 0==error_type
    ontarget = eyejoytrack('holdfix', fixation_point, hold_rect, initial_fix);
    if ~ontarget
        error_type = 3;  % broke fixation
    end
end

% sample epoch
if 0==error_type
    toggleobject(sample, 'eventmarker',20);  % turn on sample
    ontarget = eyejoytrack('holdfix', fixation_point, hold_rect, sample_time);
    if ~ontarget
        error_type = 3;  % broke fixation
    end
end

% delay epoch
if 0==error_type
    toggleobject(sample, 'eventmarker',30);  % turn off sample
    ontarget = eyejoytrack('holdfix', fixation_point, hold_rect, delay);
    if ~ontarget
        error_type = 3;  % broke fixation
    end
end

% choice presentation and response
if 0==error_type
    t_target = toggleobject([fixation_point target distractor], 'eventmarker',40);  % simultaneously turns of fix point and displays target & distractor
    [chosen_target,~,t_acquired] = eyejoytrack('acquirefix', [target distractor], [fix_rect; fix_rect], max_reaction_time);
    if chosen_target
        rt = t_acquired - t_target;
    else
        error_type = 2;  % late response (did not land on either the target or distractor)
    end
end

% hold the chosen target
if 0==error_type
    if 1==chosen_target
        toggleobject(distractor);
        ontarget = eyejoytrack('holdfix', target, hold_rect, hold_target_time);
    else
        toggleobject(target);
        ontarget = eyejoytrack('holdfix', distractor, hold_rect, hold_target_time);
        error_type = 6;  % chose the wrong (second) object among the options [target distractor]
    end
    if ~ontarget
        error_type = 3;  % broke fixation
    end
end

toggleobject([fixation_point sample target distractor],'status','off');  % clear screens

% reward
if 0==error_type
    goodmonkey(100, 'juiceline',1, 'numreward',2, 'pausetime',500, 'eventmarker',50); % 100 ms of juice x 2
else
    idle(700);
end

trialerror(error_type);  % add the result to the trial history
