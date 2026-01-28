function event_table_clean = clean_eventcodes(event_table_raw)

% Logical vector: state is positive
isPositive = event_table_raw.full_words > 0;

% Logical vector: previous state was zero or less
prevZeroOrLess = [true; event_table_raw.full_words(1:end-1) <= 0];

% First positive instance after zero
firstAfterZero = isPositive & prevZeroOrLess;

% Extract those rows
event_table_clean = event_table_raw(firstAfterZero, :);