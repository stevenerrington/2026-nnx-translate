import os
import numpy as np
import pandas as pd

def get_raw_eventcodes(ttl_directory):
    full_words = np.load(os.path.join(ttl_directory, "full_words.npy"))
    sample = np.load(os.path.join(ttl_directory, "sample_numbers.npy"))
    timestamps = np.load(os.path.join(ttl_directory, "timestamps.npy"))
    states = np.load(os.path.join(ttl_directory, "states.npy"))

    event_table_raw = pd.DataFrame({
        "sample": sample,
        "timestamps": timestamps,
        "full_words": full_words,
        "states": states,
    })

    # Equivalent to bitshift(full_words, -2)
    fw = event_table_raw["full_words"].to_numpy(dtype=np.int64)
    event_table_raw["full_words"] = np.right_shift(fw, 2)
    return event_table_raw


def clean_eventcodes(event_table_raw):
    # Logical vector: state is positive
    is_positive = event_table_raw["full_words"] > 0

    # Logical vector: previous state was zero or less
    prev_zero_or_less = (
        event_table_raw["full_words"].shift(1).fillna(0) <= 0
    )

    # First positive instance after zero
    first_after_zero = is_positive & prev_zero_or_less

    # Extract those rows
    event_table_clean = event_table_raw.loc[first_after_zero].reset_index(drop=True)

    return event_table_clean