function [imdata,info] = gen_function(TrialRecord,MLConfig)

% This part should be replaced with your own code for video data generation.
global video_data video_size frame_rate bgra_vector   % must be global
if 1==TrialRecord.CurrentTrialNumber
    v = VideoReader('initializing.avi');
    video_data = read(v,[1 60]);
    video_data(:,:,4,:) = 255;
    video_data = circshift(video_data,[0 0 1 0]);
    video_size = [v.Width v.Height];
    frame_rate = v.FrameRate;

    bgra_vector = flipud(reshape(permute(video_data,[3 2 1 4]),4,[]));
end


% imdata must be an uint8 vector that contains the color information of
% each pixel in order from the first row of one frame to the last row and
% from the first frame to the last frame. The RGB order of each pixel is [B G R A].
%
% For example, three video frames here can be represented as a vector as
% shown below. The vector does not have to be a row vector and can be a
% column vector or matrix, as long as the order of the elements is [B G R A B G R A...].
%
%    Frame 1        Frame 2       Frame 3
% [ P111 P112 ]  [ P211 P212 ] [ P311 P312 ]
% [ P121 P122 ]  [ P221 P222 ] [ P321 P322 ]
%
% imdata = [B111 G111 R111 A111 B112 G112 R112 A112 B121 G121 R121 A121 B122 G122 R122 A122 ...
%           B211 G211 R211 A211 B212 G212 R212 A212 B221 G221 R221 A221 B222 G222 R222 A222 ...
%           B311 G311 R311 A311 B312 G312 R312 A312 B321 G321 R321 A321 B322 G322 R322 A322];

imdata = bgra_vector;            % BGRA uint8 vector
info.DoNotPermute = video_size;  % [width height]

% optional parameters
info.TimePerFrame = 1000 / frame_rate;  % in milliseconds
info.Looping = 1;                       % repeat the movie
