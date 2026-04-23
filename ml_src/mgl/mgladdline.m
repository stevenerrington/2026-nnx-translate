function id = mgladdline(color,max_vertex,type,device)
%id = mgladdline(color,max_vertex,type)
%   type - 1 (list), 2 (strip)

if max(color(:))<=1, color = color*255; end
if ~exist('max_vertex','var'), max_vertex = 50; end
if ~exist('type','var'), type = 1; end
if ~exist('device','var'), device = 3; end

id = mdqmex(2,3,color,max_vertex,type,device);
