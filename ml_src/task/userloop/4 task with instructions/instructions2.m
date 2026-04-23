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
txt.List = { 'End of the task',EyeCal.norm2deg([0.5 0.25]),fontface,fontsize,fontcolor,fontstyle,halign,valign; ...
    'Touch here to exit',EyeCal.norm2deg([0.5 0.75]),fontface,fontsize,fontcolor,fontstyle,halign,valign };

fix = SingleTarget(touch_);
fix.Target = txt.Position(end,:);
fix.Threshold = txt.Size(end,:);
fth = FreeThenHold(fix);
fth.MaxTime = Inf;
fth.HoldTime = 0;

tc = TimeCounter(null_);
tc.Duration = 10000;

cont = AllContinue(txt);
cont.add(fth);
cont.add(tc);

scene = create_scene(cont);

% run scenes
while istouching(), end
run_scene(scene);
idle(50);

rt = fth.RT;
trialerror(0);
