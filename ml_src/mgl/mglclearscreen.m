function mglclearscreen(varargin)

switch nargin
    case 0, screen = 3; color = [];
    case 1, if isscalar(varargin{1}), screen = varargin{1}; color = []; else, screen = 3; color = varargin{1}; end
    case 2, if isscalar(varargin{1}), screen = varargin{1}; color = varargin{2}; else, screen = varargin{2}; color = varargin{1}; end
end
if ~isempty(color)
    if 3~=numel(color), error('Color must be [R G B].'); end
    if max(color(:))<=1, color = color*255; end
end

mdqmex(1,202,screen,color);
