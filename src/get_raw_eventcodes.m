function event_table_raw = get_raw_eventcodes(ttl_directory)

full_words = readNPY(fullfile(ttl_directory, 'full_words.npy'));
sample = readNPY(fullfile(ttl_directory, 'sample_numbers.npy'));
timestamps = readNPY(fullfile(ttl_directory, 'timestamps.npy'));
states = readNPY(fullfile(ttl_directory, 'states.npy'));

event_table_raw = table(sample,timestamps,full_words,states);
event_table_raw.full_words = bitshift(event_table_raw.full_words, -2);

end