% hot key for early exit
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

% dimensions of the screen
screen_size = Screen.SubjectScreenFullSize / Screen.PixelsPerDegree;  % in degrees
plate_size = screen_size .* [0.8 1];
plate_pos = screen_size .* [-0.1 0];
answer_pad_size = screen_size .* [0.18 0.5];
answer_pad_pos = [(screen_size(1)-answer_pad_size(1))*0.5 0];
horizontal_bar_size = screen_size .* [0.8 0.01];
horizontal_bar_pos = screen_size .* [-0.1 0];
stim_size = screen_size([2 2]) * 0.15;
target_pos = repmat(screen_size,4,1) .* [-0.5+(0.5:1:3.5)'*0.2 -0.25*ones(4,1)]; 
cue_pos = screen_size .* [-0.1 0.25];

% trial condition
cue_type = ceil(rand*4);

% create stimuli
% In MGL, a stimulus created earlier is presented above the ones created later.

% choice options
target{1} = CircleGraphic(null_);
target{1}.List = { [0.25 0 0.5], [0.25 0 0.5], stim_size, target_pos(1,:) };
target{2} = BoxGraphic(null_);
target{2}.List = { [0.5 1 0], [0.5 1 0], stim_size, target_pos(2,:) };
target{3} = PolygonGraphic(null_);
target{3}.List = { [0 0 0], [0 0 0], stim_size, target_pos(3,:), [1 0.7071; 0.7071 1; 0.2929 1; 0 0.7071; 0 0.2929; 0.2929 0; 0.7071 0; 1 0.2929] };
target{4} = PolygonGraphic(null_);
target{4}.List = { [0 0.5 1], [0 0.5 1], stim_size, target_pos(4,:), [0.5 1; 0.375 0.625; 0 0.625; 0.25 0.375; 0.125 0; 0.5 0.25; 0.875 0; 0.75 0.375; 1 0.625; 0.625 0.625] };

% cue
switch cue_type
    case 1
        stim = CircleGraphic(null_);
        stim.List = { [0.25 0 0.5], [0.25 0 0.5], stim_size, cue_pos };
    case 2
        stim = BoxGraphic(null_);
        stim.List = { [0 1 0], [0 1 0], stim_size, cue_pos };
    case 3
        stim = PolygonGraphic(null_);
        stim.List = { [0 0 0], [0 0 0], stim_size, cue_pos, [1 0.7071; 0.7071 1; 0.2929 1; 0 0.7071; 0 0.2929; 0.2929 0; 0.7071 0; 1 0.2929] };
    case 4
        stim = PolygonGraphic(null_);
        stim.List = { [0 0.5 1], [0 0.5 1], stim_size, cue_pos, [0.5 1; 0.375 0.625; 0 0.625; 0.25 0.375; 0.125 0; 0.5 0.25; 0.875 0; 0.75 0.375; 1 0.625; 0.625 0.625] };
end

% background
bg = BoxGraphic(null_);
bg.List = { [0 0 0], [0 0 0], horizontal_bar_size, horizontal_bar_pos;
    [1 1 1], [1 1 1], plate_size, plate_pos;
    [1 1 1], [1 1 1], answer_pad_size, answer_pad_pos };

% create scenes
mul1 = MultiTarget(touch_);
mul1.Target = target_pos;
mul1.Threshold = stim_size(1) * 0.75;
mul1.WaitTime = 10000;
mul1.HoldTime = 50;
con1 = Concurrent(mul1);
con1.add(target); con1.add(stim); con1.add(bg);
scene1 = create_scene(con1);

dd2 = DragAndDrop(touch_);
dd2.Destination = answer_pad_pos;
dd2.Gravity = 5;
dd2.GravityWindow = answer_pad_size;
con2 = Concurrent(dd2);

snd3 = AudioSound(null_);
tc3 = TimeCounter(snd3);
tc3.Duration = 1000;

% run task
dashboard(1,'Find Match',[1 0 0]);
dashboard(2,'Move the match to the answer pad on the right',[0 1 0]);

for m=1:2  % you get two chances to pick up a target before dropping on the answer pad
    run_scene(scene1);

    if mul1.Success                                           % a target is picked
        dd2.setTarget(target{mul1.ChosenTarget});             % register the picked target to the drag-n-drop adapter

        con2.erase(2:con2.length());                          % Don't erase the first adapter (dd2). It will break the chain.
        con2.add(target); con2.erase(mul1.ChosenTarget + 1);  % The picked target is controlled by the drag-n-drop adapter, so don't add it to the background
        con2.add(stim);
        con2.add(bg);

        scene2 = create_scene(con2);
        run_scene(scene2);                                    % This scene ends when the picked target is dropped
        
        if dd2.Success, break, end                            % dd2.Success is true only when the target is dropped on the answer pad
    end
end

error_type = 0;
if mul1.Waiting
    error_type = 8;  % No target was chosen (Ignored)
elseif ~mul1.Success
    error_type = 7;  % The target was not held long enough (Lever break)
elseif ~dd2.Success
    error_type = 1;  % The target was not dropped on the answer pad (No response)
elseif mul1.ChosenTarget~=cue_type
    error_type = 6;  % The dropped target was a wrong one (Incorrect)
end
if 0==error_type
    snd3.Source = 'correct.wav';
else
    snd3.Source = 'wrong.wav';
end
scene3 = create_scene(tc3);
run_scene(scene3);

trialerror(error_type);
