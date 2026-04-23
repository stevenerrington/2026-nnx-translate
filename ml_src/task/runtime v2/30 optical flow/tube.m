hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

editable('-color','circle_color','fill_circle','circle_size','num_circle');

circle_color = [1 1 1];
fill_circle = false;
circle_size = 200;
num_circle = 10;

mouse_.showcursor(false);
my = MyTube(mouse_);
my.Color = circle_color;
my.Fill = fill_circle;
my.Size = circle_size;
my.DepthLevel = num_circle;
tc = TimeCounter(my);
tc.Duration = 10000;
scene = create_scene(tc);
run_scene(scene);
