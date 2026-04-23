hotkey('x', 'TrialRecord.Quit = true; assignin(''caller'',''continue_'',false);');
set_bgcolor([1 1 1]);
set_iti(0);

% norm2deg converts normalized coordinates to visual degrees.
% In normalized coordinates, the left-top corner of the screen is [0 0] and
% the right-bottom corner is [1 1]. In the visual degree system, the center
% of the screen is [0 0] and the right-top corner is the positive end to
% both X and Y.
pos = EyeCal.norm2deg([0.15 0.2; 0.39 0.2; 0.63 0.2;
    0.15 0.5; 0.39 0.5; 0.63 0.5;
    0.15 0.8; 0.39 0.8; 0.63 0.8]);

% norm2size converts normalized sizes to visual degrees.
answerpad_pos = EyeCal.norm2deg([0.9 0.2; 0.9 0.5; 0.9 0.8]);
answerpad_size = EyeCal.norm2size([0.2 0.2]);
background_pos = EyeCal.norm2deg([0.89 0.5]);
background_size = EyeCal.norm2size([0.22 1]);

% randomize
imagelist = {'A.bmp','B.bmp','C.bmp','D.bmp'};
filename = cell(9,1);
correct_answer = ceil(3*rand(1,3)) + [0 3 6];
for m=1:3
    l = imagelist(randperm(4,2));
    filename((1:3)+3*(m-1)) = l(1);
    filename(correct_answer(m)) = l(2);
end

% create scenes
images = cell(9,3);
for m=1:9
    images{m,1} = filename{m};
    images{m,2} = pos(m,:);
    images{m,3} = [1 1 1];
end
img1 = ImageGraphic(null_);
img1.List = images;

bg1 = BoxGraphic(null_);
bg1.List = { [1 1 1],[1 1 1],answerpad_size,answerpad_pos(1,:); ...
    [1 1 1],[1 1 1],answerpad_size,answerpad_pos(2,:); ...
    [1 1 1],[1 1 1],answerpad_size,answerpad_pos(3,:); ...
    [0 0 0],[0 0 0],background_size,background_pos };

mul1 = MultiTarget(touch_);
mul1.Target = img1.Position;
mul1.Threshold = img1.Size;
mul1.WaitTime = Inf;
mul1.HoldTime = 0;
mul1.TurnOffUnchosen = false;
cont1 = AllContinue(img1);
cont1.add(bg1);
cont1.add(mul1);

dd2 = DragAndDrop(touch_);
dd2.Gravity = 5;
dd2.GravityWindow = answerpad_size;
cont2 = AllContinue(dd2);
cont2.add(bg1);

tc3 = TimeCounter(touch_);
tc3.Duration = 1000;
con3 = Concurrent(tc3);
con3.add(img1);
con3.add(bg1);

% run scenes
chosen = zeros(1,3);
while istouching(), end

while true
    scene1 = create_scene(cont1);
    run_scene(scene1);

    if mul1.Success
        rt = mul1.RT;
        
        switch mul1.ChosenTarget
            case {1,2,3}, chosen_row = 1;
            case {4,5,6}, chosen_row = 2;
            case {7,8,9}, chosen_row = 3;
        end
        if 0~=chosen(chosen_row), continue, end  % already answered
        
        dd2.Destination = answerpad_pos(chosen_row,:);
        dd2.setTarget(img1,mul1.ChosenTarget);
        scene2 = create_scene(cont2);
        run_scene(scene2);
        
        if dd2.Success
            chosen(chosen_row) = mul1.ChosenTarget;
            if all(0~=chosen)                       % wait until all three rows are answered
                if all(chosen==correct_answer)      % if all rows are correct
                    scene3 = create_scene(con3,1);
                    run_scene(scene3);
                    break
                else                                % if some answers are wrong
                    scene3 = create_scene(con3,2);
                    run_scene(scene3);
                    wrong_answer = chosen(chosen~=correct_answer);
                    img1.Position(wrong_answer,:) = pos(wrong_answer,:);  % put back incorrect answers
                    chosen(chosen~=correct_answer) = 0;
                end
            end
        end
    else
        break
    end
end
idle(50);

trialerror(all(chosen~=correct_answer));
