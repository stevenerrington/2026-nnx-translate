function mglactivategraphic(id,state)
%mglactivategraphic(id,state)
%   id - MGL object ID. 0 indicates all objects.
%   state - 0 (inactive), 1 (active)

if ~exist('state','var'), state = true; end

mdqmex(4,1,id,logical(state));
