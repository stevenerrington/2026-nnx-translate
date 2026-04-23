function id = mgladdmovie(filename,buffering_time,device)
%id = mgladdmovie(filepath [,buffering_time])
%id = mgladdmovie(imdata,time_per_frame)
%id = mgladdmovie(sz,time_per_frame)
%   filepath - avi, mpg
%	buffering_time - in seconds
%   sz - [width height]
%   time_per_frame - in milliseconds.

if ~exist('buffering_time','var') || isempty(buffering_time), buffering_time = 0.2; end
if ~exist('device','var'), device = 3; end

if ischar(filename)
    [~,~,e] = fileparts(filename);
    switch lower(e)
        case '.gif'  % animated GIF
            try imdata = mglimread(filename,'frames','all'); catch, error('A problem occurred while reading %s',filename); end
            info = imfinfo(filename);
            if isfield(info,'DelayTime'), time_per_frame = median([info.DelayTime]) / 100; else, time_per_frame = 0.04; end
            sz = size(imdata);
            id = mdqmex(2,2,sz([2 1]),time_per_frame,device);
            mglsetproperty(id,'addframe',imdata);
        otherwise
            id = mdqmex(2,2,filename,buffering_time,device);
    end
elseif 1<nargin
    time_per_frame = buffering_time / 1000;  % milliseconds to seconds
    if isvector(filename)
        sz = filename;
        id = mdqmex(2,2,sz,time_per_frame,device);
    else
        imdata = filename;
        sz = size(imdata);
        id = mdqmex(2,2,sz([2 1]),time_per_frame,device);
        mglsetproperty(id,'addframe',imdata);
    end
else
    error('''time_per_frame'' is not provided!!!');
end
