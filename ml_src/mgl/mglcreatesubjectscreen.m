function mglcreatesubjectscreen(adapter_no,color,fallback_screen_size,forced_fallback)

if ~exist('adapter_no','var'), error('The adapter number must be provided.'); end
nadapter = mglgetadaptercount;
if adapter_no<1 || nadapter<adapter_no, error('Adapter #%d does not exist (max: %d).',adapter_no,nadapter); end

if ~exist('color','var'), color = [0 0 0]; end
if 3~=numel(color), error('Color must be [R G B].'); end
if max(color(:))<=1, color = color*255; end

if ~exist('fallback_screen_size','var'), fallback_screen_size = [0 0 1024 768]; end
if ischar(fallback_screen_size), fallback_screen_size = eval(fallback_screen_size); end
if 4~=numel(fallback_screen_size), error('Fallback screen must be [left top right bottom].'); end

if ~exist('forced_fallback','var'), forced_fallback = false; end

mdqmex(1,1,adapter_no-1,color,int32(fallback_screen_size),logical(forced_fallback));
