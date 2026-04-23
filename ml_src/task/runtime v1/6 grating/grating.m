hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

dashboard(1,'Sine Grating Movie',[0 1 0]);
dashboard(2,'Each frame of 3 movies below is created as a square grating from a GEN script.');
dashboard(3,'Their edges are rounded with the alpha channel so that they can be overlapped.');

toggleobject(1:4);
idle(3000);
toggleobject(1:4);
set_iti(2000);
