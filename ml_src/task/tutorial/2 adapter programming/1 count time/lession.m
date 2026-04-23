hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

my = MyAdapter(null_);
my.endtime = 3000;
scene = create_scene(my);
run_scene(scene);
idle(50);  % clear the screen after the scene
