function out = decodeframe(in)

if isempty(in.Frame), out = []; return, end
if isa(in.Frame,'uint8'), out = in.Frame; return, end

if iscell(in.Frame)
    sz = [in.Size length(in.Frame)];
else
    sz = size(in.Frame);
    switch ndims(in.Frame)
        case 2, sz(3) = 1;
        case 3  % do nothing
        otherwise, error('The frame data must be 2 or 3 dimensional!!!');
    end
    out = zeros([sz(1:2) 3 sz(3)],'uint8');
end

switch in.Format
    case 'MJPEG'
        out = permute(mdqmex(11,16,sz,in.Frame),[3 2 1 4]);
        if in.VerticalFlip, out = flip(out,1); end
    case 'RGB565'
        for m=1:sz(3)
            out(:,:,1,m) = bitand(in.Frame(:,:,m),63488)/256;
            out(:,:,2,m) = bitand(in.Frame(:,:,m),2016)/8;
            out(:,:,3,m) = bitand(in.Frame(:,:,m),31)*8;
        end
    case 'YUY2'  % a.k.a. YUYV
        for m=1:sz(3)
            c = (int32(bitand(in.Frame(:,:,m),255)) - 16) * 298;  % Y0Y1
            d = int32(bitand(in.Frame(:,:,m),65280))/256 - 128;   % UVUV
            e = reshape([d(:,2:2:end,:); d(:,2:2:end,:)],size(d,1),[]);  % V
            d = reshape([d(:,1:2:end,:); d(:,1:2:end,:)],size(d,1),[]);  % U
            out(:,:,1,m) = uint8((c + 409*e + 128)/256);          % R
            out(:,:,2,m) = uint8((c - 100*d - 208*e + 128)/256);  % G
            out(:,:,3,m) = uint8((c + 516*d + 128)/256);          % B
        end
    case 'RGB555'
        for m=1:sz(3)
            out(:,:,1,m) = bitand(in.Frame(:,:,m),31744)/128;
            out(:,:,2,m) = bitand(in.Frame(:,:,m),992)/4;
            out(:,:,3,m) = bitand(in.Frame(:,:,m),31)*8;
        end
end
