% Exit early when the x key is pressed
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

% Make a scene that spends 3 seconds
tc = TimeCounter(null_);
tc.Duration = 3000;

% Save the initial condition of the scene
scene = create_scene(tc,1);  % Display TaskObject#1 during the scene

% Run the scene
run_scene(scene,10);  % Eventcode 10 is sent out at the beginning of the scene.
                      % The scene ends when TimeCounter stops after 3 s.
                      
idle(50,[],20);       % Clear the screens at the end and send Eventcode 20. Without this line,
                      % TaskObject#1 stays on the screen through the inter-trial interval.