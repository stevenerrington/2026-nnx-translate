function state = mglgetkeystate(keycode)
%function state = mglgetkeystate(keycode)
%   state - 0 (released), 1 (pressed)
%	keycode - see https://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx

state = mdqmex(11,3,keycode);
