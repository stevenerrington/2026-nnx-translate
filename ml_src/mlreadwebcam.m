function [video,timestamp] = mlreadwebcam(varargin)
%MLREADWEBCAM returns webcam video data from MonkeyLogic data files
%(*.bhv2; *.h5; *.mat).
%
%   video = mlreadwebcam(trial_num);
%   video = mlreadwebcam(trial_num,cam_num);
%   video = mlreadwebcam(trial_num,cam_num,filename);
%   [video,timestamp] = mlreadwebcam(__);
%
%   Mar 23, 2019        Written by Jaewon Hwang (jaewon.hwang@nih.gov)
%   Mar 10, 2020        Replaced by mlreadsignal

if 1<nargin, cam_num = varargin{2}; varargin(2) = []; else, cam_num = 1; end
[video,timestamp] = mlreadsignal(sprintf('webcam%d',cam_num),varargin{:});
