function id = mgladdtext(string,device)
%mgladdtext(string,device)

if ~exist('device','var'), device = 3; end

id = mdqmex(2,9,string,device);
