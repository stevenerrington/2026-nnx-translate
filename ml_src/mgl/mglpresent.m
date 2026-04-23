function varargout = mglpresent(screen,varargin)

if ~exist('screen','var'), screen = 3; end

fliptime = mdqmex(9,1,screen,varargin{:});
if 0<nargout, varargout{1} = fliptime; end
