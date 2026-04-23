function mlexportwebcam(datafile,delete_video)

if ~exist('datafile','var') || 2~=exist(datafile,'file')
    [n,p] = uigetfile({'*.bhv2;*.bhvz;*.h5','MonkeyLogic Datafile (*.bhv2;*.bhvz;*.h5)';'*.mat','MonkeyLogic Datafile (*.mat)'},'Select files','MultiSelect','on');
    cd(p);
    datafile = [p n];
end
if ~exist('delete_video','var'), delete_video = false; end

if ischar(datafile), datafile = {datafile}; end
nfile = length(datafile);

for m=1:nfile
    src = datafile{m};
    [p,n,e] = fileparts(src);
    if ~isempty(p), p = [p filesep]; end %#ok<AGROW>
    dest = [p n '_nocam' e];
    fin = mlfileopen(src);
    if delete_video, fout = mlfileopen(dest,'w'); end
    varname = mlsetdiff(who(fin),{'IndexPosition','FileInfo','FileIndex'});
    is_cam = strncmp(varname,'Cam',3);

    err = [];
    try
        for l = 1:length(varname)
            data = fin.read(varname{l});
            if is_cam(l)
                if isfield(data,'Format')
                    videofile = [p n '_' varname{l} '.mp4'];
                    frame_rate = round(1000/median(diff(data.Time)));
                    if isnan(frame_rate), frame_rate = 30; end
                    frame = decodeframe(data);
                    v = VideoWriter(videofile,'MPEG-4'); %#ok<TNMLP>
                    set(v,'FrameRate',frame_rate);
                    open(v);
                    try
                        for f=1:size(frame,4), writeVideo(v,frame(:,:,:,f)); end
                    catch
                    end
                    close(v);
                    data = struct('Filename',videofile,'File',[],'Time',data.Time);
                elseif isfield(data,'File')
                    if ~isempty(data.File)
                        [~,name,ext] = fileparts(data.Filename);
                        videopath = [p name ext];
                        fid = fopen(videopath,'w');
                        fwrite(fid,data.File);
                        fclose(fid);
                        data.File = [];
                    end
                end
            end
            if delete_video, fout.write(data,varname{l}); end
        end
    catch err
    end
    
    fin.close();
    if delete_video
        fout.close();
        orig = [p 'orig'];
        if ~exist(orig,'dir'), mkdir(orig); end
        movefile(src,orig);
        movefile(dest,src);
    end
    if ~isempty(err), rethrow(err); end
end
