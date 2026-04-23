function [C,timingfile,userdefined_trialholder] = task_userloop(MLConfig,TrialRecord)

C = [];
timingfile = {'instructions1.m','drag_trial_3x3_layout.m','instructions2.m'};
userdefined_trialholder = '';

persistent timing_filenames_retrieved
if isempty(timing_filenames_retrieved)
    TrialRecord.User.nextstep = 1;
    TrialRecord.User.max_trial = 3;
    timing_filenames_retrieved = true;
    return
end

C = {'snd(correct.wav)','snd(wrong.wav)'};

switch TrialRecord.User.nextstep
    case 1
        timingfile = 'instructions1.m';
        TrialRecord.User.nextstep = 2;
        TrialRecord.User.trialcount = 0;
    case 2
        timingfile = 'drag_trial_3x3_layout.m';
        TrialRecord.User.trialcount = TrialRecord.User.trialcount + 1;
        if TrialRecord.User.max_trial == TrialRecord.User.trialcount, TrialRecord.User.nextstep = 3; end
    otherwise
        timingfile = 'instructions2.m';
        TrialRecord.Quit = true;
end

end
