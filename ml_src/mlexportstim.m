function stim_path = mlexportstim(dest_dir,src_file)
%MLEXPORTSTIM extracts saved stimuli from the data file.
%
%   stim_path = mlexportstim;
%   stim_path = mlexportstim(dest_dir, src_file);
%
%   Mar 19, 2018        Written by Jaewon Hwang

stim_path = [];
if ~exist('src_file','var') || 2~=exist(src_file,'file')
    [n,p] = uigetfile({'*.bhv2;*.bhvz;*.h5','MonkeyLogic Datafile (*.bhv2;*.bhvz;*.h5)';'*.mat','MonkeyLogic Datafile (*.mat)'});
    if isnumeric(n), error('Data file not selected!!!'); end
    src_file = [p n];
end

fid = mlfileopen(src_file);
Stimuli = fid.read('Stimuli');
close(fid);
if isempty(Stimuli), return, end

if ~exist('dest_dir','var') || ~exist(dest_dir,'dir')
    dest_dir = uigetdir('','Select a Folder to Export stimuli');
    if isnumeric(dest_dir), error('Destination folder not selected!!!'); end
end
if ~strcmp(dest_dir(end),filesep), dest_dir(end+1) = filesep; end

nstim = length(Stimuli);
stim_path = cell(nstim,1);
for m=1:nstim
    stim_path{m} = [dest_dir Stimuli(m).name];
    fid = fopen(stim_path{m},'w');
    if -1==fid, continue, end
    fwrite(fid,Stimuli(m).contents);
    fclose(fid);
end

end
