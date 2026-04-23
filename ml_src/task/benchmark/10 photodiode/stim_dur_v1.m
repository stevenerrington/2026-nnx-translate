if 1==MLConfig.PhotoDiodeTrigger||0==MLConfig.PhotoDiodeTriggerSize||~DAQ.photodiode_present(), error('This test requires the photodiode input.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

bhv_code(10,'Stim1 ON',11,'Stim1 OFF',20,'Stim2 ON',21,'Stim2 OFF',30,'Stim3 ON',31,'Stim3 OFF');

editable('stim_dur','max_trial');
stim_dur = [100 200 300]; 
max_trial = 50;

dashboard(1,sprintf('Test %d/%d',TrialRecord.CurrentTrialNumber,max_trial));
dashboard(2,sprintf('Stim duration: %d %d %d',stim_dur));

idle(100 + rand*Screen.FrameLength);

toggleobject(1,'eventmarker',10);
idle(stim_dur(1) - 0.5*Screen.FrameLength);
toggleobject(1,'eventmarker',11);
idle(100 + rand*Screen.FrameLength);

toggleobject(1,'eventmarker',20);
idle(stim_dur(2) - 0.5*Screen.FrameLength);
toggleobject(1,'eventmarker',21);
idle(100 + rand*Screen.FrameLength);

toggleobject(1,'eventmarker',30);
idle(stim_dur(3) - 0.5*Screen.FrameLength);
toggleobject(1,'eventmarker',31);
idle(100 + rand*Screen.FrameLength);

if max_trial==TrialRecord.CurrentTrialNumber, TrialRecord.Quit = true; end
