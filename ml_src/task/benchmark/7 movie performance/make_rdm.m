function [imdata,info] = make_rdm(TrialRecord,MLConfig)
try

if exist('MLConfig','var')
    PixelsPerDegree = MLConfig.Screen.PixelsPerDegree;
    RefreshRate = MLConfig.Screen.RefreshRate;
else
    PixelsPerDegree = 30.850;
    RefreshRate = 75;
end
FrameLength = 1000 / RefreshRate;

if (isfield(TrialRecord,'CurrentConditionInfo') || isprop(TrialRecord,'CurrentConditionInfo')) ...
        && isfield(TrialRecord.CurrentConditionInfo,'deg')
    direction = TrialRecord.CurrentConditionInfo.deg;
else
    direction = 0;  % degree
end
if (isfield(TrialRecord,'CurrentConditionInfo') || isprop(TrialRecord,'CurrentConditionInfo')) ...
        && isfield(TrialRecord.CurrentConditionInfo,'coh')
    coherence = TrialRecord.CurrentConditionInfo.coh;
else
    coherence = 100;  % 0-100
end

radius = 2.5;        % degree
speed = 5;           % degees per second
num_dot = 100;
dot_size = 0.069;    % degree
ninterleaf = 3;
duration = 2500;     % msec

nframe = round(RefreshRate * duration / 1000);
scr_dot_size = round(dot_size * PixelsPerDegree);
scr_radius = radius * PixelsPerDegree;
scr_direction = mod(direction + 90,360);
frame_size = ceil(scr_radius + scr_dot_size) * 2;
center = floor(frame_size / 2);

switch scr_direction
    case {0,180}, symmetry_mat = [-1 0; 0 1];
    case {90,270}, symmetry_mat = [1 0; 0 -1];
    otherwise
        a = -1 / tand(scr_direction);
        b = 1 + a*a;
        symmetry_mat = [(2-b)/b 2*a/b; 2*a/b (b-2)/b];
end
num_moving_dot = round(num_dot * coherence / 100);
d = PixelsPerDegree * speed * ninterleaf / RefreshRate;
displacement = repmat([d*cosd(scr_direction) d*sind(scr_direction)],num_moving_dot,1);

dot_position = cell(1,ninterleaf);
for m=1:ninterleaf
    r = (1-rand(num_dot,1).^2) * scr_radius;
    t = rand(num_dot,1) * 360;
    dot_position{m} = [r.*cosd(t) r.*sind(t)];
end

imdata = zeros(frame_size,frame_size,3,nframe,'uint8');
for m=1:nframe
    interleaf = mod(m-1,ninterleaf) + 1;
    pos = round(dot_position{interleaf} + center);
    
    frame = zeros(frame_size,frame_size,'uint8');
    for n=1:num_dot
        frame(pos(n,1) + (1:scr_dot_size),pos(n,2) + (1:scr_dot_size)) = 255;
    end
    for n=1:3, imdata(:,:,n,m) = frame; end
    
    random_order = randperm(num_dot);
    moving_dots = random_order(1:num_moving_dot);
    random_dots = random_order(num_moving_dot+1:num_dot);
    
    new_position = dot_position{interleaf}(moving_dots,:) + displacement;
    escaping_dots = scr_radius * scr_radius < sum(new_position.^2,2);
    new_position(escaping_dots,:) = dot_position{interleaf}(moving_dots(escaping_dots),:) * symmetry_mat;
    dot_position{interleaf}(moving_dots,:) = new_position;
    
    n = length(random_dots);
    r = (1-rand(n,1).^2) * scr_radius;
    t = rand(n,1) * 360;
    dot_position{interleaf}(random_dots,:) = [r.*cosd(t) r.*sind(t)];
end

catch err
    err
end

info.TimePerFrame = FrameLength;
info.Looping = true;

end
