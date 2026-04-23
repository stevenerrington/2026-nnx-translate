function mglrendergraphic(frameNum,screen,clear)
%mglrendergraphic(frameNum)
%   frameNum - refrech count, 0-based

if ~exist('frameNum','var'), frameNum = 0; end
if frameNum < 0, error('The frame number must be 0 or greater.'); end
if ~exist('screen','var'), screen = 3; end
if ~exist('clear','var'), clear = true; end

mdqmex(8,frameNum,screen,logical(clear));
