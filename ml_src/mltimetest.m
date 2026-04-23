function [C,timingfile,userdefined_trialholder] = mltimetest(MLConfig,TrialRecord)

C = {'pic(benchmarkpic.jpg,0,0)','mov(initializing.avi,0,0)'};
timingfile = 'mltimetest_timingfile.m';
userdefined_trialholder = 'DO_NOT_OVERWRITE_EDITABLES';

TrialRecord.TestTrial = true;  % do not create datafile
