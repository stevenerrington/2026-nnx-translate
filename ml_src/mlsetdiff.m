function C = mlsetdiff(A,B)
% Unlike setdiff, this function does not sort the result.

if isempty(B), C = A; return, end

if iscell(A)
    if ischar(B), B = {B}; end
    row = strcmp(A,B{1});
    for m=2:length(B)
        row = row|strcmp(A,B{m});
    end
elseif isnumeric(A)
    row = B(1)==A;
    for m=2:length(B)
        row = row|B(m)==A;
    end
else
    error('Input is not numeric nor cell char array');
end

C = A(~row);

end
