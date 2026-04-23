function [inVBlank,ScanLine] = mglgetrasterstatus(screen)

if ~exist('screen','var'), screen = 1; end

[inVBlank,ScanLine] = mdqmex(1,206,screen);
