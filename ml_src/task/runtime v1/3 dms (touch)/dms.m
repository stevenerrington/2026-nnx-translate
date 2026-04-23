if ~ML_touchpresent, error('This demo requires touch input. Please set it up or turn on the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
bhv_code(20,'Sample',40,'Go',50,'Reward');  % behavioral codes

% give names to the TaskObjects defined in the conditions file:
sample = 2;
target = 3;
distractor = 4;

% define time intervals (in ms):
sample_time = 5000;
delay = 1000;
max_reaction_time = 5000;

% fixation window (in degrees):
hold_radius = 2.5;

% TASK:
error_type = 0;

% proceed only when the screen is not being touched
while istouching(), end

% sample epoch
toggleobject(sample, 'eventmarker',20);  % turn on sample
ontarget = eyejoytrack('touchtarget',sample,hold_radius, '~touchtarget',sample,hold_radius, sample_time);  % touching outside the window will abort the trial
if ~ontarget(1)
    error_type = 3;
end

% delay epoch
if 0==error_type
    toggleobject(sample, 'eventmarker',30);
    idle(delay);
end

% choice presentation and response
if 0==error_type
    t_target = toggleobject([target distractor], 'eventmarker',40);  % display target & distractor
    [chosen_target,~,t_acquired] = eyejoytrack('touchtarget', [target distractor], hold_radius, max_reaction_time);
    switch chosen_target
        case 0, error_type = 2;              % neither is chosen
        case 1, rt = t_acquired - t_target;  % correct response
        case 2, error_type = 6;              % incorrect choice
    end
end

toggleobject([sample target distractor],'status','off');  % clear screens

% reward
if 0==error_type
    goodmonkey(100, 'juiceline',1, 'numreward',2, 'pausetime',500, 'eventmarker',50); % 100 ms of juice x 2
else
    idle(700);
end

trialerror(error_type);  % add the result to the trial history
