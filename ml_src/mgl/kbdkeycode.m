function kbdkeycode()

fprintf('Press any key to display the key''s scancode.\nPress ESC to end.\n');
kbdinit;

key = [];
while isempty(key) || 1~=key
    key = kbdgetkey;
    if isempty(key), continue, end
    fprintf('key scancode = %d\n',key);
end

kbdrelease;
