function [C,timingfile,userdefined_trialholder] = movie_by_userloop(MLConfig,TrialRecord)

% return values
C = [];
timingfile = 'movie_performance.m';
userdefined_trialholder = '';

% pre-loading movies and the runtime
persistent TaskObject RunTime
if isempty(TaskObject)
    % stimulus list
    stim = {'fix(0,0)', ...
        'mov(''rdm_d0_c20'',0,0)', ...
        'mov(''rdm_d180_c20'',0,0)', ...
        'mov(''rdm_d0_c40'',0,0)', ...
        'mov(''rdm_d180_c40'',0,0)', ...
        'crc(0.5,[1 0 0],1,-5,0)', ...
        'crc(0.5,[1 0 0],1,5,0)'};
    TaskObject = mltaskobject(stim,MLConfig,TrialRecord);
    RunTime = get_function_handle(embed_timingfile(MLConfig,timingfile,userdefined_trialholder));

    % We don't need to run the rest of the function if this is the very
    % first function call. The task is not started yet.
    return
end

condition = mod(TrialRecord.CurrentTrialNumber-1,4) + 1;
switch condition
    case 1, C = TaskObject([1 2 7 6]);
    case 2, C = TaskObject([1 3 6 7]);
    case 3, C = TaskObject([1 4 7 6]);
    case 4, C = TaskObject([1 5 6 7]);
end

% return the pre-generated runtime instead of the timing file name
timingfile = RunTime;
