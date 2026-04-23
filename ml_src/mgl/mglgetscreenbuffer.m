function buffer = mglgetscreenbuffer(screen)
%buffer = mglgetscreenbuffer(screen)
%   screen - 1 (subject), 2 (control)

buffer = mdqmex(1,204,screen);
