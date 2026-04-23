isML2 = isobject(TrialRecord);
strobe_present = false;
if isML2
    strobe_present = DAQ.strobe_present();
else
    if isfield(DaqInfo.BehavioralCodes,'DIO') && ~isempty(DaqInfo.BehavioralCodes.DIO)
        strobe_present = true;
    end
end
if ~strobe_present, error('This test requires Behavioral Codes & Strobe Bit'); end
str = 'This task will end after 10 trials.';
if isML2, dashboard(1,str); else user_text(str); end

idle(100);
n = 101;
t = zeros(n,1);
tic;
for m=1:n
    eventmarker(m);
    t(m) = toc;
end
t = diff(t) * 1000;
marker = 1:n;
tic;
eventmarker(marker);
t2 = toc * 1000;

bhv_variable('time',t);
bhv_variable('time2',t2);
set_iti(0);
if 10<=TrialRecord.CurrentTrialNumber, TrialRecord.Quit = true; end
