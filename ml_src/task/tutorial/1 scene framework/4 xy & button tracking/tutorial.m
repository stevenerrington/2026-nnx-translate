hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

box_pos = [-2 2];

fix = SingleTarget(mouse_);
fix.Target = box_pos;
fix.Threshold = 1;
btn = SingleButton(mouse_);
btn.Button = 1;  % Mouse has two buttons; 1 or 2
and = AndAdapter(fix);
and.add(btn);    % Combined input of an XY pointer and a button
wth = WaitThenHold(and);
wth.WaitTime = 5000;
wth.HoldTime = 0;

box = BoxGraphic(null_);
box.List = { [1 1 1], [1 1 1], [1 1], box_pos };  % { edgecolor, facecolor, size, position, scale, angle }

con = Concurrent(wth);
con.add(box);

scene = create_scene(con);  % Concurrent - WaitThenHold - AndAdapter - SingleTarget - MouseTracker
                            %          |                           +-- SingleButton - MouseTracker
                            %          +-- BoxGraphic - NullTracker

dashboard(1,'Move the mouse cursor over the square & click the mouse left button');
run_scene(scene,10);
idle(50,[],20);
