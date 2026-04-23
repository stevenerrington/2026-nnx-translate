function mglcreatecontrolscreen(rect,bgcolor)

subject_screen = mglgetscreeninfo(1);
if isempty(subject_screen), error('Create the subject screen first.'); end

if exist('rect','var')
    nadapter = mglgetadaptercount;
    screen_rect = zeros(nadapter,4);
    for m=1:nadapter, screen_rect(m,:) = mglgetadapterrect(m); end
    intersect = IntersectRect(rect, screen_rect);
    
    area = (intersect(:,3)-intersect(:,1)) .* (intersect(:,4)-intersect(:,2));
    if all(0==area), error('The specified rect is out of screen.'); end
    [~,adapter_no] = max(area);
    
    if 1 < nadapter && adapter_no == subject_screen.Device && all(mglgetadapterrect(adapter_no)==subject_screen.Rect)
        error('The main menu window will be occluded by the subject screen. Please move it to a different location and try again.');
    end
else
    adapter_no = 1;
    rect = [0 0 800 600];
end

if ~exist('bgcolor','var'), bgcolor = [0.25 0.25 0.25]; end
if 3~=numel(bgcolor), error('Color must be [R G B].'); end
if max(bgcolor(:))<=1, bgcolor = bgcolor*255; end

mdqmex(1,101,adapter_no-1,bgcolor,int32(rect));
