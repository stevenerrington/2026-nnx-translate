hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

% Lissajous curve
t = linspace(0,2*pi,1000)';
x = 6 * sin(3*t);
y = 9 * sin(4*t)./1.5;

% create scenes
grat = SineGrating(null_);
grat.List = { [-5 2.5], 2, rand*360, 1, 1, 0, [1 1 1], [0 0 0], 'circular', 0 };

ct = CurveTracer(eye_);
ct.Target = grat;
ct.Trajectory = [x y];

is = ImageStabilizer(eye_);
is.Target = grat;

con = Concurrent(ct);
con.add(is);  % ImageStabilizer (IS) should be added after CurveTracer (CT)

scene1 = create_scene(con);
run_scene(scene1);

idle(50);
