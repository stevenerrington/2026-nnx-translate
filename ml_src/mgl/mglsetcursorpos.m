function mglsetcursorpos(position)
%mglsetcursorpos(position)
%	position -    1: center of subject screen
%                -1: return to previous position
%             [x y]: given pixel position

if ~exist('position','var'), position = 0; end

mdqmex(11,5,position);
