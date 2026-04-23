function varargout = mlreadsignal(sigtype,trial_num,filename,varargin)
%MLREADSIGNAL reads signals recorded at unconventional sample rates (i.e.,
%not 1 kHz) from MonkeyLogic data files (*.bhv2; *.h5; *.mat).
%
%   signal = mlreadsignal(signal_type);  % 'high1','voice','cam2', etc.
%   signal = mlreadsignal(signal_type,trial_num);
%   signal = mlreadsignal(signal_type,trial_num,filename);
%   [video,timestamp] = mlreadsignal('webcam1',...);  % 'webcam' + cam#
%
%   Mar 10, 2020         Written by Jaewon Hwang (jaewon.hwang@nih.gov)

if ~exist('sigtype','var'), error('The signal type (e.g., highfrequency1, voice, etc.) cannot be empty.'); end
if ~exist('trial_num','var'), trial_num = 1; warning('Trial number is not assigned. 1 will be used.'); end
if ~exist('filename','var') || 2~=exist(filename,'file')
    [n,p] = uigetfile({'*.bhv2;*.bhvz;*.h5','MonkeyLogic Datafile (*.bhv2;*.bhvz;*.h5)';'*.mat','MonkeyLogic Datafile (*.mat)'});
    if isnumeric(n), error('File not selected'); end
    filename = [p n];
    cd(p);
end

[p,n] = fileparts(filename);
if ~isempty(p), p = [p filesep]; end
fid = mlfileopen(filename);

err = []; signal = []; timestamp = [];
try
    switch lower(sigtype(1:3))
        case {'hig','hfr'}
            sig_no = str2double(regexp(sigtype,'\d+','match'));
            if isnan(sig_no), error('The channel number is not given in the signal type, %s.',sigtype); end
            signal = read(fid,sprintf('HighFrequency%d_%d',sig_no,trial_num));
        case 'voi', signal = read(fid,sprintf('Voice_%d',trial_num));
        case {'web','cam'}
            sig_no = str2double(regexp(sigtype,'\d+','match'));
            if isnan(sig_no), error('The channel number is not given in the signal type, %s.',sigtype); end

            varname = sprintf('Cam%d_%d',sig_no,trial_num);
            data = read(fid,varname);
            if ~isempty(data) && isfield(data,'Time')
                timestamp = data.Time;
                if isfield(data,'Format')
                    signal = decodeframe(data);
                elseif isfield(data,'File')
                    [path,name,ext] = fileparts(data.Filename);
                    if ~isempty(path), path = [path filesep]; end

                    if isempty(data.File)  % external video
                        search_path = {p,path};
                        if ~isempty(varargin), search_path = [varargin{1} search_path]; end
                        if ispref('NIMH_MonkeyLogic','SearchPath'), search_path = [search_path getpref('NIMH_MonkeyLogic','SearchPath')]; end
                        videopath = find_video({[name ext],[n '_' varname ext]},search_path);
                        if isempty(videopath), error('mlreadsignal:filenotfound','%s%s does not exist.',name,ext); end
                        v = VideoReader(videopath);
                        signal = read(v);
                    else
                        videopath = [tempdir name ext];
                        fid2 = fopen(videopath,'w');
                        fwrite(fid2,data.File);
                        fclose(fid2);
                        v = VideoReader(videopath);
                        signal = read(v);
                        delete(videopath);
                    end
                end
            end
        otherwise, error('%s is an unknown signal type!!!',sigtype);
    end
catch err
end

close(fid);

if ~isempty(err), rethrow(err); end

varargout{1} = signal;
if 1<nargout, varargout{2} = timestamp; end

end

function videopath = find_video(namelist,pathlist)
    for p = pathlist
        for n = namelist
            videopath = [p{1} n{1}];
            if 2==exist(videopath,'file'), return, end
        end
    end
    videopath = [];
end
