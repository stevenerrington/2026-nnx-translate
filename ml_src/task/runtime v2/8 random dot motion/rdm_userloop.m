function [C,timingfile,userdefined_trialholder] = rdm_userloop(MLConfig,TrialRecord)

C = {'fix(0,0)'};
timingfile = 'rdm.m';
userdefined_trialholder = '';

[~,taskname] = fileparts(MLConfig.MLPath.ConditionsFile);
switch taskname
    case 'rdm', TrialRecord.User.ApertureShape = 'Circle';
    otherwise,  TrialRecord.User.ApertureShape = 'Rectangle';
end