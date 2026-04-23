function [imdata,imagefile,modality] = load_cursor(imagefile, shape, color, sz, device, fill)

modality = 0;
if ~isempty(imagefile) && 2~=exist(imagefile,'file'), imagefile = ''; end
if ~exist('fill','var'), fill = 1; end

[~,~,e] = fileparts(imagefile);
if strcmpi(e,'.gif'), if 1==length(imfinfo(imagefile)), e = 'static_gif'; else, e = 'animated_gif'; end, end
switch lower(e)
    case ''
        modality = 1;
        switch lower(shape)
            case {1,'circle'}, imdata = make_circle(sz,color,fill);
            otherwise, imdata = make_rectangle(sz,color,fill);
        end
    case {'.png','.jpg','.jpeg','.bmp','.tif','.tiff','static_gif'}
        modality = 1;
        imdata = mglimread(imagefile);
    case {'.3g2','.3gp','.3gp2','.3gpp','.asf','.wmv','.m4a','.m4v','.mov','.mp4','.avi','.mpg','.mpeg','animated_gif'}
        modality = 2;
        if ~exist('device','var'), imdata = mglimread(imagefile); end
end

if exist('device','var')
   switch modality
       case 1
           imdata = mgladdbitmap(imdata,device);
       case 2
           imdata = mgladdmovie(imagefile,[],device);
           mglsetproperty(imdata,'looping',true);
   end
end
