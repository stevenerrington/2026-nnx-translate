function mglpngwrite(imdata,filename)

if 4~=size(imdata,3), error('The third dimension of the image data needs to be 4.'); end

[p,n] = fileparts(filename);
if ~isempty(p), p = [p filesep]; end
nframe = size(imdata,4);
ndigit = ceil(log10(nframe));
postfix = ['_%' num2str(ndigit) 'd'];

for m=1:nframe
    A = imdata(:,:,2:4,m);
    if ~isa(A,'uint8')
        if max(A(:))<=1, A = A*255; end
        A = uint8(A);
    end
    alpha = double(imdata(:,:,1,m)) / 255;

    if 0==ndigit
        fn = [p n '.png'];
    else
        fn = [p n sprintf(postfix,m-1) '.png'];
    end
    imwrite(A,fn,'alpha',alpha);
end

end
