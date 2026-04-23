function imdata2 = mglimresize(imdata,scale,method)

if ~exist('method','var'), method = 'bilinear'; end

if ~isa(imdata,'uint8')
    if max(imdata(:))<=1, imdata = imdata*255; end
    imdata = uint8(imdata);
end

sz = size(imdata);
if length(sz)<3, sz(3) = 1; end
if length(sz)<4, sz(4) = 1; end

if isscalar(scale)
    numrows = round(sz(2) * scale);
    numcols = round(sz(1) * scale);
else
    numrows = round(scale(2));
    numcols = round(scale(1));
end

warning('off','MATLAB:griddedInterpolant:MeshgridEval2DWarnId');
imdata2 = zeros(numcols,numrows,sz(3),sz(4),'uint8');
[x,y] = meshgrid(1:sz(2),1:sz(1));
[nx,ny] = meshgrid(linspace(1,sz(2),numrows),linspace(1,sz(1),numcols));
for m=1:sz(4)
    for n=1:sz(3)
        try
            imdata2(:,:,n,m) = uint8(interp2(x,y,double(imdata(:,:,n,m)),nx,ny,method));
        catch
            % do nothing
        end
    end
end

end
