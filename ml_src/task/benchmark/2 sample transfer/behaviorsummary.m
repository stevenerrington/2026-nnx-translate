function behaviorsummary(filename)

if ~exist('filename','var') || ~exist(filename,'file'), filename = ''; end

data = mlread(filename);
c = data(end).UserVars.read_count;
t = data(end).UserVars.time;
n = data(end).UserVars.sample_count;

figure;

plot(t,n);
xlabel('Time (ms)')
ylabel('Number of available samples')
title(sprintf('Read attempts: %d, Sample transfer: %d',c,length(unique(n))));

end
