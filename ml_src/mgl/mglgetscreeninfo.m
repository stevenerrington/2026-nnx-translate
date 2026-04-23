function info = mglgetscreeninfo(screen,prop)

if ~exist('screen','var'), screen = 1; end

info = mdqmex(1,201,screen);
if exist('prop','var'), info = info.(prop); end
