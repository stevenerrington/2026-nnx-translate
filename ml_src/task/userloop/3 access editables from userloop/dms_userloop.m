function [C,timingfile,userdefined_trialholder] = dms_userloop(MLConfig,TrialRecord)

% default return value
C = [];
timingfile = 'dms.m';
userdefined_trialholder = '';

% Editable variables are available only after ML embeds the timing file. If
% this is the very first call to the userloop for retriving the timing
% filename, the embedding is not done yet, so we just return here.
if ~isfield(TrialRecord.Editable,'param_file'), return, end

% Editable variables are accessible via TrialRecord.
[~,n] = fileparts(TrialRecord.Editable.param_file);

% This example gets a function name from an editable variable and calls the
% function to receive preset values.
param = eval(n);
TrialRecord.User.probability = param.probability;
