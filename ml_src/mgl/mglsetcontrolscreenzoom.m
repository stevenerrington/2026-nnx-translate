function mglsetcontrolscreenzoom(zoom)

if ~exist('zoom','var') || isempty(zoom), error('zoom must be a scalar.'); end

mdqmex(1,106,zoom);
