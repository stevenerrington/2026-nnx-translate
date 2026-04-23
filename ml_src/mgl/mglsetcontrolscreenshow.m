function mglsetcontrolscreenshow(show)

if ~exist('show','var') || isempty(show), error('show must be a scalar.'); end

mdqmex(1,107,logical(show));
