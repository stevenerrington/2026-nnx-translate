hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
dashboard(1,'Touch anywhere on the screen and you will see a small star where you touch');

idle(100);  % If TouchMarker is in the first scene, touches made during ITI
            % are registered. To prevent it, run the idle command, which is
            % a blank scene.

tm = TouchMarker(touch_);
% This is the same format as the List property of the PolygonGraphic
% adapter. The position part will be ignored.
tm.Polygon = { [1 1 1], [1 1 1], 0.5, [0 0], ...  % edgecolor, facecolor, size, position
            [0.5 1; 0.375 0.625; 0 0.625; 0.25 0.375; 0.125 0; 0.5 0.25; 0.875 0; 0.75 0.375; 1 0.625; 0.625 0.625], ...  % vertex
            1, 0 };  % scale, angle
tc = TimeCounter(tm);
tc.Duration = 10000;
scene = create_scene(tc);
run_scene(scene);
