function mglsetscreencolor(screen,color)

if isempty(screen), screen = 3; end
if 3~=numel(color), error('Color must be [R G B].'); end
if max(color)<=1, color = color*255; end

mdqmex(1,203,screen,color);
