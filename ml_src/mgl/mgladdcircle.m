function id = mgladdcircle(color,sz,device)
%id = mgladdcircle(color,sz)
%   color - color can be a 1-by-3 or 2-by-3 ([edgecolor; facecolor]) matrix.
%   sz - [width height]

if max(color(:))<=1, color = color*255; end
if isscalar(sz), sz = [sz sz]; end
if ~exist('device','var'), device = 3; end

id = mdqmex(2,4,color',sz,device);
