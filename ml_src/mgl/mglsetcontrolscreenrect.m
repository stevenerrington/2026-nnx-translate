function mglsetcontrolscreenrect(rect)

if 4~=numel(rect), error('rect must be [left top right bottom]'); end
if any(0==rect(3:4)-rect(1:2)), return, end

mdqmex(1,105,int32(rect));
