hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

box_pos = [-2 2];  % box position

fix = SingleTarget(mouse_);  % Any XY tracker such as EyeTracker, JoyTracker and
                             % TouchTracker can be used with SingleTarget.
fix.Target = box_pos;        % [x y] in degrees
fix.Threshold = 1;           % radius; or [width height] for retangular window
wth = WaitThenHold(fix);
wth.WaitTime = 5000;         % wait time till fixation acquisition
wth.HoldTime = 0;            % hold time for fixation

box = BoxGraphic(null_);
box.List = { [1 1 1], [1 1 1], [1 1], box_pos };  % { edgecolor, facecolor, size, position, scale, angle }

con = Concurrent(wth);
con.add(box);

scene = create_scene(con);  % Concurrent - WaitThenHold - SingleTarget - MouseTracker
                            %          +-- BoxGraphic - NullTracker

dashboard(1,'Move the mouse cursor over the square');
run_scene(scene,10);
idle(50,[],20);
