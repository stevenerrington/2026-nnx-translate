isML2 = isobject(TrialRecord);
ai = [];
if isML2, ai = get_device(DAQ,'eye'); else ai = DaqInfo.AnalogInput; end
if isempty(ai), error('This test requires real eye signals, not simulated ones.'); end
str = 'This task will end after 10 trials.';
if isML2, dashboard(1,str); else user_text(str); end

idle(100);
t = zeros(40000,1);
n = t;
c = 0;
flushdata(ai);
tic;
while toc < 1
    c = c + 1;
    t(c) = toc;
    n(c) = ai.SamplesAvailable;
end
t = t(1:c) * 1000;
n = n(1:c);

bhv_variable('read_count',c);
bhv_variable('unique_count',length(unique(n)));
if isML2
    bhv_variable('time',t);
    bhv_variable('sample_count',n);
end
set_iti(0);
if 10<=TrialRecord.CurrentTrialNumber, TrialRecord.Quit = true; end
