function [width,height,refresh_rate] = mglgetadapterdisplaymode(adapter_no)

if ~exist('adapter_no','var'), error('The adapter number must be provided.'); end
nadapter = mglgetadaptercount;
if adapter_no<1 || nadapter<adapter_no, error('Adapter #%d does not exist (max: %d).',adapter_no,nadapter); end

[width,height,refresh_rate] = mdqmex(0,2,adapter_no-1);  % 0-based
