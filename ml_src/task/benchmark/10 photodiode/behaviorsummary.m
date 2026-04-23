function len = behaviorsummary(filename)

if ~exist('filename','var'), filename = []; end
[data,~,~,filename] = mlread(filename);
[~,n,e] = fileparts(filename);
filename = [n e];

stim_dur = round(data(1).VariableChanges.stim_dur);

ntrial = length(data);
pd = cell(1,3);
for m=1:3, pd{m} = zeros(stim_dur(m)+51,ntrial); end
len = zeros(ntrial,6);

for m=1:ntrial
    try
        code = data(m).BehavioralCodes.CodeNumbers;
        time = data(m).BehavioralCodes.CodeTimes;
        idx = [find(10==code,1) find(20==code,1) find(30==code,1)];
        t = time(idx);
        len(m,1:3) = time(idx+1) - t;  % lengths based on timestamp

        p = data(m).AnalogData.PhotoDiode;
        p_max = max(p);
        p_min = min(p);
        threshold = p_min + 0.5*(p_max-p_min);
        d = diff(threshold<p);
        len(m,4:6) = find(-1==d) - find(1==d);  % lengths based on signal

        t = round(t);
        for n=1:3, pd{n}(:,m) = p(t(n):t(n)+stim_dur(n)+50); end
    catch err
        err
    end
end

pd_max = max(max(pd{1}));
pd_min = min(min(pd{1}));
margin = 0.1 * (pd_max - pd_min);
ylim = [pd_min-margin pd_max+margin];

figure;
set(gcf,'Name',filename);

for m=1:3
    subplot(2,3,m); hold on;
    plot(pd{m});
    plot([stim_dur(m) stim_dur(m)],ylim,'r:');
    set(gca,'xlim',[0 stim_dur(m)+50],'ylim',ylim);
    xlabel('Time from stim onset (ms)');
    ylabel('Voltage');
    title(sprintf('Stim%d: %d ms',m,stim_dur(m)));
end

for m=1:3
    subplot(2,3,m+3); hold on;
    plot(len(:,m),'bx');
    plot(len(:,m+3),'ro');
    xlabel('Trials');
    ylabel('PD signal duration (ms)');
    title(sprintf('Stim%d: %d ms',m,stim_dur(m)));
    legend('Timestamp','PD signal');
end
