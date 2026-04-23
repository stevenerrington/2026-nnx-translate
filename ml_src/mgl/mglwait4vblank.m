function mglwait4vblank(state,screen)

if ~exist('state','var'), state = true; end
if ~exist('screen','var'), screen = 1; end

mdqmex(1,207,logical(state),screen);
