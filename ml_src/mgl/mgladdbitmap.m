function id = mgladdbitmap(varargin)
%id = mgladdbitmap(filename [,colorkey])
%id = mgladdbitmap(bits [,colorkey])

if 0==nargin, error('The first argument must be either filename or bitmat data.'); end

default_colorkey = [30 31 32];
switch nargin
    case 1, colorkey = default_colorkey; device = 3;
    case 2, if isscalar(varargin{2}), device = varargin{2}; colorkey = default_colorkey; else, device = 3; colorkey = varargin{2}; end
    case 3, if isscalar(varargin{2}), device = varargin{2}; colorkey = varargin{3}; else, colorkey = varargin{2}; device = varargin{3}; end
end
if max(colorkey(:))<=1, colorkey = colorkey*255; end

if ischar(varargin{1})
    filename = varargin{1};
    if 2~=exist(filename,'file'), error('The file, %s, does not exist.',filename); end
    [~,~,ext] = fileparts(filename);
    if ~strcmpi(ext,'.bmp'), error('Only a BMP file can be added directly.'); end
    id = mdqmex(2,1,filename,colorkey,device);
else
    bits = varargin{1};
    if verLessThan('matlab','9.7'), [sz(1),sz(2),sz(3),sz(4)] = size(bits); else, sz = size(bits,[1 2 3 4]); end
    if ~any([1 3 4]==sz(3)), error('The first argument doesn''t look like a bitmap or movie.'); end
    if ~isa(bits,'uint8'), if max(bits(:))<=1, bits = bits*255; end, bits = cast(bits,'uint8'); end
    if 1==sz(3), bits = repmat(bits,[1 1 3]); sz(3) = 3; end
    if 3==sz(3), bits(:,:,4,:) = 255; bits = circshift(bits,[0 0 1 0]); end
    id = mdqmex(2,1,sz,flipud(reshape(permute(bits,[3 2 1 4]),4,[])),colorkey,device);
end
