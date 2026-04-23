function [C,timingfile,userdefined_trialholder] = gen_video_userloop(MLConfig,TrialRecord)

C = [];
timingfile = 'gen_video.m';
userdefined_trialholder = '';

persistent timing_filenames_retrieved
if isempty(timing_filenames_retrieved)
    timing_filenames_retrieved = true;
    return
end

% gen_function here returns video data as a BGRA vector. Since a BGRA
% vector does not need permuting to be converted to a movie, the stimulus
% creation time becomes shorter.
% For the format of the BGRA vector, see gen_function.

C = 'gen(gen_function,0,0)';

end
