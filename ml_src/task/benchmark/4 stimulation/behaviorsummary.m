function behaviorsummary(filename)

if ~exist('filename','var') || ~exist(filename,'file'), filename = ''; end

data = mlread(filename);
uv = [data.UserVars];
t = [[uv.stim_on]' [uv.stim_off]'];
max_t = max(max(t));
bin = linspace(0,max_t,20);

figure;

subplot(1,2,1);
counts = hist(t(:,1),bin);
counts2 = hist(t(:,2),bin);
bar(bin,counts); hold on;
bar(bin,-counts2);
xlabel('Time (msec)');
ylabel('Count');
title(sprintf('Stimulation on/off time (n = %d)',length(t(:,1))));
set(gca,'xlim',bin([1 end]) + [-1 1]*bin(2),'ytick',-100:20:100,'yticklabel',[100:-20:0 20:20:100]);
legend('Stimulation on','Stimulation off');

subplot(1,2,2);
plot(t,'o');
xlabel('# of calls');
ylabel('Time (msec)');
title('Stimulation on/off time');

end
