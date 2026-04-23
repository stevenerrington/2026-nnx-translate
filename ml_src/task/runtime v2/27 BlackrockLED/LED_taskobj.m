hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
intensity = 0.005;

id = TaskObject(1).ID;                  % TaskObject#1
BlackrockLED_setmax(id, intensity);     % change the maximum allowed intensity for safety

BlackrockLED_load(id, intensity, 500);  % load pattern 1
toggleobject(1);                        % play pattern 1
idle(500);
dashboard(1, sprintf('LED temperature: %4.1f %4.1f %4.1f %4.1f', BlackrockLED_temp(id)));  % same as BlackrockLED_temp(id,2)
idle(1000);

toggleobject(1);  % pattern 1 already ended but you still need to turn it off explicitly to turn on again

pattern2 = repmat([intensity 0; 0 intensity],5,32);
BlackrockLED_load(id,pattern2,500);     % load pattern 2
toggleobject(1);                        % play pattern 2
idle(5000);
dashboard(1, sprintf('LED temperature: %4.1f %4.1f %4.1f %4.1f', BlackrockLED_temp(id)));  % same as BlackrockLED_temp(id,2)
idle(1000);
