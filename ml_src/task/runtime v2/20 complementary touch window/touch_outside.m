if ~exist('touch_','var'), error('This demo requires the touch input. Please enable it in the main menu.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

% scene 1
fix1 = SingleTarget(touch_);
fix1.Target = 1;  % TaskObject#1
fix1.Threshold = 3;
wth1 = WaitThenHold(fix1);
wth1.WaitTime = 5000;
wth1.HoldTime = 500;

out1 = ComplementaryWindow(touch_);  % abort if the outside of the window is touched
out1.setTarget(fix1);

ac1 = AllContinue(wth1);
ac1.add(out1);

scene1 = create_scene(ac1,1);  % TaskObject#1

% scene 2
mul2 = MultiTarget(touch_);
mul2.Target = [2 3];  % TaskObject#2 & TaskObject#3. Also [x1 y1; x2 y2; ...] is okay.
mul2.Threshold = 3;
mul2.WaitTime = 5000;
mul2.HoldTime = 500;

out2 = ComplementaryWindow(touch_);  % abort if the outside of the window is touched
out2.setTarget(mul2);

ac2 = AllContinue(mul2);
ac2.add(out2);

scene2 = create_scene(ac2,[2 3]);  % TaskObject#2 & TaskObject#3

% task
dashboard(1,'Complementary Window for Touch',[0 1 0]);
dashboard(2,'This task tests whether the outsides of threshold windows are touched as well.');
dashboard(3,'');

error_type=0;

run_scene(scene1);
if out1.Success
    error_type = 7;  % touch outside of the window
else
    if ~wth1.Success
        if wth1.Waiting
            error_type = 3;  % no touch
        else
            error_type = 4;  % touch not held
        end
    end
end

if 0==error_type
    idle(2000);  % not to make the trial aborted by touch extended from scene 1
    run_scene(scene2);

    if out2.Success
        error_type = 7;  % touch outside of the window
    else
        if ~mul2.Success
            if mul2.Waiting
                error_type = 3;  % no touch
            else
                error_type = 4;  % touch not held
            end
        end
    end
end

trialerror(error_type);

switch error_type
    case 0, dashboard(3,sprintf('TaskObject#%d is chosen',mul2.ChosenTarget),[1 1 0]);
    case 3, dashboard(3,'The screen was not touched',[1 1 1]);
    case 4, dashboard(3,'Touch was not held long enough',[1 1 1]);
    case 7, dashboard(3,'The outside of the window is touched',[1 0 0]);
end
