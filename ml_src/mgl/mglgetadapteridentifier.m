function info = mglgetadapteridentifier(adapter_no)

if ~exist('adapter_no','var'), error('The adapter number must be provided.'); end
nadapter = mglgetadaptercount;
if adapter_no<1 || nadapter<adapter_no, error('Adapter #%d does not exist (max: %d).',adapter_no,nadapter); end

info = mdqmex(0,4,adapter_no-1);  % 0-based
