function mglcreateplaybackscreen(subjectscreensize,subjectscreencolor,controlscreenrect,controlscreencolor,refreshrate)

if max(subjectscreencolor(:))<=1, subjectscreencolor = subjectscreencolor*255; end
if max(controlscreencolor(:))<=1, controlscreencolor = controlscreencolor*255; end

mdqmex(1,301,int32(subjectscreensize),uint8(subjectscreencolor),int32(controlscreenrect),uint8(controlscreencolor),refreshrate);
