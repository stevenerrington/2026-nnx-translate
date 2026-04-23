function mglplaysound(id)
%mglplaysound(id)
%   id - sound object ids. 0 indicates all sound objects

if ~exist('id','var'), id = 0; end

mdqmex(10,id,true);
