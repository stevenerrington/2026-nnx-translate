function [C,timingfile,userdefined_trialholder] = LBC_fMRI2_userloop(MLConfig,TrialRecord)

% This is the same task as LBC_fMRI, but just written as a userloop version.
% This version pre-creates all image stimuli and re-uses them so that you
% can save ITI and video memory. These pre-created images are not tracked
% by NIMH MonkeyLogic and therefore not displayed in mlplayer during replay.

C = 'fix(0,0)';
timingfile = 'LBC_fMRI2.m';
userdefined_trialholder = '';

persistent TaskObject RunTime MGL_ID
if isempty(TaskObject)  % this if statement is executed only once

    % process the Taskobject and timing file
    TaskObject = mltaskobject(C,MLConfig,TrialRecord);
    RunTime = get_function_handle(embed_timingfile(MLConfig,timingfile,userdefined_trialholder));

    % process image files
    filenames = {'A.bmp','B.bmp','C.bmp','D.bmp'}';
    MGL_ID = NaN(length(filenames),1);
    for m=1:length(filenames)
        MGL_ID(m) = mgladdbitmap(mglimread(filenames{m}));  % mgladdbitmap returns an MGL object ID that is a double scalar.
    end
    mglsetproperty(MGL_ID,'active',false);  % turn off all images.

    % store the IDs to TrialRecord to access them in the timing script
    TrialRecord.User.ImageFile = filenames;
    TrialRecord.User.ImageID = MGL_ID;

    return  % return if this is the very first call
end

% return the processed TaskObject and timing file
C = TaskObject;
timingfile = RunTime;
