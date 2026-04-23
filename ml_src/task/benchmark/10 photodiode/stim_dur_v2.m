if 1==MLConfig.PhotoDiodeTrigger||0==MLConfig.PhotoDiodeTriggerSize||~DAQ.photodiode_present(), error('This test requires the photodiode input.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

bhv_code(10,'Stim1 ON',11,'Stim1 OFF',20,'Stim2 ON',21,'Stim2 OFF',30,'Stim3 ON',31,'Stim3 OFF');

editable('stim_dur','max_trial');
stim_dur = [100 200 300]; 
max_trial = 50;

dashboard(1,sprintf('Test %d/%d',TrialRecord.CurrentTrialNumber,max_trial));
dashboard(2,sprintf('Stim duration: %d %d %d',stim_dur));

tc1 = TimeCounter(null_);
tc1.Duration = stim_dur(1);
scene1 = create_scene(tc1,1);

tc2 = TimeCounter(null_);
tc2.Duration = stim_dur(2);
scene2 = create_scene(tc2,1);

tc3 = TimeCounter(null_);
tc3.Duration = stim_dur(3);
scene3 = create_scene(tc3,1);

run_scene(scene1,10);
idle(100 + rand*Screen.FrameLength,[],11);

run_scene(scene2,20);
idle(100 + rand*Screen.FrameLength,[],21);

run_scene(scene3,30);
idle(100 + rand*Screen.FrameLength,[],31);

if max_trial==TrialRecord.CurrentTrialNumber, TrialRecord.Quit = true; end
