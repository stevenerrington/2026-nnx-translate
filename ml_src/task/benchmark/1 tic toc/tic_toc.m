isML2 = isobject(TrialRecord);
str = 'This task will end after 10 trials.';
if isML2, dashboard(1,str); else user_text(str); end

idle(100);
n = 101;
t = zeros(n,1);
for m=1:n
    t(m) = trialtime;  % in milliseconds
end
c = diff(t) * 10^3;   % in microseconds
s = sort(c);
min_interval = s(find(s~=0,1));

bhv_variable('interval',c);
bhv_variable('min_interval',min_interval);
set_iti(0);
if 10<=TrialRecord.CurrentTrialNumber, TrialRecord.Quit = true; end
