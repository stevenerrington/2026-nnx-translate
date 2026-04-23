function id = BlackrockLED_init(desc)

if ~exist('desc','var'), desc = 'Blinky 1.0'; end

id = mdqmex(2,12,desc);
