hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

switch mod(TrialRecord.CurrentTrialNumber-1,2)+1
    case 1
        x = [0:0.04:3 3:-0.04:-3 -3:0.04:0];  % in degrees
        y = zeros(size(x));
    case 2
        y = [0:0.04:3 3:-0.04:-3 -3:0.04:0];
        x = zeros(size(y));
end
set_object_path(1,x,y);

toggleobject(1:2);
idle(Screen.FrameLength * length(x));
toggleobject(1:2);
set_iti(2000);
