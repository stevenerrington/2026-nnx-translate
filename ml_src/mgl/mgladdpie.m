function id = mgladdpie(color,sz,start_degree,center_angle,device)
%id = mgladdpie(color,sz,start_degree,central_angle)
%   color - color can be a 1-by-3 or 2-by-3 ([edgecolor; facecolor]) matrix.
%   sz - [width height]
%   start_degree - 0 to 360 degrees
%   center_angle - 0 to 360 degrees

if max(color(:))<=1, color = color*255; end
if isscalar(sz), sz = [sz sz]; end
if ~exist('device','var'), device = 3; end

id = mdqmex(2,7,color',sz,start_degree,center_angle,device);
