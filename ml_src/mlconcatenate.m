function [val,MLConfig,TrialRecord,filename] = mlconcatenate(filename)
%MLCONCATENATE combines and returns trial data as if it is continuously
%recorded in one trial.
%
%   [data,MLConfig,TrialRecord] = mlconcatenate(filename)
%   [data,MLConfig,TrialRecord,filename] = mlconcatenate
%
%   Jan 4, 2018         Written by Jaewon Hwang (jaewon.hwang@nih.gov, jaewon.hwang@hotmail.com)
%   Apr 22, 2021        Fixed an error in concatenating touch data

TrialRecord = [];

if ~exist('filename','var') || 2~=exist(filename,'file')
    [n,p] = uigetfile({'*.bhv2;*.bhvz;*.h5','MonkeyLogic Datafile (*.bhv2;*.bhvz;*.h5)';'*.mat','MonkeyLogic Datafile (*.mat)'});
    if isnumeric(n), error('File not selected'); end
    filename = [p n];
end
try
    fid = mlfileopen(filename);
    MLConfig = fid.read('MLConfig');
    data = fid.read_trial();
    if 2<nargout, TrialRecord = fid.read('TrialRecord'); end
    close(fid);
catch err
    close(fid);
    rethrow(err);
end

if 1000~=MLConfig.AISampleRate, error('AISampleRate must be 1000 Hz!!!'); end
if isfield(MLConfig,'NonStopRecording'), NonStopRecording = MLConfig.NonStopRecording; else, NonStopRecording = false; end
ntrial = length(data);

skip_uservars = false;
for field={'Trial','BlockCount','TrialWithinBlock','Block','Condition','TrialError','ReactionTime','AbsoluteTrialStartTime','TrialDateTime', ...
    'BehavioralCodes','ObjectStatusRecord','RewardRecord','UserVars','VariableChanges','TaskObject','CycleRate','Ver'}
    f = field{1}; if ~isfield(data,f), continue, end
    try
        val.(f) = vertcat(data.(f));
    catch err
        if strcmp(f,'UserVars'), skip_uservars = true; end
        warning(err.identifier,'%s',err.message);
    end
end
for m=ntrial:-1:1
    val.BehavioralCodes(m).CodeTimes = val.BehavioralCodes(m).CodeTimes + val.AbsoluteTrialStartTime(m);
    if isfield(val.ObjectStatusRecord(m),'Time')
        val.ObjectStatusRecord(m).Time = val.ObjectStatusRecord(m).Time + val.AbsoluteTrialStartTime(m);
    else
        for n=1:length(val.ObjectStatusRecord(m).SceneParam)
            val.ObjectStatusRecord(m).SceneParam(n).Time = val.ObjectStatusRecord(m).SceneParam(n).Time + val.AbsoluteTrialStartTime(m);
        end
    end
    val.RewardRecord(m).StartTimes = val.RewardRecord(m).StartTimes + val.AbsoluteTrialStartTime(m);
    val.RewardRecord(m).EndTimes = val.RewardRecord(m).EndTimes + val.AbsoluteTrialStartTime(m);
    if ~skip_uservars && ~isempty(val.UserVars(m).SkippedFrameTimeInfo)
        val.UserVars(m).SkippedFrameTimeInfo(:,1:2) = val.UserVars(m).SkippedFrameTimeInfo(:,1:2) + val.AbsoluteTrialStartTime(m);
    end
end

AnalogData = [data.AnalogData];
val.AnalogData.SampleInterval = vertcat(AnalogData.SampleInterval);

for field={'Eye','Eye2','EyeExtra','Joystick','Joystick2','Touch','Mouse','KeyInput','PhotoDiode'}
    f = field{1}; if ~isfield(AnalogData(1),f), continue, end
    if isempty(AnalogData(1).(f)), val.AnalogData.(f) = []; continue, end

    nsample = round(data(ntrial).AbsoluteTrialStartTime) + size(AnalogData(end).(f),1);
    val.AnalogData.(f) = NaN(nsample,size(AnalogData(1).(f),2));

    t2 = 1;
    for m=1:ntrial
        t1 = round(val.AbsoluteTrialStartTime(m)) + 1;
        if NonStopRecording && 1<t1-t2, val.AnalogData.(f)(t2+1:t1-1,:) = repmat(val.AnalogData.(f)(t2,:),t1-t2-1,1); end
        t2 = t1 + size(AnalogData(m).(f),1) - 1;
        val.AnalogData.(f)(t1:t2,:) = AnalogData(m).(f);
    end
end

for field={'General','Button'}
    f = field{1}; if ~isfield(AnalogData(1),f), continue, end
    for chan=fieldnames(AnalogData(1).(f))'
        c = chan{1}; if isempty(AnalogData(1).(f).(c)), val.AnalogData.(f).(c) = []; continue, end
        
        nsample = round(data(ntrial).AbsoluteTrialStartTime) + size(AnalogData(end).(f).(c),1);
        val.AnalogData.(f).(c) = NaN(nsample,size(AnalogData(1).(f).(c),2));
        
        t2 = 1;
        for m=1:ntrial
            t1 = round(val.AbsoluteTrialStartTime(m)) + 1;
            if NonStopRecording && 1<t1-t2, val.AnalogData.(f).(c)(t2+1:t1-1,:) = repmat(val.AnalogData.(f).(c)(t2,:),t1-t2-1,1); end
            t2 = t1 + size(AnalogData(m).(f).(c),1) - 1;
            val.AnalogData.(f).(c)(t1:t2,:) = AnalogData(m).(f).(c);
        end
    end
end

for field={'LSL'}
    f = field{1}; if ~isfield(AnalogData(1),f), continue, end
    a = [AnalogData.(f)];
    for chan=fieldnames(a)'
        c = chan{1};
        for m=1:ntrial
            if isempty(a(m).(c)), continue, end
            a(m).(c)(:,1) = a(m).(c)(:,1) + val.AbsoluteTrialStartTime(m);
        end
    end
    for chan=fieldnames(a)'
        c = chan{1}; val.AnalogData.(f).(c) = vertcat(a.(c));
    end
end
