function id = mgladdpolygon(color,sz,vertex,device)
%id = mgladdpolygon(color,sz,vertex)
%   color - color can be a 1-by-3 or 2-by-3 ([edgecolor; facecolor]) matrix.
%   sz - [width height]
%   vertex - normalized (0 to 1) coordinates, [x1 y1; x2 y2; ...]

if max(color(:))<=1, color = color*255; end
if isscalar(sz), sz = [sz sz]; end
if ~exist('device','var'), device = 3; end

id = mdqmex(2,8,color',sz,vertex(:,1),1-vertex(:,2),device);
