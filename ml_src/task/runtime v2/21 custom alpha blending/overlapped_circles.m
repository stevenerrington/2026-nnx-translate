hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

% Shapes drawn by MGL already have fixed alpha channel values, but you can
% use the ImageGraphic adapter and provide a bitmap data, including the
% alpha channel, as you want. In MGL, you can use a matrix of Y-by-X-by-4
% to represent an ARGB bitmap or load from PNG files.

radius = 1.5;  % in degrees
imdata = make_circle(radius*Screen.PixelsPerDegree,[1 1 1],1);  % make_circle(radius_in_pixels,color,fill)
imdata(:,:,1) = imdata(:,:,1) / 2;  % imdata(:,:,1): alpha
                                    % imdata(:,:,2): red
                                    % imdata(:,:,3): green
                                    % imdata(:,:,4): blue

crc = ImageGraphic(null_);
crc.ImageList = {imdata,[-1 -0.7]; imdata,[1 -0.7]; imdata,[0 1]};
tc = TimeCounter(crc);
tc.Duration = 5000;
scene = create_scene(tc);

run_scene(scene);
idle(50);
