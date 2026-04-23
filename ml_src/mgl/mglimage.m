function h = mglimage(C,varargin)

if ~isa(C,'uint8')
    if max(C(:))<=1, C = C*255; end
	C = uint8(C);
end

if 4==size(C,3)
    h = image(C(:,:,2:4,1),varargin{:});
    set(h,'AlphaData',double(C(:,:,1))/255);
else
    h = image(C(:,:,:,1),varargin{:});
end
