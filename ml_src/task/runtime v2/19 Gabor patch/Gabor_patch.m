hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

direction = 360 * rand;
sf = 2*rand + 0.5;  % cycles per degree
tf = 3*rand + 0.5;  % cycles per second

dashboard(1,'Sine grating & Gabor patches',[0 1 0]);
dashboard(2,sprintf('Direction: %.1f deg',direction));
dashboard(3,sprintf('Spatial frequency: %.1f cycles/deg',sf));
dashboard(4,sprintf('Temporal frequency: %.1f cycles/sec',tf));
dashboard(5,'Press ''x'' to quit.',[1 0 0]);

% grat1a = SineGrating(null_);
% grat1a.Position = [-5 2.5];
% grat1a.Radius = 2;
% grat1a.Direction = direction;
% grat1a.SpatialFrequency = sf;
% grat1a.TemporalFrequency = tf;
% grat1a.WindowType = 'circular';  % default window type
% grat1a.Phase = 0;
% 
% grat1b = SineGrating(grat1a);
% grat1b.Position = [0 2.5];
% grat1b.Radius = 2;
% grat1b.Direction = direction + 60;
% grat1b.SpatialFrequency = sf;
% grat1b.TemporalFrequency = tf;
% grat1b.WindowType = 'triangular';
% grat1b.Phase = 120;
% 
% grat1c = SineGrating(grat1b);
% grat1c.Position = [5 2.5];
% grat1c.Radius = 2;
% grat1c.Direction = direction + 120;
% grat1c.SpatialFrequency = sf;
% grat1c.TemporalFrequency = tf;
% grat1c.WindowType = 'sine';
% grat1c.Phase = 240;
% 
% grat1d = SineGrating(grat1c);
% grat1d.Position = [-5 -2.5];
% grat1d.Radius = 2;
% grat1d.Direction = direction + 180;
% grat1d.SpatialFrequency = sf;
% grat1d.TemporalFrequency = tf;
% grat1d.WindowType = 'hann';
% grat1d.Phase = 0;
% 
% grat1e = SineGrating(grat1d);
% grat1e.Position = [0 -2.5];
% grat1e.Radius = 2;
% grat1e.Direction = direction + 240;
% grat1e.SpatialFrequency = sf;
% grat1e.TemporalFrequency = tf;
% grat1e.WindowType = 'hamming';
% grat1e.Phase = 120;
% 
% grat1f = SineGrating(grat1e);
% grat1f.Position = [5 -2.5];
% grat1f.Radius = 3;
% grat1f.Direction = direction + 300;
% grat1f.SpatialFrequency = sf;
% grat1f.TemporalFrequency = tf;
% grat1f.Color1 = [1 0 0];
% grat1f.Color2 = [0 1 0];
% grat1f.WindowType = 'gaussian';
% grat1f.WindowSize = 1;  % sigma in degrees
% grat1f.Phase = 240;
% 
% tc1 = TimeCounter(grat1f);
% tc1.Duration = 5000;

% To create multiple gratings, you can use the List property.
% [position radius direction spatial_freq temporal_freq phase color1 color2 window_type window_size]
grat1 = SineGrating(null_);
grat1.List = { [-5 2.5], 2, direction, sf, tf, 0, [1 1 1], [0 0 0], 'circular', 0; ...
    [0 2.5], 2, direction+60, sf, tf, 120, [1 1 1], [0 0 0], 'triangular', 0; ...
    [5 2.5], 2, direction+120, sf, tf, 240, [1 1 1], [0 0 0], 'sine', 0; ...
    [-5 -2.5], 2, direction+180, sf, tf, 0, [1 1 1], [0 0 0], 'hann', 0; ...
    [0 -2.5], 2, direction+240, sf, tf, 120, [1 1 1], [0 0 0], 'hamming', 0; ...
    [5 -2.5], 3, direction+300, sf, tf, 240, [1 0 0], [0 1 0], 'gaussian', 1 };

tc1 = TimeCounter(grat1);
tc1.Duration = 5000;

scene1 = create_scene(tc1);

run_scene(scene1);
