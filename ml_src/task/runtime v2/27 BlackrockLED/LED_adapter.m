hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
intensity = 0.005;

led = BlackrockLED(null_);
tc = TimeCounter(led);
led.MaxIntensity = intensity;  % or led.setmax(intensity);

led.load(intensity, 500);      % led.load(intensity, duration);
tc.Duration = 500;
scene = create_scene(tc);
run_scene(scene);
dashboard(1, sprintf('LED temperature: %4.1f %4.1f %4.1f %4.1f', led.Temperature));  % same as led.temp(2);
idle(1000);

pattern2 = repmat([intensity 0; 0 intensity],5,32);
led.load(pattern2,500);
tc.Duration = 5000;
scene = create_scene(tc);
run_scene(scene);
dashboard(1, sprintf('LED temperature: %4.1f %4.1f %4.1f %4.1f', led.temp(2)));  % led.temp(adapter_ver)
idle(1000);
