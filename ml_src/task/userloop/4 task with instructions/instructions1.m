hotkey('x', 'TrialRecord.Quit = true; assignin(''caller'',''continue_'',false);');
set_bgcolor([1 1 1]);
set_iti(0);

% create scenes
fontface = 'Arial';
fontsize = 20;
fontcolor = [0 0 0];
fontstyle = 'bold';
halign = 'center';
valign = 'middle';

txt = TextGraphic(null_);
txt.List = { 'Instructions for the task',EyeCal.norm2deg([0.5 0.15]),fontface,fontsize,fontcolor,fontstyle,halign,valign; ...
    'In the next screen, you will see 9 objects presented in a 3-by-3 layout.',EyeCal.norm2deg([0.1 0.3]),fontface,fontsize,fontcolor,fontstyle,'left',valign; ...
    'Find an object different from the other two in each row and move it to',EyeCal.norm2deg([0.1 0.4]),fontface,fontsize,fontcolor,fontstyle,'left',valign; ...
    'the answer pads on the right. A trial ends when you answer all three',EyeCal.norm2deg([0.1 0.5]),fontface,fontsize,fontcolor,fontstyle,'left',valign; ...
    sprintf('rows correctly. You need to finish %d trials.',TrialRecord.User.max_trial),EyeCal.norm2deg([0.1 0.6]),fontface,fontsize,fontcolor,fontstyle,'left',valign; ...
    'Press x key if you want to quit during the task.',EyeCal.norm2deg([0.1 0.7]),fontface,fontsize,fontcolor,fontstyle,'left',valign; ...
    'Touch here to start',EyeCal.norm2deg([0.5 0.85]),fontface,fontsize,fontcolor,fontstyle,halign,valign };

fix = SingleTarget(touch_);
fix.Target = txt.Position(end,:);
fix.Threshold = txt.Size(end,:);
fth = FreeThenHold(fix);
fth.MaxTime = Inf;
fth.HoldTime = 0;

cont = AllContinue(txt);
cont.add(fth);

scene = create_scene(cont);

% run scenes
while istouching(), end
t_flip = run_scene(scene);
idle(50);

rt = fth.RT;
trialerror(0);
