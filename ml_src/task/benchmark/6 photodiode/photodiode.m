isML2 = isobject(TrialRecord);
if isML2
    photodiode_trigger = 1<MLConfig.PhotoDiodeTrigger;
else
    photodiode_trigger = 1<ScreenInfo.PhotoDiode;
end
if ~photodiode_trigger, error('The photodiode trigger is not set. Please change the option on the menu.'); end

str = 'This task sends out eventcodes, 1 & 0, when turning on and off the photodiode trigger.';
if isML2
    frame_length = Screen.FrameLength;
    dashboard(1,str);
else
    frame_length = ScreenInfo.FrameLength;
    user_text(str);
end

t = zeros(101,1);
t2 = zeros(101,1);
for m=1:101
    t(m) = toggleobject(1,'eventmarker',1);
    t2(m) = toggleobject(1,'eventmarker',0);
    idle(1.5*frame_length);
end

bhv_variable('stim_on',t);
bhv_variable('stim_off',t2);
set_iti(0);

TrialRecord.Quit = true;
