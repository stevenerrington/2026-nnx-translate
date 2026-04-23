if ~exist('mouse_','var'), error('This demo requires the mouse input. Please enable it in the main menu or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
mouse_.showcursor(false);  % hide the mouse cursor from the subject screen

dashboard(3,'Move: Left click + Drag, Resize: Right click + Drag',[0 1 0]);
dashboard(4,'Coherence: [LEFT(-) RIGHT(+)], Speed: [DOWN(-) UP(+)]',[0 1 0]);
dashboard(5,'Press ''x'' to quit.',[1 0 0]);

% editables
ApertureShape =  {'Square','Circle','Circle'};
CoherenceStep = 5;
SpeedStep = 0.5;
NumDot = 100;
DotSize = 0.15;
DotColor = [1 1 1];
DotShape = {'Square','Circle','Square'};
editable('-category','ApertureShape','CoherenceStep','SpeedStep','NumDot','DotSize','-color','DotColor','-category','DotShape');

% create scene
if strcmp(ApertureShape{end},'Circle')
    rdm1 = RDM_RF_Mapper(mouse_);
else
    rdm1 = RectRDM_RF_Mapper(mouse_);
end
rdm1.CoherenceStep = CoherenceStep;
rdm1.SpeedStep = SpeedStep;
rdm1.InfoDisplay = true;
rdm1.NumDot = NumDot;
rdm1.DotSize = DotSize;
rdm1.DotColor = DotColor;
rdm1.DotShape = DotShape{end};
scene1 = create_scene(rdm1,1);

% task
run_scene(scene1);
idle(50);

% save parameters
bhv_variable('position',rdm1.Position);
bhv_variable('radius',rdm1.Radius);
bhv_variable('coherence',rdm1.Coherence);
bhv_variable('direction',rdm1.Direction);
bhv_variable('speed',rdm1.Speed);
