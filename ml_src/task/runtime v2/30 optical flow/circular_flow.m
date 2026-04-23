hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

editable('aperture','-color','dot_color','dot_size','num_dot');

speed = (2 * (0.5<rand) - 1) * (round(170 * rand / 10) * 10 + 10);  % -180 to 180
aperture = 10;
dot_color = [1 1 1];
dot_size = 0.5;
num_dot = 100;

dashboard(1,sprintf('Angular speed: %.0f deg/s',speed));

my = CircularOpticalFlow(null_);
my.AngularSpeed = speed;
my.ApertureRadius = aperture;
my.DotColor = dot_color;
my.DotSize = dot_size;
my.NumDot = num_dot;
tc = TimeCounter(my);
tc.Duration = 10000;
scene = create_scene(tc);
run_scene(scene);
