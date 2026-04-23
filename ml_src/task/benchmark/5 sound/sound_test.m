isML2 = isobject(TrialRecord);
str = 'This task will end after 100 trials.';
if isML2, dashboard(1,str); else user_text(str); end

t1 = trialtime;
t2 = toggleobject(1,'eventmarker',1);
idle(100);
t3 = trialtime;
t4 = toggleobject(1,'eventmarker',0);

bhv_variable('stim_on',t2-t1);
bhv_variable('stim_off',t4-t3);
set_iti(0);
if 100<=TrialRecord.CurrentTrialNumber, TrialRecord.Quit = true; end
