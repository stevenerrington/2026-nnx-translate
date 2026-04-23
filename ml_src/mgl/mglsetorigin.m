function mglsetorigin(id,point)

sz = size(point);
if 0==sz(1), return, end
if 2~=sz(2), error('POINT should be a n-by-2 matrix of [x y].'); end

mdqmex(5,id,point);
