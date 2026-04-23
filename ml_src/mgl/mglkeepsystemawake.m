function [status,priority] = mglkeepsystemawake(state)
% [status,priority] = mglkeepsystemawake
% [status,priority] = mglkeepsystemawake(state)
%   state - 0 (off), 1 (on)

if 0 < nargin
    [status,priority] = mdqmex(11,4,logical(state));
else
    [status,priority] = mdqmex(11,4);
end
