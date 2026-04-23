function A = mglimread(filename,varargin)

[~,~,e] = fileparts(filename);
switch lower(e)
    case {'.3g2','.3gp','.3gp2','.3gpp','.asf','.wmv','.m4a','.m4v','.mov','.mp4','.avi','.mpg','.mpeg'}
        id = mgladdmovie(filename,0);
        frames = mglgetproperty(id,'getbuffer');
        A = frames(:,:,:,1);
        mgldestroygraphic(id);
        
    otherwise
        [A,map,transparency] = imread(filename,varargin{:});
        if 3 < size(A,3), [~,n,e] = fileparts(filename); error('%s%s is in the CMYK format, not RGB.',n,e); end
        if ~isempty(map), for m=1:size(A,4), A(:,:,1:3,m) = uint8(255*ind2rgb(A(:,:,1,m),map)); end, end
        A = check_format(A);
        if 1==size(A,3), A = repmat(A,[1 1 3]); end
        if ~isempty(transparency)
            transparency = check_format(transparency);
            A = cat(3,transparency,A);
        end
end

end

function A = check_format(A)
    switch class(A)
        case 'uint8'  % do nothing
        case 'logical', A = uint8(A*255);
        case {'double','single'}, if max(A(:))<=1, A = A*255; end, A = uint8(A);
        otherwise, A = uint8(double(A) / double(intmax(class(A))) * 255);
    end
end
