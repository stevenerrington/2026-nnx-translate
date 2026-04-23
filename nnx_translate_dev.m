
%% BHV2 MonkeyLogic
% AGL TASK
bhv2_file = '/Users/stevenerrington/Desktop/2026-04-15_10-58-15/260415__Elifetask.bhv2';

% Import task data
[data, MLConfig, TrialRecord, filename] = mlconcatenate(bhv2_file);

% Get analog data out
eyes.x = data.AnalogData.Eye(:,1);
eyes.y = data.AnalogData.Eye(:,2);
eyes.pupil = data.AnalogData.EyeExtra;
data = rmfield(data,'AnalogData');

% Convert session infos to table
data = struct2table(data);

%% NNX System
% task detect
% ERROR: msg_text = readNPY('/Users/stevenerrington/Desktop/2026-04-15_10-58-15/Record Node 104/experiment1/recording1/events/MessageCenter/text.npy');
msg_sample_numbers = readNPY('/Users/stevenerrington/Desktop/2026-04-15_10-58-15/Record Node 104/experiment1/recording1/events/MessageCenter/sample_numbers.npy');
msg_timestamps = readNPY('/Users/stevenerrington/Desktop/2026-04-15_10-58-15/Record Node 104/experiment1/recording1/events/MessageCenter/timestamps.npy');

% Extract TTLs
full_words = readNPY('/Users/stevenerrington/Desktop/2026-04-15_10-58-15/Record Node 104/experiment1/recording1/events/XDAQ-100.Rhythm Data/TTL/full_words.npy');
states = readNPY('/Users/stevenerrington/Desktop/2026-04-15_10-58-15/Record Node 104/experiment1/recording1/events/XDAQ-100.Rhythm Data/TTL/states.npy');
sample_numbers = readNPY('/Users/stevenerrington/Desktop/2026-04-15_10-58-15/Record Node 104/experiment1/recording1/events/XDAQ-100.Rhythm Data/TTL/sample_numbers.npy');
timestamps = readNPY('/Users/stevenerrington/Desktop/2026-04-15_10-58-15/Record Node 104/experiment1/recording1/events/XDAQ-100.Rhythm Data/TTL/timestamps.npy');

nnx_ttl_table = table(full_words, states, sample_numbers, timestamps);

fw = int64(nnx_ttl_table.full_words);
nnx_ttl_table.full_words = bitshift(fw, -2);

% Logical vector: state is positive
is_positive = nnx_ttl_table.full_words > 0;

% Previous values (shift down by 1, fill first with 0)
prev_vals = [0; nnx_ttl_table.full_words(1:end-1)];

% Logical vector: previous state was zero or less
prev_zero_or_less = prev_vals <= 0;

% First positive instance after zero
first_after_zero = is_positive & prev_zero_or_less;

% Extract those rows
nnx_ttl_table = nnx_ttl_table(first_after_zero, :);

% Reset index (MATLAB tables don't keep row indices like pandas,
% but you can add one if needed)
nnx_ttl_table = addvars(nnx_ttl_table, (1:height(nnx_ttl_table))', ...
    'Before', 1, 'NewVariableNames', 'Index');

task_idx = 2;

nTrls = length(find(nnx_ttl_table.full_words == 9 &...
    nnx_ttl_table.sample_numbers > msg_sample_numbers (task_idx) & ...
    nnx_ttl_table.sample_numbers < msg_sample_numbers (task_idx + 1)))