function rect = Pos2Rect(position)
%rect = Pos2Rect(position)
%	position - [left bottom width height] in MATLAB coordinates
%   rect - [left top right botton] in Windows coordinates
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

mglgetadaptercount;  % make MATLAB aware of DPI

screensize = get(0,'ScreenSize');
DPI_ratio = mglgetadapterdisplaymode(1) / screensize(3);

position(:,1) = position(:,1) - 1;
position(:,2) = screensize(4) - position(:,4) - position(:,2) + 1;
if ~verLessThan('matlab','8.6'), position = position * DPI_ratio; end
position(:,3:4) = position(:,3:4) + position(:,1:2);

rect = position;
