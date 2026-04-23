if ~exist('mouse_','var'), error('This demo requires the mouse input. Please enable it in the main menu or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
mouse_.showcursor(false);  % hide the mouse cursor from the subject screen

dashboard(3,'Move: Left click + Drag, Resize: Right click + Drag',[0 1 0]);
dashboard(4,'Spatial Frequency: [LEFT(-) RIGHT(+)], Temporal Frequency: [DOWN(-) UP(+)]',[0 1 0]);
dashboard(5,'Press ''x'' to quit.',[1 0 0]);

% editables
SpatialFrequencyStep = 0.1;
TemporalFrequencyStep = 0.1;
Color1 = [1 1 1];
Color2 = [0 0 0];
WindowType = {'none','circular','triangular','sine','cosine','hann','hamming','gaussian','gaussian'};
editable('SpatialFrequencyStep','TemporalFrequencyStep','-color',{'Color1','Color2'},'-category','WindowType');

% create scene
grat1 = Grating_RF_Mapper(mouse_);
grat1.SpatialFrequencyStep = SpatialFrequencyStep;
grat1.TemporalFrequencyStep = TemporalFrequencyStep;
grat1.InfoDisplay = true;
grat1.Color1 = Color1;
grat1.Color2 = Color2;
grat1.WindowType = WindowType{end};
scene1 = create_scene(grat1,1);

% task
run_scene(scene1);
idle(50);

% save parameters
bhv_variable('position',grat1.Position);
bhv_variable('radius',grat1.Radius);
bhv_variable('orientation',grat1.Direction);
bhv_variable('spatial_frequency',grat1.SpatialFrequency);
bhv_variable('temporal_frequency',grat1.TemporalFrequency);
