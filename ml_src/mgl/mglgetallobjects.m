function [id,type,active] = mglgetallobjects()
%[id,type,active] = mglgetallobjects()
%   types - 'BITMAP','MOVIE',etc.

[id,type,active] = mdqmex(11,2);
