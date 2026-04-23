function mlimportwebcam(datafile,cam_dir)

if ~exist('datafile','var') || 2~=exist(datafile,'file')
    [n,p] = uigetfile({'*.bhv2;*.bhvz;*.h5','MonkeyLogic Datafile (*.bhv2;*.bhvz;*.h5)';'*.mat','MonkeyLogic Datafile (*.mat)'},'Select files','MultiSelect','on');
    cd(p);
    datafile = [p n];
end
if ischar(datafile), datafile = {datafile}; end
nfile = length(datafile);
if ~exist('cam_dir','var'), cam_dir = {}; end
if ischar(cam_dir), cam_dir = {cam_dir}; end
ndir = length(cam_dir);

for m=1:nfile
    src = datafile{m};
    [p,n,e] = fileparts(src);
    if ~isempty(p), p = [p filesep]; end
    combined = [p 'combined' filesep];
    if ~exist(combined,'dir'), mkdir(combined); end
    dest = [combined n e];
    fin = mlfileopen(src);
    fout = mlfileopen(dest,'w');
    varname = mlsetdiff(who(fin),{'IndexPosition','FileInfo','FileIndex'});
    is_cam = strncmp(varname,'Cam',3);
    no_cam = ~any(is_cam);

    err = [];
    try
        for l = 1:length(varname)
            data = fin.read(varname{l});
            if isempty(cam_dir)
                videopath = p;
            else
                if ndir < l, videopath = cam_dir{end}; else, videopath = cam_dir{l}; end
                if ~strcmp(videopath(end),filesep), videopath = [videopath filesep]; end
            end
            
            if no_cam
                a = regexp(varname{l},'^Trial(\d+)$','tokens');
                if isempty(a)  % non-Trial variables
                    fout.write(data,varname{l});
                else           % Trial variables
                    trial_no = str2double(a{1}{1});
                    videoinfo = {};
                    for c = 1:4
                        cam_no = sprintf('Webcam%d',c);
                        if isfield(data.AnalogData,cam_no)
                            videoinfo{c} = struct('Filename',data.AnalogData.(cam_no).Filename,'File',[],'Time',data.AnalogData.(cam_no).Time); %#ok<*AGROW>
                            data.AnalogData = rmfield(data.AnalogData,cam_no);
                        end
                    end
                    fout.write(data,varname{l});
                    for c = 1:length(videoinfo)
                        [~,name,ext] = fileparts(videoinfo{c}.Filename);
                        videofile = [videopath name ext];
                        fid = fopen(videofile,'r');
                        videoinfo{c}.File = fread(fid,Inf,'*uint8');
                        fclose(fid);
                        fout.write(videoinfo{c},sprintf('Cam%d_%d',c,trial_no),false);
                    end
                end
            elseif is_cam(l)
                [~,name,ext] = fileparts(data.Filename);
                videofile = [videopath name ext];
                fid = fopen(videofile,'r');
                data.File = fread(fid,Inf,'*uint8');
                fclose(fid);
                fout.write(data,varname{l},false);
            else
                fout.write(data,varname{l});
            end
        end
    catch err
    end
    
    fin.close();
    fout.close();
    if ~isempty(err), rethrow(err); end
end
