if ~exist('eye_','var'), error('This demo requires eye input. Please enable it in the main menu or try the simulation mode.'); end
if isempty(DAQ.Stimulation{1}), error('This demo requires Stimulation 1. Please assign it in the main menu.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
bhv_code(0,'out',1,'in');

dashboard(1,'Closed Loop Stimulation Demo',[0 1 0]);
dashboard(2,'250 Hz 10 V peak-to-peak biphasic pulses are sent out via Stimulation 1 while fixation is maintained.');
dashboard(3,'Press ''x'' to quit.',[1 0 0]);

fix1 = SingleTarget(eye_);
fix1.Target = 1;
fix1.Threshold = 3;
stim1 = ClosedLoopStimulator(fix1);
stim1.Channel = 1;
stim1.Waveform = [5 -5 0 0]';  % 250 Hz 10 V peak-to-peak bi-phasic pulse
stim1.Frequency = 1000;
mrk1 = OnOffMarker(stim1);
mrk1.OnMarker = 1;
mrk1.OffMarker = 0;
tc1 = TimeCounter(mrk1);
tc1.Duration = 10000;

scene1 = create_scene(tc1,1);
run_scene(scene1);
idle(50);
