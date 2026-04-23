hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
if ~exist('mouse_','var'), error('Mouse is not selected on the main menu.'); end
    
mouse_.showcursor(false);  % Turn off the mouse cursor
my = MyAdapter(mouse_);
my.endtime = 3000;
scene = create_scene(my);
run_scene(scene);
idle(50);
