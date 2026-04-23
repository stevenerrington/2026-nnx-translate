function mglsetrasterthreshold(threshold)

if ~exist('threshold','var'), threshold = 0.9; end

mdqmex(11,6,threshold);
