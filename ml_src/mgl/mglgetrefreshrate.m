function refreshrate = mglgetrefreshrate(screen)

if ~exist('screen','var'), screen = 1; end

refreshrate = mdqmex(1,208,screen);
