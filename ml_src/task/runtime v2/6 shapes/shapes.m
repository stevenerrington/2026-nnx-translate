if ~exist('eye_','var'), error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

dashboard(1,'FINDING STAR',[0 1 0]);
dashboard(2,'What shape can we use as a stimulus?');
dashboard(3,'Anything that you can draw!',[1 0 0]);

nstim = 10;  % we will draw 10 stimuli
sz = ones(nstim,2) + 4 * repmat(rand(nstim,1),1,2);  % 1-5 degrees
color = [163 73 164; 63 72 204; 0 162 232; 34 177 76; 255 242 0; 255 127 39; 237 28 36];  % 7 preset colors
c = color(ceil(7*rand(nstim,1)),:);  % 10-by-3 matrix
scrsize = Screen.SubjectScreenFullSize / Screen.PixelsPerDegree;  % screen size in degrees
position = repmat(2.5,nstim,2) + repmat(scrsize-5,nstim,1).*rand(nstim,2) - repmat(scrsize/2,nstim,1);  % [0 0] is the screen center

% create scene

% chain #1
% Graphic adapters (star1 and text1 below) do not change the Success and
% continue_ status of the child adapter. So the adapter that determines
% when to stop the chain (i.e., topmost adapter) here is, in effect, wth1.
fix1 = SingleTarget(eye_);
fix1.Target = position(1,:);  % The 'star' is the 1st stimulus.
fix1.Threshold = sz(1,1);

wth1 = WaitThenHold(fix1);
wth1.WaitTime = 5000;
wth1.HoldTime = 0;

star1 = PolygonGraphic(wth1);
star1.EdgeColor = c(1,:);
star1.FaceColor = c(1,:);
star1.Size = sz(1,:);
star1.Position = position(1,:);
star1.Vertex = [0.5 1; 0.375 0.625; 0 0.625; 0.25 0.375; 0.125 0; 0.5 0.25; 0.875 0; 0.75 0.375; 1 0.625; 0.625 0.625];

text1 = TextGraphic(star1);
text1.Text = 'Star';
text1.FontSize = sz(2,1)*20;          % in points
text1.FontColor = c(2,:);
text1.Position = position(2,:);
text1.HorizontalAlignment = 'center';  % 'left', 'center', 'right'
text1.VerticalAlignment = 'middle';    % 'top', 'middle', 'bottom'
text1.Angle = 360 * rand;

% chain #2
% If some graphic objects are always displayed together, you can link them
% all in the same chain, for convenience.
crc2 = CircleGraphic(null_);
crc2.EdgeColor = c(3,:);
crc2.FaceColor = c(3,:);
crc2.Size = sz(3,:);
crc2.Position = position(3,:);

tri2 = PolygonGraphic(crc2);
tri2.EdgeColor = c(4,:);
tri2.FaceColor = c(4,:);
tri2.Size = sz(4,:);
tri2.Position = position(4,:);
tri2.Vertex = [0.5 1; 0.067 0.25; 0.9333 0.25];  % normalized coordinates

sqr2 = BoxGraphic(tri2);
sqr2.EdgeColor = c(5,:);
sqr2.FaceColor = c(5,:);
sqr2.Size = sz(5,:);
sqr2.Position = position(5,:);

dia2 = BoxGraphic(sqr2);
dia2.EdgeColor = c(6,:);
dia2.FaceColor = c(6,:);
dia2.Size = sz(6,:);
dia2.Position = position(6,:);
dia2.Angle = 45;

pie2 = PieGraphic(dia2);
pie2.EdgeColor = c(7,:);
pie2.FaceColor = c(7,:);
pie2.Size = sz(7,:);
pie2.Position = position(7,:);
pie2.StartDegree = 360 * rand;
pie2.CenterAngle = 45 + 270 * rand;

pen2 = PolygonGraphic(pie2);
pen2.EdgeColor = c(8,:);
pen2.FaceColor = c(8,:);
pen2.Size = sz(8,:);
pen2.Position = position(8,:);
pen2.Vertex = [0.5 1; 0.0245 0.6545; 0.2061 0.0955; 0.7939 0.0955; 0.9755 0.6545];

% chain #3 & #4
% Adapters do not have to be in one chain. You can define many chains and
% combine them with one of the aggregator adapters, like Concurrent here.
hex3 = PolygonGraphic(null_);
hex3.EdgeColor = c(9,:);
hex3.FaceColor = c(9,:);
hex3.Size = sz(9,:);
hex3.Position = position(9,:);
hex3.Vertex = [0.5 1; 0.067 0.75; 0.067 0.25; 0.5 0; 0.933 0.25; 0.933 0.75];

oct4 = PolygonGraphic(null_);
oct4.EdgeColor = c(10,:);
oct4.FaceColor = c(10,:);
oct4.Size = sz(10,:);
oct4.Position = position(10,:);
oct4.Vertex = [0.5 1; 0.1464 0.8536; 0 0.5; 0.1464 0.1464; 0.5 0; 0.8536 0.1464; 1 0.5; 0.8536 0.8536];

% The Concurrent adapter runs multiple chains together, but only the first
% chain determine the Success and continue_ status of the Concurrent. See
% the manual for more information of other aggregator adapters.
con1 = Concurrent(text1);
con1.add(pen2);
con1.add(hex3);
con1.add(oct4);

scene1 = create_scene(con1);

% task
run_scene(scene1);
if wth1.Success
    trialerror(0);  % correct
else
    trialerror(2);  % no or late response
end
rt = wth1.RT;

set_iti(500);
