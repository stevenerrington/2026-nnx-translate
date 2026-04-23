function [imdata,info] = make_grating(TrialRecord,MLConfig)
% This script creates a user-defined TaskObject, GEN. In the conditions
% file, a GEN object can be defined like the following.
%
%   gen(function_name)
%   gen(function_name,x,y)  % x & y in visual angles
%
% A GEN function takes one or two input arguments. The first argument is
% TrialRecord. The second argument is MLConfig, as shown in this function
% above, and it is optional.

% If you need to deliver extra arguments to the GEN function, use the Info
% field of the conditions file. The conditions file of this example is like
% the following.
%
%   Condition   Block   Frequency   Timing File     Info
%   1           1       1           grating         'deg',45
%
% The Info field is read into TrialRecord.CurrentConditionInfo as a struct,
% like TrialRecord.CurrentConditionInfo.deg = 45;
% You can create multiple fields by writing more comma-separated pairs,
% like 'field1',value1,'field2',value2,'field3','string3',etc.
%
% To deliver the same information using the userloop, create a struct
% and pass it to TrialRecord by calling the setCurrentConditionInfo() method.
%
%   a.deg = 45;  % 'a' is an arbitrary name.
%   TrialRecord.SetCurrentConditionInfo(a);

% A GEN function can take one of four return types listed below.
%
%   imdata =  gen_function(___);
%   [imdata,info] = gen_function(___);
%   [imdata,x,y] =  gen_function(___);
%   [imdata,x,y,info] = gen_function(___);
%
% IMDATA is a matrix that contains either PIC or MOV data. A PIC matrix has
% a size of Y-by-X-by-3 and a MOV matrix can be Y-by-X-by-3-by-N. The size
% of the third dimension can be 4, if the data includes the alpha channel.
% In case that the alpha channel is included, the order of the color
% channels is [alpha red green blue]. IMDATA can be also a filename of a
% PIC or MOV.
% X & Y are optional, if they are not given in the conditions file.
% INFO is a structure that you can use to deliver additional information
% about the GEN stimuli. There are three special field names reserved already.
%
%   info.Colorkey: This field indicates a color of the image that should
%                  be treated as transparent. This field is ignored for
%                  movies. Use the alpha channel for making transparent
%                  movies.
%   info.TimePerFrame: This field sets the intervals of the frames (in msec)
%                      if the given stimulus is a movie. This field is
%                      ignored in case that the movie is read from a file.
%   info.Looping: This field makes the movie repeated when the end is reached.

PixelsPerDegree = MLConfig.Screen.PixelsPerDegree;
RefreshRate = MLConfig.Screen.RefreshRate;
FrameLength = MLConfig.Screen.FrameLength;

if isfield(TrialRecord.CurrentConditionInfo,'deg')
    Orientation = TrialRecord.CurrentConditionInfo.deg;
else
    Orientation = 45;      % deg
end
ApertureRadius = 1;        % deg
SpatialFrequency = 1;      % cycles per deg
TemporalFrequency = 2;     % cycles per sec
Time = 0:1/RefreshRate:1;  % sec
Time = Time(1:end-1);

x = (-ApertureRadius*PixelsPerDegree:ApertureRadius*PixelsPerDegree) / PixelsPerDegree;
y = x;
cx = mean(x);
cy = cx;
[x,y] = meshgrid(x,y);

% This example creates the alpha channel separately and combines it with
% the RGB data later, but you can also read the alpha channel data from the
% PNG files with mglimread.
%
%   imdata = mglimread(png_filename);  % mglimread returns 4-ch data, Y-by-X-by-4, if the format is PNG.
%                                      % Otherwise, it returns 3-ch data, Y-by-X-by-3.
imdata = zeros([size(x) 4 length(Time)]);  % Y-by-X-by-4-by-N
alpha = sqrt((x-cx).^2 + (y-cy).^2) < ApertureRadius;
for m=1:length(Time)
    grating = (sine_grating(x,y,Orientation,SpatialFrequency,TemporalFrequency,Time(m)) + 1) / 2;  % [-1 1] to [0 1]
    imdata(:,:,:,m) = cat(3,alpha,grating,grating,grating);  % [a r g b]
end

info.TimePerFrame = FrameLength;  % Inform that the frame interval of this movie is 16.667 msec.
info.Looping = true;              % Make the movie repeat when the last frame is reached.

end

function z = sine_grating(x,y,orientation,cycles_per_deg,cycles_per_sec,t)

z = sind(360*(cycles_per_deg*(x*cosd(orientation) + y*sind(orientation)) - cycles_per_sec*t));

end
