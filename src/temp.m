clear all; clc

dirs.data_dir = '/Users/stevenerrington/Desktop/Projects/2026-nnx-translate/data_example';
session_name = '2026-01-28_08-45-14';

directory = fullfile(dirs.data_dir, session_name);
data = Session(directory);

recording_idx = length(data.recordNodes{1, 1}.recordings);
recording = data.recordNodes{1, 1}.recordings{recording_idx} ;


% Continuous data
recording.continuous.keys()
cont_data = recording.continuous('XDAQ-100.Rhythm Data');

ttl_directory = '/Users/stevenerrington/Desktop/Projects/2026-nnx-translate/data_example/2026-01-28_08-45-14/Record Node 102/experiment1/recording1/events/XDAQ-100.Rhythm Data/TTL';

% Event codes
event_table_raw = get_raw_eventcodes(ttl_directory);
event_table_clean = clean_eventcodes(event_table_raw);
