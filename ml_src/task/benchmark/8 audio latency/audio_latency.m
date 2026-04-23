function audio_latency()
% This script requires NIMH MonkeyLogic (https://monkeylogic.nimh.nih.gov)
% to be installed and added to the MATLAB path.
%
% At least one NI board is necessary.
%
% For AI configuration of NI boards, refer to the following document.
% https://monkeylogic.nimh.nih.gov/docs_NIMultifunctionIODevice.html#AIGroundConfiguration
%
%   Nov 1, 2022     written by Jaewon Hwang (jaewon.hwang@nih.gov)

% add NIMH daqtoolbox to the path
MLPATH = fileparts(which('monkeylogic'));
if ~isempty(MLPATH)
    p = [MLPATH filesep 'daqtoolbox'];
    if exist(p,'dir'), addpath(p); end
end
DAQPATH = fileparts(which('daqreset'));
if isempty(DAQPATH)
    error(['NIMH daqtoolbox is not found. Please install NIMH MonkeyLogic from <a href="https://monkeylogic.nimh.nih.gov">' ...
        'https://monkeylogic.nimh.nih.gov</a> and add it to the MATLAB path.']);
end

% add the SND toolbox to the path
SNDPATH = fileparts(which('sndmex'));
if isempty(SNDPATH)
    p = mfilename('fullpath');
    p = [p(1:find(p==filesep,1,'last')) 'sndtool'];
    if exist(p,'dir')
        addpath(p);
    else
        MGLPATH = [MLPATH filesep 'mgl'];
        if exist(MGLPATH,'dir'), addpath(MGLPATH); end
    end
end
SNDPATH = fileparts(which('mglreset'));
if isempty(SNDPATH), error('The SND toolbox is not found. Please add its directory to the MATLAB path.'); end

% global variables
measurement_type_list = {'Playback latency','playback';'Recording latency','recording'};
playback_api_list = {'NIDAQmx',0,'NIDAQ';'XAudio2',1,'XAudio2';'WASAPI Shared AC3',2,'Shared3';'WASAPI Exclusive',3,'Exclusive';'WASAPI Shared AC1',4,'Shared1'};
recording_api_list = {'NIDAQmx',0,'NIDAQ';'WASAPI Shared',2,'Shared';'WASAPI Exclusive',3,'Exclusive'};
measurement_type = [];
playback_api = [];
recording_api = [];
ni_info = [];
snd_info = [];

% figure variables
api_list = [];
dev_list = [];
fmt_list = [];
ni_list = [];
fontsize = 10;
callback = @UIcallback;
hTag = [];

% load config
config_filename = [tempdir 'audio_latency_cfg.mat'];
if exist(config_filename,'file')
    try load(config_filename,'config'); catch, end
end
if ~exist('config','var')
    config = struct('NumTrial',1005,'MeasurementType','Playback latency','API','NIDAQmx', ...
        'Device','SoundCard','DeviceFormat',1,'DeviceAOChan',0,'DeviceAIConfig','SingleEnded','DeviceAIChan',0, ...
        'NIBoard','NIBoard','NIBoardAOChan',0,'NIBoardAIConfig','SingleEnded','NIBoardAIChan',0);
end
config.info.fs = 48000;

init_device();
init_UI();

    function measure_latency()
        save(config_filename,'config');

        ntrial = config.NumTrial;
        type = getidx(measurement_type(:,1),config.MeasurementType);
        api_idx = getidx(api_list(:,1),config.API);
        api = api_list{api_idx,2};
        dev_idx = getidx(dev_list(:,1),config.Device);
        format = fmt_list{config.DeviceFormat};
        driver = dev_list{dev_idx,4};
        ni_idx = getidx(ni_list(:,1),config.NIBoard);

        if 1==type
            if 0==api
                idx = dev_list{dev_idx,2};
                player = eval(ni_info.ObjectConstructorName{idx,2});
                addchannel(player,config.DeviceAOChan);
                player.TriggerType = 'Manual';
                player.SampleRate = config.info.fs;
            else
                player = [];
                mglaudioengine(api,dev_idx,config.DeviceFormat);
            end

            idx = ni_list{ni_idx,2};
            recorder = eval(ni_info.ObjectConstructorName{idx,1});
            recorder.InputType = config.NIBoardAIConfig;
            addchannel(recorder,config.NIBoardAIChan);
            recorder.SamplesPerTrigger = Inf;
            recorder.SampleRate = config.info.fs;
        else
            if 0==api
                idx = dev_list{dev_idx,2};
                recorder = eval(ni_info.ObjectConstructorName{idx,1});
                recorder.InputType = config.DeviceAIConfig;
            else
                idx = dev_list{dev_idx,2};
                recorder = eval(snd_info.ObjectConstructorName{idx,1});
                recorder.setProperty('Format',fi(2==api,length(snd_info.SupportedFormat{idx}),config.DeviceFormat));
            end
            addchannel(recorder,config.DeviceAIChan);
            recorder.SamplesPerTrigger = Inf;
            recorder.SampleRate = config.info.fs;

            idx = ni_list{ni_idx,2};
            player = eval(ni_info.ObjectConstructorName{idx,2});
            addchannel(player,config.NIBoardAOChan);
            player.TriggerType = 'Manual';
            player.SampleRate = config.info.fs;
        end

        filename = [ measurement_type{type,2} ...
            '_' api_list{api_idx,3} ...
            '_' dev_list{dev_idx,5} ...
            '_' config.info.OS];
        [filename,filepath] = uiputfile('*.mat','',filename);
        if 0==filename, return, end

        y = sin(2*pi*1000*(0:1/config.info.fs:0.1))';  % 1-kHz sine waves of 0.1 s
        win = [0.0439 0.2494 0.7066 1.0000 0.7066 0.2494 0.0439];
        win = win / sum(win);
        signal = cell(ntrial,1);
        time = zeros(ntrial,5);

        err = [];
        mglkeepsystemawake(true);
        try
            wb = waitbar(0,'Processing...','Name',filename);
            for m=1:ntrial
                waitbar(m/ntrial,wb,sprintf('Processing...(%d/%d)',m,ntrial));

                timer = tic;
                start(recorder);

                if ~isempty(player) && isa(player,'analogoutput')
                    putdata(player,y);
                    start(player);
                    tic; while toc<0.1, end

                    nsample = recorder.SamplesAvailable;
                    while nsample==recorder.SamplesAvailable, end  % wait for a new sample transfer cycle

                    t1 = toc(timer);
                    flushmarker(recorder);  % mark the current sample position
                    t2 = toc(timer);
                    trigger(player);        % play command
                    t3 = toc(timer);
                    tic; while toc<0.3, end

                    stop(player);
                else
                    id = mgladdsound(y,config.info.fs);
                    tic; while toc<0.1, end

                    nsample = recorder.SamplesAvailable;
                    while nsample==recorder.SamplesAvailable, end  % wait for a new sample transfer cycle

                    t1 = toc(timer);
                    flushmarker(recorder);  % mark the current sample position 
                    t2 = toc(timer);
                    mglplaysound(id);       % play command
                    t3 = toc(timer);
                    tic; while toc<0.3, end

                    mgldestroysound(id);
                end

                flushdata(recorder);    % discard the samples acquired before the marked position
                stop(recorder);
                data = getdata(recorder);

                data(:,1) = data(:,1) - data(1,1);
                if find(data<0.5*min(data),1)<find(0.5*max(data)<data,1), data = data * -1; end

                if 1==m
                    hfig = figure;
                    x = (1:length(data)) * 1000 / config.info.fs;
                    plot(x,data);
                    set(gca,'XLim',[0 150]);
                    set(gcf,'Name',filename);
                end

                signal{m} = data;
                time(m,1:2) = [t2-t1 t3-t2] * 1000;
            end
            close(wb);
        catch err
        end
        mglkeepsystemawake(false);

        err2 = [];
        try
            for m=1:length(signal)
                data = signal{m};
                if isempty(data), break, end

                data(:,1) = conv(data(:,1),win,'same');
                dv1 = [0; diff(data(:,1))];
                dv2 = [0; diff(dv1)];

                ub = 0.05 * max(data(:,1));
                peak = find(1==diff(ub<dv1));

                peak_interval = diff(peak);
                cr = 1.5 * median(peak_interval);
                while cr < peak_interval(1), peak(1) = []; peak_interval(1) = []; end
                while cr < peak_interval(end), peak(end) = []; peak_interval(end) = []; end

                first = find(signal{m}(1:peak(1),1)<ub,1,'last');
                last = peak(end)+find(dv2(peak(end):end)<=0,1);
                duration = last-first-1;

                peak(last<=peak) = [];
                peak(end) = [];
                peakcount = length(peak);
                time(m,3:4) = [first duration] * 1000 / config.info.fs;
                time(m,5) = peakcount;
            end
        catch err2
        end

        assignin('base','signal',signal);
        assignin('base','time',time);
        assignin('base','driver',driver);
        assignin('base','format',format);
        assignin('base','config',config);
        if ~isempty(err), fprintf(2,'%s\n',err.message); rethrow(err); end
        if ~isempty(err2), fprintf(2,'%s\n',err2.message); rethrow(err2); end

        save([filepath filename],'signal','time','driver','format','config');

        try
            if exist('hfig','var') && ishandle(hfig), close(hfig); end
            audio_latency_viewer(signal,time,config,filename);
        catch
        end
    end

    function update_UI()
        config.NumTrial = max(1,config.NumTrial);
        [config.MeasurementType,type] = getval(measurement_type(:,1),config.MeasurementType);

        api_list = fi(1==type,playback_api,recording_api);
        [config.API,idx] = getval(api_list(:,1),config.API);
        api = api_list{idx,2};

        if 1==type
            if 0==api, dev_list = ni_info.ao; else, dev_list = snd_info.ao.(api_list{idx,3}); end
            [config.Device,idx] = getval(dev_list(:,1),config.Device);
            aochan = dev_list{idx,3};
            config.DeviceAOChan = getval(aochan,config.DeviceAOChan);
            fmt_list = dev_list{idx,6};
            config.DeviceFormat = min(length(fmt_list),config.DeviceFormat);
            driver = dev_list{idx,4};
            ni_list = ni_info.ai;
            [config.NIBoard,idx] = getval(ni_list(:,1),config.NIBoard);
            nichan = ni_list{idx,3};
            niboardaiconfig = ni_list{idx,7};
            config.NIBoardAIConfig = getval(niboardaiconfig,config.NIBoardAIConfig);
            aichan = fi(strcmp('Differential',config.NIBoardAIConfig),nichan{1},nichan{2});
            config.NIBoardAIChan = getval(aichan,config.NIBoardAIChan);
        else
            if 0==api, dev_list = ni_info.ai; else, dev_list = snd_info.ai; end
            [config.Device,idx] = getval(dev_list(:,1),config.Device);
            if 0==api
                nichan = dev_list{idx,3};
                deviceaiconfig = dev_list{idx,7};
                config.DeviceAIConfig = getval(deviceaiconfig,config.DeviceAIConfig);
                aichan = fi(strcmp('Differential',config.DeviceAIConfig),nichan{1},nichan{2});
            else
                aichan = dev_list{idx,3}{2};
            end
            config.DeviceAIChan = getval(aichan,config.DeviceAIChan);
            fmt_list = dev_list{idx,6};
            if 2==api, fmt_list = fmt_list(end); elseif 3==api, fmt_list = fmt_list(1:end-1); end
            config.DeviceFormat = min(length(fmt_list),config.DeviceFormat);
            driver = dev_list{idx,4};
            ni_list = ni_info.ao;
            [config.NIBoard,idx] = getval(ni_list(:,1),config.NIBoard);
            aochan = ni_list{idx,3};
            config.NIBoardAOChan = getval(aochan,config.NIBoardAOChan);
        end

        set(hTag.NumTrial,'string',config.NumTrial);
        setval(hTag.MeasurementType,measurement_type(:,1),config.MeasurementType);
        setval(hTag.API,api_list(:,1),config.API);
        pos = get(hTag.Device(2),'position'); pos(3) = fi(0==api,200,300); set(hTag.Device(2),'position',pos);
        set(hTag.Device(1),'string',fi(1==type,'Player','Recorder'));
        setval(hTag.Device(2),dev_list(:,1),config.Device);
        set(hTag.DeviceFormat(2),'string',fmt_list,'value',config.DeviceFormat);
        set(hTag.Driver(2),'string',driver);
        set(hTag.NIBoard(1),'string',fi(1==type,'Recorder (NI board)','Player (NI board)'));
        setval(hTag.NIBoard(2),ni_list(:,1),config.NIBoard);
        if 1==type
            setval(hTag.DeviceAOChan(2),aochan,config.DeviceAOChan);
            setval(hTag.NIBoardAIConfig(2),niboardaiconfig,config.NIBoardAIConfig);
            setval(hTag.NIBoardAIChan(2),aichan,config.NIBoardAIChan);
            set(hTag.DeviceFormat,'visible','on');
            set(hTag.DeviceAOChan,'visible',fi(0==api,'on','off'));
            set([hTag.DeviceAIConfig hTag.DeviceAIChan],'visible','off');
        else
            if 0==api
                setval(hTag.DeviceAIConfig(2),deviceaiconfig,config.DeviceAIConfig);
                setval(hTag.DeviceAIChan(2),aichan,config.DeviceAIChan);
            else
                config.DeviceAIChan = aichan(1);
            end
            setval(hTag.NIBoardAOChan(2),aochan,config.NIBoardAOChan);
            set(hTag.DeviceFormat,'visible',fi(0==api,'off','on'));
            set(hTag.DeviceAOChan,'visible','off');
            set([hTag.DeviceAIConfig hTag.DeviceAIChan],'visible',fi(0==api,'on','off'));
        end
        set([hTag.NIBoardAIConfig hTag.NIBoardAIChan],'visible',fi(1==type,'on','off'));
        set(hTag.NIBoardAOChan,'visible',fi(1==type,'off','on'));
        if 1==type
            player = [config.Device fi(0==api,sprintf(' AO %d',config.DeviceAOChan),'')];
            recorder = [config.NIBoard sprintf(' AI %d',config.NIBoardAIChan)];
        else
            player = [config.NIBoard sprintf(' AO %d',config.NIBoardAOChan)];
            recorder = [config.Device sprintf(fi(0==api,' AI %d',' Ch %d'),config.DeviceAIChan)];
        end
        wiring = { sprintf('%s -> %s',player,recorder) };
        set(hTag.WiringInfo,'string',wiring);
    end

    function UIcallback(hObject,~)
        obj_tag = get(hObject,'tag');
        switch obj_tag
            case 'NumTrial', config.(obj_tag) = str2double(get(gcbo,'string'));
            case {'MeasurementType','API','Device','DeviceAIConfig','NIBoard','NIBoardAIConfig'}
                str = get(gcbo,'string'); val = get(gcbo,'value'); config.(obj_tag) = str{val};
            case 'DeviceFormat', config.(obj_tag) = get(gcbo,'value');
            case {'DeviceAOChan','DeviceAIChan','NIBoardAOChan','NIBoardAIChan'}
                str = get(gcbo,'string'); val = get(gcbo,'value'); config.(obj_tag) = str2double(str(val,:));
            case 'Refresh', set(gcbo,'enable','off'); drawnow; init_device(); set(gcbo,'enable','on');
            case 'Start', timer = tic; measure_latency(); toc(timer)
        end
        update_UI();
    end

    function init_UI()
        fw = 550; fh = 430;
        lx = 155;

        hTag.hFig = figure;
        pos = get(hTag.hFig,'position');
        pos = [pos(1:2) fw fh];
        set(hTag.hFig,'tag','latency_test','units','pixels','position',pos,'numbertitle','off','name','Audio Latency Test','menubar','none','resize','off');

        x0 = 20; y0 = fh-60;
        uicontrol('style','text','position',[x0 y0 lx 21],'string','# of Trials','fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.NumTrial = uicontrol('style','edit','position',[x0+lx y0 50 23],'tag','NumTrial','string',config.NumTrial,'fontsize',fontsize,'callback',callback);
        uicontrol('style','pushbutton','position',[x0+fw-200 y0+20 160 30],'tag','Refresh','string','Refresh Device List','fontsize',fontsize,'fontweight','bold','callback',callback);
        uicontrol('style','pushbutton','position',[x0+fw-200 y0-15 160 30],'string','Open Device Manager','fontsize',fontsize,'fontweight','bold','callback','system(''devmgmt.msc'');');
        uicontrol('style','pushbutton','position',[x0+fw-200 y0-50 160 30],'string','Open Sound Control','fontsize',fontsize,'fontweight','bold','callback','system(''mmsys.cpl'');');

        y0 = y0-30;
        uicontrol('style','text','position',[x0 y0 lx 21],'string','Measurement Type','fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.MeasurementType = uicontrol('style','popupmenu','position',[x0+lx y0 140 23],'tag','MeasurementType','string',measurement_type(:,1),'fontsize',fontsize,'callback',callback);

        y0 = y0-30;
        uicontrol('style','text','position',[x0 y0 lx 21],'string','Programming Interface','fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.API = uicontrol('style','popupmenu','position',[x0+lx y0 160 23],'tag','API','string',{'API1'},'fontsize',fontsize,'callback',callback);

        y0 = y0-30;
        hTag.Device(1) = uicontrol('style','text','position',[x0 y0 lx 21],'string','Playback Device','fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.Device(2) = uicontrol('style','popupmenu','position',[x0+lx y0 200 23],'tag','Device','string',{'Device1'},'fontsize',fontsize,'callback',callback);
        hTag.DeviceAOChan(1) = uicontrol('style','text','position',[x0+lx+210 y0 lx 21],'string','AO Chan','fontsize',fontsize,'horizontalalignment','left');
        hTag.DeviceAOChan(2) = uicontrol('style','popupmenu','position',[x0+lx+270 y0 40 23],'tag','DeviceAOChan','string',0,'fontsize',fontsize,'callback',callback);

        y0 = y0-30;
        hTag.DeviceFormat(1) = uicontrol('style','text','position',[x0+40 y0 lx 21],'string','Sound Format','fontsize',fontsize,'horizontalalignment','left');
        hTag.DeviceFormat(2) = uicontrol('style','popupmenu','position',[x0+lx y0 200 23],'tag','DeviceFormat','string',{'Format1'},'fontsize',fontsize,'callback',callback);
        hTag.DeviceAIConfig(1) = uicontrol('style','text','position',[x0+40 y0 lx 21],'string','AI Configuration','fontsize',fontsize,'horizontalalignment','left');
        hTag.DeviceAIConfig(2) = uicontrol('style','popupmenu','position',[x0+lx y0 200 23],'tag','DeviceAIConfig','string','Differential','fontsize',fontsize,'callback',callback);
        hTag.DeviceAIChan(1) = uicontrol('style','text','position',[x0+lx+210 y0 lx 21],'string','AI Chan','fontsize',fontsize,'horizontalalignment','left');
        hTag.DeviceAIChan(2) = uicontrol('style','popupmenu','position',[x0+lx+270 y0 40 23],'tag','DeviceAIChan','string',0,'fontsize',fontsize,'callback',callback);

        y0 = y0-30;
        hTag.Driver(1) = uicontrol('style','text','position',[x0+40 y0 lx 21],'string','Driver','foregroundcolor',[0 0 1],'fontsize',fontsize,'horizontalalignment','left');
        hTag.Driver(3) = uicontrol('style','text','position',[x0+40 y0-20 lx 21],'string','(click here for update','enable','inactive','foregroundcolor',[0 0 1],'fontsize',8,'horizontalalignment','left','ButtonDownFcn','web(''https://monkeylogic.nimh.nih.gov/docs_AudioEngine.html#UpdateDriver'',''-browser'')');
        hTag.Driver(4) = uicontrol('style','text','position',[x0+40 y0-33 lx 21],'string',' instructions)','enable','inactive','foregroundcolor',[0 0 1],'fontsize',8,'horizontalalignment','left','ButtonDownFcn','web(''https://monkeylogic.nimh.nih.gov/docs_AudioEngine.html#UpdateDriver'',''-browser'')');
        y0 = y0-20;
        hTag.Driver(2) = uicontrol('style','edit','position',[x0+lx y0 350 40],'tag','Driver','min',1,'max',3,'enable','inactive','foregroundcolor',[0 0 1],'fontsize',fontsize,'horizontalalignment','left','callback',callback);

        y0 = y0-40;
        hTag.NIBoard(1) = uicontrol('style','text','position',[x0 y0 lx 21],'string','NI Board','fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.NIBoard(2) = uicontrol('style','popupmenu','position',[x0+lx y0 200 23],'tag','NIBoard','string',{'NIBoard1'},'fontsize',fontsize,'callback',callback);
        hTag.NIBoardAOChan(1) = uicontrol('style','text','position',[x0+lx+210 y0 lx 21],'string','AO Chan','fontsize',fontsize,'horizontalalignment','left');
        hTag.NIBoardAOChan(2) = uicontrol('style','popupmenu','position',[x0+lx+270 y0 40 23],'tag','NIBoardAOChan','string',0,'fontsize',fontsize,'callback',callback);

        y0 = y0-30;
        hTag.NIBoardAIConfig(1) = uicontrol('style','text','position',[x0+40 y0 lx 21],'string','AI Configuration','fontsize',fontsize,'horizontalalignment','left');
        hTag.NIBoardAIConfig(2) = uicontrol('style','popupmenu','position',[x0+lx y0 200 23],'tag','NIBoardAIConfig','string','Differential','fontsize',fontsize,'callback',callback);
        hTag.NIBoardAIChan(1) = uicontrol('style','text','position',[x0+lx+210 y0 lx 21],'string','AI Chan','fontsize',fontsize,'horizontalalignment','left');
        hTag.NIBoardAIChan(2) = uicontrol('style','popupmenu','position',[x0+lx+270 y0 40 23],'tag','NIBoardAIChan','string',0,'fontsize',fontsize,'callback',callback);

        y0 = y0-40;
        uicontrol('style','text','position',[x0 y0 lx 21],'string','Wiring Information','foregroundcolor',[0 0 1],'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        y0 = y0-20;
        hTag.WiringInfo = uicontrol('style','edit','position',[x0+lx y0 350 40],'tag','WiringInfo','min',1,'max',3,'enable','inactive','foregroundcolor',[0 0 1],'fontsize',fontsize,'horizontalalignment','left','callback',callback);

        uicontrol('style','pushbutton','position',[x0+fw-200 20 160 30],'tag','Start','string','Start Measurement','fontsize',fontsize,'fontweight','bold','callback',callback);

        update_UI();
    end

    function init_device()
        % get system info
        [~,v] = system('ver');
        config.info.winver = cellfun(@str2num,regexp(strtrim(v),'(\d+)','match'));
        if config.info.winver(1)<10, error('Windows 10 or later is required.'); end
        if config.info.winver(3)<22000, config.info.OS = 'Win10'; else, config.info.OS = 'Win11'; end

        % get device info
        daqreset;
        mglreset;
        try ni_info = daqhwinfo('nidaq'); ni_info = enum_recording(ni_info); catch, ni_info = struct('ai',[],'ao',[]); end
        try snd_info = daqhwinfo('wasapi'); snd_info = enum_recording(snd_info); catch, snd_info = struct('ai',[],'ao',[]); end
        try snd_info = enum_playback(snd_info); catch, snd_info.ao = []; end

        playback_api = [];
        if ~isempty(ni_info.ao), playback_api = playback_api_list(1,:); end
        if ~isempty(snd_info.ao), playback_api = [playback_api; playback_api_list(2:end,:)]; end
        if ~isempty(playback_api) && isempty(ni_info.ai), error('At least one NI board that supports analoginput is required to record sound output!'); end

        recording_api = [];
        if ~isempty(ni_info.ai), recording_api = recording_api_list(1,:); end
        if ~isempty(snd_info.ai), recording_api = [recording_api; recording_api_list(2:end,:)]; end
        if ~isempty(recording_api) && isempty(ni_info.ao), error('At least one NI board that supports analogoutput is required to play the test tone!'); end

        measurement_type = [];
        if ~isempty(playback_api), measurement_type = measurement_type_list(1,:); end
        if ~isempty(recording_api), measurement_type = [measurement_type; measurement_type_list(2:end,:)]; end
        if isempty(measurement_type), error('No play or recording device is detected!'); end
    end
    function info = enum_playback(info)
        str = {'XAudio2','Shared3','Exclusive','Shared1'};
        for m=1:length(str)
            [~,~,~,dev] = mglaudioengine(m); if ~iscell(dev), dev = {dev}; end
            ndev = length(dev);
            info.ao.(str{m}) = cell(ndev,6);
            for n=1:ndev
                [~,~,~,dev,fmt,drv] = mglaudioengine(m,n);
                if ~iscell(dev), dev = {dev}; end
                if ~iscell(fmt), fmt = {fmt}; end
                info.ao.(str{m}){n,1} = dev{n};
                info.ao.(str{m}){n,2} = n;
                info.ao.(str{m}){n,3} = [1,2];
                info.ao.(str{m}){n,4} = sprintf('%s %s (%s)',drv.Driver,drv.DriverVersion,drv.DriverDate);
                info.ao.(str{m}){n,5} = fi(isempty(regexpi(drv.DriverProvider,'microsoft','once')),'MF','MS');
                info.ao.(str{m}){n,6} = fmt;
            end
        end
    end
    function info = enum_recording(info)
        io = {'ai','ao','dio'};
        nboard = length(info.BoardNames);
        info.io_support = ~cellfun(@isempty,info.ObjectConstructorName);
        info.frendly_name = cell(nboard,1);
        info.io_info = cell(nboard,3);
        info.driver = cell(nboard,2);
        InputType = cell(nboard,1);
        for m=1:nboard
            info.frendly_name{m} = sprintf('%s: %s',info.InstalledBoardIds{m},info.BoardNames{m});
            for n=1:length(io)
                if ~info.io_support(m,n), continue, end
                try
                    o = eval(info.ObjectConstructorName{m,n});
                catch
                    fprintf(2,'An error occurred while initializing %s\n',info.frendly_name{m});
                    info.io_support(m,n) = false;
                    continue
                end
                if 1==n, InputType{m} = set(o,'InputType'); end
                i = daqhwinfo(o);
                if isfield(i,'MaxSampleRate') && i.MaxSampleRate<config.info.fs
                    fprintf(2,'The max sample rate of %s %s is just %d Hz. We need one that supports >%d Hz!!!\n',info.BoardNames{m},io{n},i.MaxSampleRate,config.info.fs);
                    info.io_support(m,n) = false;
                    continue
                end
                info.io_info{m,n} = i;
                if isfield(i,'VendorDriverProvider')
                    info.driver{m,1} = sprintf('%s %s (%s)',i.VendorDriverDiscription,i.VendorDriverVersion,i.VendorDriverDate);
                    info.driver{m,2} = fi(isempty(regexpi(i.VendorDriverProvider,'microsoft','once')),'MF','MS');
                else
                    info.driver(m,:) = {sprintf('%s %s',i.VendorDriverDiscription,i.VendorDriverVersion),'MF'};
                end
            end
        end
        for m=1:length(io)
            idx = info.io_support(:,m);
            num = find(idx);
            ch = cell(length(num),1);
            fmt = cell(length(num),1);
            for n=1:length(num)
                i = info.io_info{num(n),m};
                switch m
                    case 1
                        ch{n} = {i.DifferentialIDs,i.SingleEndedIDs};
                        if isfield(i,'SupportedFormat'), fmt{n} = i.SupportedFormat; else, fmt{n} = {sprintf('%d Hz',min(config.info.fs,i.MaxSampleRate))}; end
                    case 2, ch{n} = i.ChannelIDs; fmt{n} = {sprintf('%d Hz',min(config.info.fs,i.MaxSampleRate))};
                    case 3, ch{n} = {i.Port.LineIDs}; for k=1:length(i.Port), if isempty(regexp(i.Port(k).Direction,'out','once')), ch{n}{k} = []; end, end
                end
            end
            info.(io{m}) = [info.frendly_name(idx) num2cell(num) ch info.driver(idx,:) fmt];
            if 1==m, info.(io{m}) = [info.(io{m}) InputType(idx)]; end
        end
    end

    function val = setval(h,op,val)
        try
            if isnumeric(val)
                if iscell(op), op = cell2mat(op); end, idx = find(op==val,1); if isempty(idx), idx = 1; end, val = op(idx);
            else
                idx = find(strcmp(op,val),1); if isempty(idx), idx = 1; end, val = op{idx};
            end
            set(h,'string',op,'value',idx);
        catch err
            err %#ok<NOPRT>
        end
    end
    function [val,idx] = getval(op,val)
        try
            if isnumeric(val)
                idx = find(op==val,1); if isempty(idx), idx = 1; end, val = op(idx);
            else
                idx = find(strcmp(op,val),1);
                if isempty(idx), idx = 1; end, val = op{idx};
            end
        catch err
            err %#ok<NOPRT>
        end
    end
    function idx = getidx(op,val), [~,idx] = getval(op,val); end
    function op = fi(tf,op1,op2), if tf, op = op1; else, op = op2; end, end
end
