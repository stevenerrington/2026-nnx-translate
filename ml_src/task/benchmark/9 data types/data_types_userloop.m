function [C,timingfile,userdefined_trialholder] = data_types_userloop(varargin)

C = [];
userdefined_trialholder = '';

if verLessThan('matlab','8.4')
    error('This task requires NIMH 2.2.');
elseif verLessThan('matlab','9.1')
    timingfile = 'data_types_without_string.m';
else
    timingfile = 'data_types.m';
end

end