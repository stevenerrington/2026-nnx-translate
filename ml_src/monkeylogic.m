function monkeylogic()
% NIMH MonkeyLogic
%
% NIMH MonkeyLogic is a MATLAB-based software tool for behavioral control
% and data acquisition.
%
% Developer: Jaewon Hwang (jaewon.hwang@nih.gov, jaewon.hwang@hotmail.com)
% Website: https://monkeylogic.nimh.nih.gov

newline = char(10); %#ok<CHARTEN>

MLConfig = mlconfig;
old_MLConfig = MLConfig;
MLPath = MLConfig.MLPath;
MLConditions = MLConfig.MLConditions;
DAQ = MLConfig.DAQ;
DAQ.msg_handler(@mlmessage);
Screen = MLConfig.Screen;
System = MLConfig.System;

% temporary variables
hTag = struct('hFig',[],'hVideo',[],'hIO',[],'hTask',[]);
hMessagebox = [];
IOBoard = [];      % DAQ board list
IOName = [];       % IO names on the GUI menu
io = [];           % IO panel user input cache
datafilename_manually_typed = false;
all_DAQ_accounted = true;
null_tic = tic;
last_click = tic;
last_clicked = NaN;

% figure
calibration_method = {'Raw Signal (Pre-calibrated)','Origin & Gain','2-D Spatial Transformation'};
load('mlimagedata.mat','earth_image','ioheader_image','runbutton_image','runbuttondim_image','taskheader_image','threemonkeys_image','sound_icon','ttl_icon','videoheader_image','expand_icon','collapse_icon','help_icon','refresh_icon','refresh_active','play_button');
fontsize = 9;
callbackfunc = @UIcallback;
figure_bgcolor = [.65 .70 .80];
frame_bgcolor = [0.9255 0.9137 0.8471];
purple_bgcolor = [.8 .76 .82];
green_bgcolor = [0.7098 0.9020 0.1137];
collapsed_menu = false;
init();

    function update_UI(alteni_skip)
        if ~exist('alteni_skip','var'), alteni_skip = false; end

        float1 = {'DiagonalSize','ViewingDistance','FixationPointDeg'};
        int0 = {'EyeTracerSize','JoystickCursorSize','TouchCursorSize','PhotoDiodeTriggerSize','EyeAutoDriftCorrection','InterTrialInterval'};
        int1 = {'TotalNumberOfTrialsToRun','TotalNumberOfBlocksToRun'};
        arr1 = {'NumberOfTrialsToRunInThisBlock'};
        for m=float1, if isnan(MLConfig.(m{1})) || MLConfig.(m{1})<=0, mlmessage('''%s'' must be a positive number',m{1},'e'); MLConfig.(m{1}) = old_MLConfig.(m{1}); end, end
        for m=int0, MLConfig.(m{1}) = round(MLConfig.(m{1})); if any(isnan(MLConfig.(m{1}))) || any(MLConfig.(m{1})<0), mlmessage('''%s'' must be 0 or a positive number',m{1},'e'); MLConfig.(m{1}) = round(old_MLConfig.(m{1})); end, end
        for m=int1, MLConfig.(m{1}) = round(MLConfig.(m{1})); if isnan(MLConfig.(m{1})) || MLConfig.(m{1})<=0, mlmessage('''%s'' must be a positive number',m{1},'e'); MLConfig.(m{1}) = round(old_MLConfig.(m{1})); end, end
        for m=arr1, MLConfig.(m{1}) = round(MLConfig.(m{1})); if any(isnan(MLConfig.(m{1}))) || any(MLConfig.(m{1})<1), mlmessage('''%s'' must be 1 or a positive number',m{1},'e'); MLConfig.(m{1}) = old_MLConfig.(m{1}); end, end

        if ~isempty(hTag.hVideo), update_videoUI(); end
        if ~isempty(hTag.hIO), update_ioUI(); end
        if ~isempty(hTag.hTask), update_taskUI(); end

        set(hTag.ConfigurationFile,'string',strip_path(MLPath.ConfigurationFile));
        set(hTag.OpenConfigurationFolder,'enable',fi(2==exist(MLPath.ConfigurationFile,'file'),'on','off'));

        set(hTag.LoadConditionsFile,'enable','on','string',fi(isempty(MLPath.ConditionsFile),'To start, load a conditions file',strip_path(MLPath.ConditionsFile)));
        set(hTag.EditConditionsFile,'enable',fi(isempty(MLPath.ConditionsFile),'off','on'));

        vars = MLConditions.UIVars;
        enable = fi(isconditionsfile(MLConditions),'on','off');
        set(hTag.TotalNumberOfConditions,'string',num2str(vars.TotalNumberOfConditions));
        if isconditionsfile(MLConditions), str = {vars.StimulusList.Label}; else, str = vars.StimulusList; end
        set(hTag.StimulusList,'enable',fi(isempty(vars.StimulusList),'off','on'),'string',str);
        set(hTag.StimulusTest,'enable',enable);
        set(hTag.BlockList,'enable',enable,'string',num2cell(vars.BlockList));
        set(hTag.ChooseBlocksToRun,'enable',enable);
        set(hTag.ChooseFirstBlockToRun,'enable',enable);
        if ~alteni_skip
            if isconditionsfile(MLConditions)
                chosen_block = get(hTag.BlockList,'value');
                set(hTag.TotalNumberOfConditionsInThisBlock,'string',num2str(vars.TotalNumberOfConditionsInThisBlock(chosen_block)));
                set(hTag.NumberOfTrialsToRunInThisBlock,'enable',enable,'string',num2str(MLConfig.NumberOfTrialsToRunInThisBlock(chosen_block)));
                set(hTag.CountOnlyCorrectTrials,'enable',enable,'value',MLConfig.CountOnlyCorrectTrials(chosen_block));
                set(hTag.BlocksToRun,'string',['[' num2range(MLConfig.BlocksToRun) ']']);
                set(hTag.FirstBlockToRun,'string',fi(isempty(MLConfig.FirstBlockToRun),'TBD',num2str(MLConfig.FirstBlockToRun)));
            else
                set(hTag.TotalNumberOfConditionsInThisBlock,'string','');
                set(hTag.NumberOfTrialsToRunInThisBlock,'enable',enable,'string','');
                set(hTag.CountOnlyCorrectTrials,'enable',enable,'value',false);
                set(hTag.BlocksToRun,'string','');
                set(hTag.FirstBlockToRun,'string','');
            end
        end

        set(hTag.ChartBlocks,'enable',enable);
        set(hTag.ApplyToAll,'enable',enable);
        set(hTag.TimingFiles,'enable',fi(isempty(vars.TimingFiles),'off','on'),'string',vars.TimingFiles);
        set(hTag.EditTimingFiles,'enable',enable);

        set(hTag.TotalNumberOfTrialsToRun,'string',num2str(MLConfig.TotalNumberOfTrialsToRun));
        set(hTag.TotalNumberOfBlocksToRun,'string',num2str(MLConfig.TotalNumberOfBlocksToRun));

        set(hTag.ExperimentName,'string',MLConfig.ExperimentName);
        set(hTag.Investigator,'string',MLConfig.Investigator);
        set(hTag.SubjectName,'string',MLConfig.SubjectName);
        set(hTag.FilenameFormat,'string',MLConfig.FilenameFormat);

        set(hTag.DataFile,'string',MLPath.DataFile);
        MLConfig.Filetype = set_listbox_item(hTag.Filetype,MLConfig.Filetype);
        set(hTag.SaveStimuli,'value',MLConfig.SaveStimuli);
%         set(hTag.MinifyRuntime,'value',MLConfig.MinifyRuntime);

        if isloaded(MLConditions)
            set(hTag.RunButton,'enable','on','cdata',runbutton_image);
        else
            set(hTag.RunButton,'enable','inactive','cdata',runbuttondim_image);
        end

        set(hTag.SaveSettings,'enable',fi(2==exist(MLPath.ConfigurationFile,'file') && isequal(MLConfig,old_MLConfig),'off','on'));
    end

    function update_videoUI()
        set(hTag.LatencyTest,'enable','on');
        set(hTag.VideoTest,'enable','on');

        if System.NumberOfScreenDevices < MLConfig.SubjectScreenDevice
            mlmessage('Can''t find the subject screen device #%d. Changed to #%d.',MLConfig.SubjectScreenDevice,System.NumberOfScreenDevices,'e');
            MLConfig.SubjectScreenDevice = System.NumberOfScreenDevices;
        end
        if 4~=length(regexp(MLConfig.FallbackScreenRect,'-?[0-9]+'))
            mlmessage('Fallback screen rect: %s is not a 1-by-4 vector. Changed back to %s.',MLConfig.FallbackScreenRect,old_MLConfig.FallbackScreenRect,'e');
            MLConfig.FallbackScreenRect = old_MLConfig.FallbackScreenRect;
        end
        if isempty(regexp(MLConfig.FallbackScreenRect,'^[ \t]*\[[ \t]*-?[0-9]+(,|[ \t]+)-?[0-9]+(,|[ \t]+)-?[0-9]+(,|[ \t]+)-?[0-9]+[ \t]*\][ \t]*$','match'))
            mlmessage('Fallback screen rect: %s is not a format of [left,top,right,bottom]. Changed back to %s.',MLConfig.FallbackScreenRect,old_MLConfig.FallbackScreenRect,'e');
            MLConfig.FallbackScreenRect = old_MLConfig.FallbackScreenRect;
        end

        set(hTag.SubjectScreenDevice,'value',MLConfig.SubjectScreenDevice);
        set(hTag.Resolution,'string',MLConfig.Resolution);
        set(hTag.DiagonalSize,'string',num2str(MLConfig.DiagonalSize));
        set(hTag.ViewingDistance,'string',num2str(MLConfig.ViewingDistance));
        set(hTag.PixelsPerDegree,'string',sprintf('%.3f',MLConfig.PixelsPerDegree(1)));
        set(hTag.AdjustedPPD,'value',MLConfig.AdjustedPPD);

        set(hTag.FallbackScreenRect,'string',MLConfig.FallbackScreenRect);
        set(hTag.ForcedUseOfFallbackScreen,'value',MLConfig.ForcedUseOfFallbackScreen);

        set_button_color(hTag.SubjectScreenBackground,MLConfig.SubjectScreenBackground);

        MLConfig.FixationPointImage = MLPath.validate_path(MLConfig.FixationPointImage);
        set(hTag.FixationPointImage,'string',strip_path(MLConfig.FixationPointImage,'Select a(n) image/movie'));
        enable = fi(isempty(MLConfig.FixationPointImage),'on','off');
        MLConfig.FixationPointShape = set_listbox_item(hTag.FixationPointShape,MLConfig.FixationPointShape,'enable',enable);
        set_button_color(hTag.FixationPointColor,MLConfig.FixationPointColor,'enable',enable);
        set(hTag.FixationPointDeg,'string',num2str(MLConfig.FixationPointDeg),'enable',enable);

        eyenum = MLConfig.EyeNumber;
        set(hTag.EyeNumber(1),'value',eyenum);
        MLConfig.EyeTracerShape{eyenum} = set_listbox_item(hTag.EyeTracerShape,MLConfig.EyeTracerShape{eyenum});
        set_button_color(hTag.EyeTracerColor,MLConfig.EyeTracerColor(eyenum,:));
        set(hTag.EyeTracerSize,'string',num2str(MLConfig.EyeTracerSize(eyenum)),'enable',fi(strcmp(MLConfig.EyeTracerShape{eyenum},'Line'),'off','on'));

        joynum = MLConfig.JoystickNumber;
        set(hTag.JoystickNumber(1),'value',joynum);
        MLConfig.JoystickCursorImage{joynum} = MLPath.validate_path(MLConfig.JoystickCursorImage{joynum});
        set(hTag.JoystickCursorImage,'string',strip_path(MLConfig.JoystickCursorImage{joynum},'Select a(n) image/movie'));
        enable = fi(isempty(MLConfig.JoystickCursorImage{joynum}),'on','off');
        MLConfig.JoystickCursorShape{joynum} = set_listbox_item(hTag.JoystickCursorShape,MLConfig.JoystickCursorShape{joynum},'enable',enable);
        set_button_color(hTag.JoystickCursorColor,MLConfig.JoystickCursorColor(joynum,:),'enable',enable);
        set(hTag.JoystickCursorSize,'string',num2str(MLConfig.JoystickCursorSize(joynum)),'enable',enable);

        MLConfig.TouchCursorImage = MLPath.validate_path(MLConfig.TouchCursorImage);
        set(hTag.TouchCursorImage,'string',strip_path(MLConfig.TouchCursorImage,'Select a(n) image/movie'));
        enable = fi(isempty(MLConfig.TouchCursorImage),'on','off');
        MLConfig.TouchCursorShape = set_listbox_item(hTag.TouchCursorShape,MLConfig.TouchCursorShape,'enable',enable);
        set_button_color(hTag.TouchCursorColor,MLConfig.TouchCursorColor,'enable',enable);
        set(hTag.TouchCursorSize,'string',num2str(MLConfig.TouchCursorSize),'enable',enable);

        set(hTag.MouseCursorType,'value',MLConfig.MouseCursorType);

        set(hTag.PhotoDiodeTrigger,'value',MLConfig.PhotoDiodeTrigger);
        set(hTag.PhotoDiodeTriggerSize,'string',num2str(MLConfig.PhotoDiodeTriggerSize));
        set(hTag.PhotoDiodeTuning,'enable',fi(1==MLConfig.PhotoDiodeTrigger||0==MLConfig.PhotoDiodeTriggerSize,'off','on'));
    end

    function update_ioUI()
        set(hTag.IOTestButton,'enable','on');
        set(hTag.StrobeTest,'enable','on');
        set(hTag.RewardTest,'enable','on');

        set(hTag.EditBehavioralCodesFile,'enable',fi(isempty(MLPath.BehavioralCodesFile),'off','on'));

        MLConfig.AIConfiguration = set_listbox_item(hTag.AIConfiguration,MLConfig.AIConfiguration);
        MLConfig.AISampleRate = str2double(set_listbox_item(hTag.AISampleRate,num2str(fi(MLConfig.NonStopRecording,1000,MLConfig.AISampleRate))));

        set(hTag.StrobeTrigger,'value',MLConfig.StrobeTrigger);
        set(hTag.RewardPolarity,'value',MLConfig.RewardPolarity);
        set(hTag.RewardTest,'enable',fi(isempty(MLPath.RewardFunction),'off','on'));

        set(hTag.UseDefaultIO,'visible',fi(exist(MLPath.DefaultConfigPath,'file'),'on','off'));

        eyenum = MLConfig.EyeNumber;
        set(hTag.EyeNumber(2),'value',eyenum);
        set(hTag.EyeCalibration,'value',MLConfig.EyeCalibration(eyenum));
        if 1==MLConfig.EyeCalibration(eyenum)
            enable = 'off'; string = 'Calibrate Eye'; color = [0 0 0];
        else
            enable = 'on';
            string = fi(isempty(MLConfig.EyeTransform{eyenum,MLConfig.EyeCalibration(eyenum)}),'Calibrate Eye','Re-calibrate');
            color = fi(isempty(MLConfig.EyeTransform{eyenum,MLConfig.EyeCalibration(eyenum)}),[1 0 0],[0 0.5 0]);
        end
        set(hTag.ResetEyeCalibration,'enable',fi(isempty(MLConfig.EyeTransform{eyenum,MLConfig.EyeCalibration(eyenum)}),'off','on'));
        set(hTag.EyeCalibrationButton,'enable',enable,'string',string,'foregroundcolor',color);
        set(hTag.EyeCalibrationImportButton,'enable',enable);
        set(hTag.EyeAutoDriftCorrection,'string',num2str(MLConfig.EyeAutoDriftCorrection));

        joynum = MLConfig.JoystickNumber;
        set(hTag.JoystickNumber(2),'value',joynum);
        set(hTag.JoystickCalibration,'value',MLConfig.JoystickCalibration(joynum));
        if 1==MLConfig.JoystickCalibration(joynum)
            enable = 'off'; string = 'Calibrate Joy'; color = [0 0 0];
        else
            enable = 'on';
            string = fi(isempty(MLConfig.JoystickTransform{joynum,MLConfig.JoystickCalibration(joynum)}),'Calibrate Joy','Re-calibrate');
            color = fi(isempty(MLConfig.JoystickTransform{joynum,MLConfig.JoystickCalibration(joynum)}),[1 0 0],[0 0.5 0]);
        end
        set(hTag.ResetJoystickCalibration,'enable',fi(isempty(MLConfig.JoystickTransform{joynum,MLConfig.JoystickCalibration(joynum)}),'off','on'));
        set(hTag.JoystickCalibrationButton,'enable',enable,'string',string,'foregroundcolor',color);
        set(hTag.JoystickCalibrationImportButton,'enable',enable);
    end

    function update_taskUI()
        set(hTag.ErrorLogic,'value',MLConfig.ErrorLogic,'enable','on');
        MLConfig.CondSelectFunction = MLPath.validate_path(MLConfig.CondSelectFunction);
        MLConfig.CondLogic = fi(5==MLConfig.CondLogic && isempty(MLConfig.CondSelectFunction),1,MLConfig.CondLogic);
        set(hTag.CondLogic,'value',MLConfig.CondLogic,'enable','on');
        set(hTag.CondSelectFunction,'string',strip_path(MLConfig.CondSelectFunction,'Choose a user-defined function'),'enable',fi(5==MLConfig.CondLogic,'on','off'));
        MLConfig.BlockSelectFunction = MLPath.validate_path(MLConfig.BlockSelectFunction);
        MLConfig.BlockLogic = fi(5==MLConfig.BlockLogic && isempty(MLConfig.BlockSelectFunction),1,MLConfig.BlockLogic);
        set(hTag.BlockLogic,'value',MLConfig.BlockLogic,'enable','on');
        set(hTag.BlockSelectFunction,'string',strip_path(MLConfig.BlockSelectFunction,'Choose a user-defined function'),'enable',fi(5==MLConfig.BlockLogic,'on','off'));
        if isloaded(MLConditions) && isuserloopfile(MLConditions)
            set(hTag.ErrorLogic,'enable','off');
            set(hTag.CondLogic,'enable','off');
            set(hTag.CondSelectFunction,'enable','off');
            set(hTag.BlockLogic,'enable','off');
            set(hTag.BlockSelectFunction,'enable','off');
        end
        MLConfig.BlockChangeFunction = MLPath.validate_path(MLConfig.BlockChangeFunction);
        set(hTag.BlockChangeFunction,'string',strip_path(MLConfig.BlockChangeFunction,'Block change function'));

        enable = fi(isempty(MLPath.AlertFunction),'off','on');
        set(hTag.RemoteAlert,'enable',enable,'string',fi(MLConfig.RemoteAlert,'Alert ON','Alert OFF'),'fontweight',fi(MLConfig.RemoteAlert,'bold','normal'),'foregroundcolor',fi(MLConfig.RemoteAlert,[1 0 0],[0 0 0]));
        set(hTag.EditAlertFunc,'enable',enable);
        set(hTag.InterTrialInterval,'string',num2str(MLConfig.InterTrialInterval));
        set(hTag.SummarySceneDuringITI,'value',MLConfig.SummarySceneDuringITI);
        set(hTag.NonStopRecording,'value',MLConfig.NonStopRecording);
        MLConfig.UserPlotFunction = MLPath.validate_path(MLConfig.UserPlotFunction);
        set(hTag.UserPlotFunction,'string',strip_path(MLConfig.UserPlotFunction,'User plot function'));
    end

    function UIcallback(hObject,~)
        err = [];
        obj_tag = get(hObject,'tag');
        switch obj_tag
            case {'SubjectScreenDevice','AdjustedPPD','ForcedUseOfFallbackScreen','MouseCursorType','PhotoDiodeTrigger', ...
                    'ErrorLogic','SummarySceneDuringITI','NonStopRecording', ...
                    'Touchscreen','RewardPolarity','StrobeTrigger','EyeNumber','JoystickNumber'}
                MLConfig.(obj_tag) = get(gcbo,'value');
            case {'CondLogic','BlockLogic'}
                MLConfig.(obj_tag) = get(gcbo,'value');
                switch obj_tag
                    case 'CondLogic', filename = MLConfig.CondSelectFunction;
                    case 'BlockLogic', filename = MLConfig.BlockSelectFunction;
                end
                if 5==MLConfig.(obj_tag) && isempty(MLPath.validate_path(filename))
                    [filename,filepath] = uigetfile({'*.m','MATLAB Files'; '*.*','All Files'},'Select a MATLAB script');
                    switch obj_tag
                        case 'CondLogic', MLConfig.CondSelectFunction = fi(0==filename,'',[filepath filename]);
                        case 'BlockLogic', MLConfig.BlockSelectFunction = fi(0==filename,'',[filepath filename]);
                    end
                end
            case 'FallbackScreenRect', MLConfig.(obj_tag) = get(gcbo,'string');
            case {'DiagonalSize','ViewingDistance','FixationPointDeg','TouchCursorSize','PhotoDiodeTriggerSize', ...
                    'InterTrialInterval','TotalNumberOfTrialsToRun','TotalNumberOfBlocksToRun'}
                MLConfig.(obj_tag) = str2double(get(gcbo,'string'));
            case 'EyeAutoDriftCorrection', MLConfig.(obj_tag) = max(0,min(100,str2double(get(gcbo,'string'))));
            case {'FixationPointShape','TouchCursorShape','USBJoystick','AIConfiguration'}
                items = get(gcbo,'string');
                MLConfig.(obj_tag) = items{get(gcbo,'value')};
                preview();
            case {'AISampleRate'}
                items = get(gcbo,'string');
                MLConfig.(obj_tag) = str2double(items{get(gcbo,'value')});
            case {'SubjectScreenBackground','FixationPointColor','TouchCursorColor'}
                MLConfig.(obj_tag) = uisetcolor(MLConfig.(obj_tag),'Pick up a color');
                preview();
            case {'FixationPointImage','TouchCursorImage'}
                [filename,filepath] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.gif;*.mp4;*.avi;*.mpg;*.mpeg','Image/Movie Files'; '*.*','All Files'},'Select a(n) image/movie file',fileparts(MLConfig.(obj_tag)));
                MLConfig.(obj_tag) = fi(0==filename,'',[filepath filename]);
                preview();
            case {'EyeTracerShape','JoystickCursorShape'}
                no = fi(strncmpi(obj_tag,'eye',3),MLConfig.EyeNumber,MLConfig.JoystickNumber);
                items = get(gcbo,'string');
                MLConfig.(obj_tag){no} = items{get(gcbo,'value')};
            case {'EyeTracerColor','JoystickCursorColor'}
                no = fi(strncmpi(obj_tag,'eye',3),MLConfig.EyeNumber,MLConfig.JoystickNumber);
                MLConfig.(obj_tag)(no,:) = uisetcolor(MLConfig.(obj_tag)(no,:),'Pick up a color');
            case {'EyeTracerSize','JoystickCursorSize'}
                no = fi(strncmpi(obj_tag,'eye',3),MLConfig.EyeNumber,MLConfig.JoystickNumber);
                MLConfig.(obj_tag)(no) = str2double(get(gcbo,'string'));
            case {'EyeCalibration','JoystickCalibration'}
                no = fi(strncmpi(obj_tag,'eye',3),MLConfig.EyeNumber,MLConfig.JoystickNumber);
                MLConfig.(obj_tag)(no) = get(gcbo,'value');
            case 'JoystickCursorImage'
                [filename,filepath] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.gif;*.mp4;*.avi;*.mpg;*.mpeg','Image/Movie Files'; '*.*','All Files'},'Select a(n) image/movie file',fileparts(MLConfig.(obj_tag){MLConfig.JoystickNumber}));
                MLConfig.(obj_tag){MLConfig.JoystickNumber} = fi(0==filename,'',[filepath filename]);
            case {'CondSelectFunction','BlockSelectFunction','BlockChangeFunction','UserPlotFunction'}
                [filename,filepath] = uigetfile({'*.m','MATLAB Files'; '*.*','All Files'},'Select a MATLAB script',fileparts(MLConfig.(obj_tag)));
                MLConfig.(obj_tag) = fi(0==filename,'',[filepath filename]);
            case 'LoadSettings'
                try
                    check_cfg_change();
                    [config_by_subject,filename,filepath] = DlgSelectConfig();
                    if ~isempty(config_by_subject)
                        old_config = MLConfig;
                        loadcfg([filepath filename],config_by_subject);
                        for m={'NumberOfTrialsToRunInThisBlock','CountOnlyCorrectTrials','BlocksToRun','FirstBlockToRun','SubjectName'}, MLConfig.(m{1}) = old_config.(m{1}); end
                        old_MLConfig = old_config;
                        if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
                        mlmessage('New config loaded: %s (%s)',filename,filepath);
                    end
                catch err
                end
            case 'SaveSettings'
                savecfg(MLPath.ConfigurationFile);
                [p,n,e] = fileparts(MLPath.ConfigurationFile);
                mlmessage('Config saved: %s (%s)',[n e],p);
            case 'LatencyTest'
                try
                    set(gcbo,'enable','off');
                    for m=1:2
                        if 1<MLConfig.EyeCalibration(m) && isempty(MLConfig.EyeTransform{m,MLConfig.EyeCalibration(m)})
                            error('Eye #%d is not calibrated yet. Calibrate it first or choose ''Raw Signal''',m);
                        end
                        if 1<MLConfig.JoystickCalibration(m) && isempty(MLConfig.JoystickTransform{m,MLConfig.JoystickCalibration(m)})
                            error('Joystick #%d is not calibrated yet. Calibrate it first or choose ''Raw Signal''',m);
                        end
                    end
                    old_MLConditions = MLConditions;
                    MLConfig.MLConditions = mlconditions([MLPath.BaseDirectory 'mltimetest.m']);
                    create(DAQ,MLConfig);
                    create(Screen,MLConfig);
                    result = run_trial(MLConfig);
                catch err
                end
                if exist('old_MLConditions','var'), MLConfig.MLConditions = old_MLConditions; end
                if exist('result','var')
                    pos = get(hTag.hFig,'position');
                    screen_pos = GetMonitorPosition(Pos2Rect(pos));
                    fig_pos = [0 0 800 600];
                    fig_pos(1) = min(max(pos(1) + 0.5 * (pos(3) - fig_pos(3)), screen_pos(1)), sum(screen_pos([1 3])) - fig_pos(3));
                    fig_pos(2) = min(max(pos(2) + 0.5 * (pos(4) - fig_pos(4) - 30), screen_pos(2) + 40), sum(screen_pos([2 4])) - fig_pos(4) - 30);

                    figure;
                    set(gcf,'units','pixels','position',fig_pos,'color',[0 0 0],'numbertitle','off','name','MonkeyLogic Latency Test');

                    pass = size(result{1},1);
                    maxtime = 1000;
                    color = { 0.5*[.8 .8 0],[.8 .8 0] };

                    subplot(2,1,1); hold on;
                    ymax = 0;
                    for m=pass
                        x = result{m,1}(2:end) - result{m,1}(1);
                        y = diff(result{m,1});
                        plot(x, y,'-','linewidth',1,'color',color{m});
                        ymax = max([ymax max(y)]);
                    end
                    set(gca,'box','on','color',[0 0 0],'xlim',[-10 maxtime],'ylim',ymax*[-0.05 1.05],'xcolor',[1 1 1],'ycolor',[1 1 1]);
                    xlabel('Cycle Number');
                    ylabel('Cycle Latency (milliseconds)');
                    set(title('Static Picture Display Results'),'color',[1 1 1]);

                    subplot(2,1,2); hold on;
                    ymax = 0;
                    for m=pass
                        x = result{m,2}{1}(2:end) - result{m,2}{2}(1);
                        y = diff(result{m,2}{1});
                        plot(x, y,'-','linewidth',1,'color',color{m});
                        ymax = max([ymax max(y)]);
                    end
                    for m=pass
                        x = result{m,2}{2} - result{m,2}{2}(1);
                        y = ymax*1.05*ones(size(x));
                        stem(x,y,'marker','none','linewidth',0.5,'color',[1 0 0]);
                    end
                    set(gca,'box','on','color',[0 0 0],'xlim',[-10 maxtime],'ylim',ymax*[-0.05 1.05],'xcolor',[1 1 1],'ycolor',[1 1 1]);
                    xlabel('Cycle Number');
                    ylabel('Cycle Latency (milliseconds)');
                    set(title('Movie Display Results'),'color',[1 1 1]);
                end
                set(gcbo,'enable','on');
            case 'PhotoDiodeTuning'
                try
                    create(DAQ,MLConfig); if isempty(DAQ.get_device('photodiode')), error('Photodiode input is not assigned in the I/O panel!!!'); end
                    MLConfig.RasterThreshold = mlphotodiodetuner(MLConfig);
                catch err
                end
                destroy(DAQ);
            case 'EditBehavioralCodesFile', system(MLPath.BehavioralCodesFile);
            case 'EditAlertFunc', system(MLPath.AlertFunction);
            case 'RemoteAlert', MLConfig.(obj_tag) = ~MLConfig.(obj_tag);
            case {'ExperimentName','Investigator','FilenameFormat'}
                val = get(gcbo,'string'); MLConfig.(obj_tag) = fi(isempty(val),'',val);
                if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
            case 'DataFile'
                MLPath.DataFile = get(gcbo,'string');
                datafilename_manually_typed = ~isempty(MLPath.DataFile) & ~strcmp(MLPath.DataFile,MLConfig.FormattedName);
                if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
            case 'SignalType'
                update_boards(true);
                if ~isempty(MLConfig.IO)  % toggle the selected signal
                    val = get(gcbo,'value');
                    if toc(last_click) < 1 && last_clicked==val
                        str = MLConfig.IOList{val,1};
                        idx = find(strcmp({MLConfig.IO.SignalType},str),1);
                        if ~isempty(idx)
                            switch str(1:3)
                                case 'TTL'
                                    state = ~MLConfig.IO(idx).Invert;
                                    MLConfig.IO(idx).Invert = state;
                                    IOName{val} = ['{ ' fi(state,'~','') str ' }'];
                            end
                            set(gcbo,'string',IOName);
                        end
                        last_click = null_tic;
                        last_clicked = NaN;
                    else
                        last_click = tic;
                        last_clicked = val;
                    end
                end
            case 'IOBoards', update_subsystem();
            case 'Subsystem', update_channels();
            case 'VideoTest'
                try
                    set(gcbo,'enable','off');
                    create(Screen,MLConfig);

                    halfx = Screen.SubjectScreenHalfSize(1);
                    halfy = Screen.SubjectScreenHalfSize(2);
                    [x,y] = meshgrid(-halfx:halfx-1, -halfy:halfy-1);
                    dist = sqrt((x.^2) + (y.^2));

                    numcycles = 10;
                    buffer = NaN(numcycles, 1);
                    for m = 1:numcycles
                        rpat = cos(dist./m+2);
                        gpat = cos(dist./(m+5));
                        bpat = cos(dist./(m+8));
                        testpattern = cat(3, rpat, gpat, bpat);
                        testpattern = (testpattern + 1)/2;
                        testpattern = round(255*testpattern);
                        buffer(m) = mgladdbitmap(testpattern,1);
                    end

                    for n = 1:numcycles
                        for m = 1:numcycles
                            mglactivategraphic([0 buffer(m)],[false true]);
                            mglrendergraphic;
                            pause(0.01);
                            mglpresent;
                        end
                        for m = numcycles:-1:1
                            mglactivategraphic([0 buffer(m)],[false true]);
                            mglrendergraphic;
                            pause(0.01);
                            mglpresent;
                        end
                    end
                    mgldestroygraphic(buffer);
                catch err
                end
                destroy(Screen);
                set(gcbo,'enable','on');
            case 'IORefresh'
                try
                    if ~isempty(hTag.hVideo), set(hTag.IORefresh1,'enable','inactive','cdata',refresh_active); end
                    if ~isempty(hTag.hIO), set(hTag.IORefresh2,'enable','inactive','cdata',refresh_active); end
                    drawnow;
                    mglreset; if ~isempty(hTag.hVideo), set(hTag.SubjectScreenDevice,'string',num2cell(1:System.NumberOfScreenDevices),'value',min(get(hTag.SubjectScreenDevice,'value'),System.NumberOfScreenDevices)); end
                    daqreset; refresh_boards();
                catch err
                end
                if ~isempty(hTag.hVideo), set(hTag.IORefresh1,'enable','on','cdata',refresh_icon); end
                if ~isempty(hTag.hIO), set(hTag.IORefresh2,'enable','on','cdata',refresh_icon); end
            case 'IOAssign'
                items = get(hTag.Channels,'string');
                val = get(hTag.Channels,'value');
                io.Channel = cellfun(@str2double,items(val));

                entry.SignalType = io.Spec{1};
                entry.Adaptor = IOBoard(io.Board).Adaptor;
                entry.DevID = IOBoard(io.Board).DevID;
                entry.Subsystem = io.SubsystemLabel;
                entry.Channel = io.Channel;
                entry.DIOInfo = DlgAssignDIOLine();  % empty when the dialog is cancelled
                entry.Invert = false;  % default value
                if (3~=io.Subsystem||~isempty(entry.DIOInfo)) && assign_IO(entry)  % entry.DIOInfo cannot be empty when subsystem is digitalio
                    if ~isempty(MLConfig.IO) && any(strcmp({MLConfig.IO.SignalType},io.Spec{1})), clear_IO(io.Spec{1},false); end
                    if isempty(MLConfig.IO), MLConfig.IO = entry; else, MLConfig.IO(end+1,1) = entry; end
                    [~,I] = sort({MLConfig.IO.SignalType}); MLConfig.IO = MLConfig.IO(I);
                    update_boards();
                end
            case 'IOClear', clear_IO(io.Spec{1}); update_boards();
            case 'OtherDeviceSettings', DlgOtherDeviceSettings();
            case 'IOTestButton'
                try
                    set(gcbo,'enable','off');
                    create(DAQ,MLConfig);
                    MLConfig.IOTestParam = mliotest(MLConfig);
                catch err
                end
                destroy(DAQ);
                set(gcbo,'enable','on');
            case 'StrobePulseSpec', DlgStrobePulseSpec();
            case 'StrobeTest'
                try
                    set(gcbo,'enable','off');
                    create(DAQ,MLConfig);
                    if ~DAQ.strobe_present
                        switch MLConfig.StrobeTrigger
                            case {1,2}, error('Either ''Behavioral Codes'' or ''Strobe Bit'' is not assigned');
                            case 3, error('''Behavioral Codes'' is not assigned');
                        end
                    end

                    numline = length(DAQ.BehavioralCodes.Line);
                    mlmessage('Sending 10 cycles of 2.^(0:%d)',numline-1);
                    for m=1:10
                        for n=0:numline-1
                            DAQ.eventmarker(2^n);
                            timer = tic; while toc(timer)<0.01, end
                        end
                        timer = tic; while toc(timer)<0.1, end
                    end
                    mlmessage('Strobe test is done');
                catch err
                end
                destroy(DAQ);
                set(gcbo,'enable','on');
            case 'RewardTest', DlgRewardTest();
            case 'ResetEyeCalibration'
                eyenum = MLConfig.EyeNumber;
                if ~isempty(MLConfig.EyeTransform{eyenum,MLConfig.EyeCalibration(eyenum)})
                    options.Interpreter = 'tex';
                    options.Default = 'Yes';
                    qstring = ['\fontsize{10}This will reset ''' calibration_method{MLConfig.EyeCalibration(eyenum)} sprintf(''' of Eye #%d.',eyenum) newline ...
                        'Do you want to proceed?'];
                    button = questdlg(qstring,'Eye calibration will be reset.','Yes','No',options);
                    if strcmp(button,'Yes'), MLConfig.EyeTransform{eyenum,MLConfig.EyeCalibration(eyenum)} = []; end
                end
            case 'EyeCalibrationButton'
                try
                    set(gcbo,'enable','off'); drawnow;
                    create(DAQ,MLConfig);
                    eyenum = MLConfig.EyeNumber;
                    switch eyenum
                        case 1, if ~DAQ.eye_present, error('''Eye X & Y'' are not assigned yet.'); end
                        case 2, if ~DAQ.eye2_present, error('''Eye2 X & Y'' are not assigned yet.'); end
                    end
                    create(Screen,MLConfig);
                    switch MLConfig.EyeCalibration(eyenum)
                        case 2, MLConfig.EyeTransform{eyenum,2} = mlcalibrate_origin_gain(1,MLConfig);
                        case 3, MLConfig.EyeTransform{eyenum,3} = mlcalibrate_spatial_transform(1,MLConfig);
                    end
                catch err
                end
                destroy(Screen);
                destroy(DAQ);
                set(gcbo,'enable','on');
            case 'EyeCalibrationImportButton'
                [config_by_subject,filename,filepath] = DlgSelectConfig();
                if ~isempty(config_by_subject)
                    content = load([filepath filename],config_by_subject);
                    if isfield(content,config_by_subject) && isa(content.(config_by_subject),'mlconfig')
                        eyenum = MLConfig.EyeNumber;
                        options.Interpreter = 'tex';
                        options.Default = 'Eye #1';
                        qstring = ['\fontsize{10}Which eye would you like to import ''' calibration_method{MLConfig.EyeCalibration(eyenum)} ''' from?'];
                        answer = questdlg(qstring,sprintf('Import Calibration for Eye #%d',eyenum),'Eye #1','Eye #2',options);
                        if ~isempty(answer)
                            chosen = str2double(regexp(answer,'\d','match'));
                            MLConfig.EyeTransform{eyenum,MLConfig.EyeCalibration(eyenum)} = content.(config_by_subject).EyeTransform{chosen,MLConfig.EyeCalibration(eyenum)};
                        end
                    end
                end
            case 'ResetJoystickCalibration'
                joynum = MLConfig.JoystickNumber;
                if ~isempty(MLConfig.JoystickTransform{joynum,MLConfig.JoystickCalibration(joynum)})
                    options.Interpreter = 'tex';
                    options.Default = 'Yes';
                    qstring = ['\fontsize{10}This will reset ''' calibration_method{MLConfig.JoystickCalibration(joynum)} sprintf(''' of Joystick #%d.',joynum) newline ...
                        'Do you want to proceed?'];
                    button = questdlg(qstring,'Joystick calibration will be reset.','Yes','No',options);
                    if strcmp(button,'Yes'), MLConfig.JoystickTransform{joynum,MLConfig.JoystickCalibration(joynum)} = []; end
                end
            case 'JoystickCalibrationButton'
                try
                    set(gcbo,'enable','off'); drawnow;
                    create(DAQ,MLConfig);
                    joynum = MLConfig.JoystickNumber;
                    switch joynum
                        case 1, if ~DAQ.joystick_present, error('''Joystick X & Y'' are not assigned yet.'); end
                        case 2, if ~DAQ.joystick2_present, error('''Joystick2 X & Y'' are not assigned yet.'); end
                    end
                    create(Screen,MLConfig);
                    switch MLConfig.JoystickCalibration(joynum)
                        case 2, MLConfig.JoystickTransform{joynum,2} = mlcalibrate_origin_gain(2,MLConfig);
                        case 3, MLConfig.JoystickTransform{joynum,3} = mlcalibrate_spatial_transform(2,MLConfig);
                    end
                catch err
                end
                destroy(Screen);
                destroy(DAQ);
                set(gcbo,'enable','on');
            case 'JoystickCalibrationImportButton'
                [config_by_subject,filename,filepath] = DlgSelectConfig();
                if ~isempty(config_by_subject)
                    content = load([filepath filename],config_by_subject);
                    if isfield(content,config_by_subject) && isa(content.(config_by_subject),'mlconfig')
                        joynum = MLConfig.JoystickNumber;
                        options.Interpreter = 'tex';
                        options.Default = 'Joystick #1';
                        qstring = ['\fontsize{10}Which joystick would you like to import ''' calibration_method{MLConfig.JoystickCalibration(joynum)} ''' from?'];
                        answer = questdlg(qstring,sprintf('Import Calibration for Joystick #%d',joynum),'Joystick #1','Joystick #2',options);
                        if ~isempty(answer)
                            chosen = str2double(regexp(answer,'\d','match'));
                            MLConfig.JoystickTransform{joynum,MLConfig.JoystickCalibration(joynum)} = content.(config_by_subject).JoystickTransform{chosen,MLConfig.JoystickCalibration(joynum)};
                        end
                    end
                end
            case 'OpenConfigurationFolder', system(['explorer ' fileparts(MLPath.ConfigurationFile)]);
            case 'LoadConditionsFile'
                try
                    if isempty(MLPath.ConditionsFile) && ispref('NIMH_MonkeyLogic','ConditionsFile')
                        last_folder = fileparts(getpref('NIMH_MonkeyLogic','ConditionsFile'));
                        if exist(last_folder,'dir'), cd(last_folder); end
                    end

                    check_cfg_change();
                    [n,p] = uigetfile({'*.txt','Conditions files (*.txt)'; '*.m','Userloop function (*.m)'},'Select a Conditions File');
                    if 0==n
                        MLConditions.init();
                        MLPath.ConditionsFile = '';
                        loadcfg(MLPath.ConfigurationFile);
                        if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
                    else
                        timer = tic;
                        cd(p);
                        set(gcbo,'enable','inactive','string','Loading...');
                        set(hTag.RunButton,'enable','inactive','cdata',runbuttondim_image);
                        drawnow;
                        Conditions = mlconditions;
                        Conditions.load_file([p n],gcbo);
                        if isloaded(Conditions)
                            loadcfg(Conditions.MLPath.ConfigurationFile);
                            MLConfig.MLConditions = Conditions;
                            MLConditions = MLConfig.MLConditions;
                            MLPath.ConditionsFile = Conditions.MLPath.ConditionsFile;
                            setpref('NIMH_MonkeyLogic','ConditionsFile',MLPath.ConditionsFile);
                            if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
                            mlmessage('New conditions loaded in %.1f s: %s (%s)',toc(timer),n,p);

                            old_nblock = length(MLConfig.NumberOfTrialsToRunInThisBlock); new_nblock = length(MLConditions.UIVars.BlockList);
                            if 0==new_nblock
                                MLConfig.NumberOfTrialsToRunInThisBlock = [];
                                MLConfig.CountOnlyCorrectTrials = false;
                            elseif 0==old_nblock
                                MLConfig.NumberOfTrialsToRunInThisBlock = repmat(MLConfig.DefaultNumberOfTrialsToRunInThisBlock,1,new_nblock);
                                MLConfig.CountOnlyCorrectTrials = repmat(MLConfig.DefaultCountOnlyCorrectTrials,1,new_nblock);
                            elseif old_nblock < new_nblock
                                MLConfig.NumberOfTrialsToRunInThisBlock(old_nblock+1:new_nblock) = MLConfig.DefaultNumberOfTrialsToRunInThisBlock;
                                MLConfig.CountOnlyCorrectTrials(old_nblock+1:new_nblock) = MLConfig.DefaultCountOnlyCorrectTrials;
                            else
                                MLConfig.NumberOfTrialsToRunInThisBlock = MLConfig.NumberOfTrialsToRunInThisBlock(1:new_nblock);
                                MLConfig.CountOnlyCorrectTrials = MLConfig.CountOnlyCorrectTrials(1:new_nblock);
                            end
                            old_MLConfig.NumberOfTrialsToRunInThisBlock = MLConfig.NumberOfTrialsToRunInThisBlock;
                            if 2==exist(MLPath.ConfigurationFile,'file')
                                MLConfig.BlocksToRun = MLConfig.BlocksToRun(ismember(MLConfig.BlocksToRun,MLConditions.UIVars.BlockList));
                                if isempty(MLConfig.BlocksToRun), MLConfig.BlocksToRun = MLConditions.UIVars.BlockList; end
                                MLConfig.FirstBlockToRun = MLConfig.FirstBlockToRun(ismember(MLConfig.FirstBlockToRun,MLConditions.UIVars.BlockList));
                            else
                                MLConfig.BlocksToRun = MLConditions.UIVars.BlockList;
                                MLConfig.FirstBlockToRun = [];
                            end
                            set(hTag.StimulusList,'value',1);
                            set(hTag.BlockList,'value',1);
                            set(hTag.TimingFiles,'value',1);
                        end
                    end
                    preview();
                catch err
                end
                set(gcbo,'enable','on');
            case 'EditConditionsFile', system(MLPath.ConditionsFile);
            case 'StimulusList', preview();
            case 'StimulusTest'
                try
                    val = get(hTag.StimulusList,'value');
                    if ~isscalar(val), return, end
                    taskobj = MLConditions.UIVars.StimulusList(val);
                    set([hTag.StimulusList gcbo],'enable','off');
                    mouse = pointingdevice;
                    switch lower(taskobj.Attribute{1})
                        case {'gen','fix','dot','pic','crc','sqr','mov'}
                            create(Screen,MLConfig);
                            TaskObject = mltaskobject(taskobj,MLConfig);
                            id = TaskObject.ID;
                            mglactivategraphic(id);  % taskobject is created inactive for userloop

                            mlmessage('Press any key to quit %s...',taskobj.Label);
                            if strcmp(mglgettype(id),'MOVIE')
                                movie_playback(id);
                            else
                                mglrendergraphic;
                                mglpresent;
                                keypress = []; kbdinit; [~,button] = getsample(mouse);
                                while isempty(keypress) && ~any(button), keypress = kbdgetkey; [~,button] = getsample(mouse); end
                            end
                        case 'snd'
                            TaskObject = mltaskobject(taskobj,MLConfig);
                            id = TaskObject.ID;
                            mglactivatesound(id);  % taskobject is created inactive for userloop

                            mlmessage('%s playing...',taskobj.Label);
                            mglplaysound(id);
                            keypress = []; kbdinit; [~,button] = getsample(mouse);
                            while mglgetproperty(id,'isplaying') && isempty(keypress) && ~any(button), keypress = kbdgetkey; [~,button] = getsample(mouse); end
                            mgldestroysound(id);
                            mlmessage('%s done',taskobj.Label);
                        case 'stm'
                            create(DAQ,MLConfig);
                            TaskObject = mltaskobject(taskobj,MLConfig);
                            o = DAQ.Stimulation{TaskObject.ID};

                            trigger(o);
                            mlmessage('%s sending...',taskobj.Label);
                            while o.Sending, end
                            mlmessage('%s done',taskobj.Label);
                        case 'ttl'
                            create(DAQ,MLConfig);
                            TaskObject = mltaskobject(taskobj,MLConfig);
                            id = TaskObject.ID;
                            o = DAQ.TTL{id};

                            for m=1:3
                                val = ~DAQ.TTLInvert(id); putvalue(o,val); mlmessage(['%s ' fi(val,'HI','LO') ' (%d/3)'],taskobj.Label,m);
                                timer = tic; while toc(timer)<0.3, end
                                val = DAQ.TTLInvert(id); putvalue(o,val); mlmessage(['%s ' fi(val,'HI','LO') ' (%d/3)'],taskobj.Label,m);
                                timer = tic; while toc(timer)<0.3, end
                            end
                            mlmessage('%s done',taskobj.Label);
                    end
                catch err
                end
                destroy(Screen);
                destroy(DAQ);
                set([hTag.StimulusList gcbo],'enable','on');
            case 'NumberOfTrialsToRunInThisBlock'
                chosen_block = get(hTag.BlockList,'value');
                MLConfig.(obj_tag)(chosen_block) = str2double(get(gcbo,'string'));
            case 'CountOnlyCorrectTrials'
                chosen_block = get(hTag.BlockList,'value');
                MLConfig.(obj_tag)(chosen_block) = get(gcbo,'value');
            case 'ChartBlocks', DlgChartBlocks();
            case 'ApplyToAll'
                MLConfig.NumberOfTrialsToRunInThisBlock(:) = str2double(get(hTag.NumberOfTrialsToRunInThisBlock,'string'));
                MLConfig.CountOnlyCorrectTrials(:) = get(hTag.CountOnlyCorrectTrials,'value');
            case 'ChooseBlocksToRun', MLConfig.BlocksToRun = DlgChooseBlock(MLConfig.BlocksToRun, true);
            case 'ChooseFirstBlockToRun', MLConfig.FirstBlockToRun = DlgChooseBlock(MLConfig.FirstBlockToRun, false);
            case 'TimingFiles'
                val = get(gcbo,'value');
                if toc(last_click) < 1 && last_clicked==val
                    items = get(gcbo,'string');
                    [~,n,e] = fileparts(items{val});
                    runtime = [MLPath.RunTimeDirectory n '_runtime' e];
                    if 2==exist(runtime,'file')
                        system(runtime);
                    elseif exist(MLPath.RunTimeDirectory,'dir')
                        system(['explorer ' fileparts(MLPath.RunTimeDirectory)]);
                    end
                    last_click = null_tic;
                    last_clicked = NaN;
                else
                    last_click = tic;
                    last_clicked = val;
                end
            case 'EditTimingFiles'
                hobj = hTag.TimingFiles;
                items = get(hobj,'string');
                val = get(hobj,'value');
                system([MLPath.ExperimentDirectory items{val}]);
            case 'SubjectName'
                try
                    val = get(gcbo,'string');
                    namelengthlimit = namelengthmax()-length('MLEditable_');
                    if ~isempty(val) && isempty(regexp(val,'^[A-Za-z0-9_]+$','once'))
                        mlmessage('Subject Name must use letters, numbers and underscores only','e');
                    elseif namelengthlimit < length(val)
                        mlmessage('Subject Name must be %d characters or shorter',namelengthlimit,'e');
                    else
                        check_cfg_change();
                        if isempty(val)
                            val = '';
                        else
                            if loadcfg(MLPath.ConfigurationFile,['MLConfig_' lower(val)])
                                mlmessage('Subject profile loaded: %s',val,'w');
                            else
                                mlmessage('New profile created: %s',val,'w');
                            end
                        end
                        MLConfig.(obj_tag) = val; old_MLConfig.(obj_tag) = val;
                        if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; end
                    end
                catch err
                end
            case 'Filetype'
                items = get(gcbo,'string');
                MLConfig.(obj_tag) = items{get(gcbo,'value')};
            case 'SaveStimuli', MLConfig.SaveStimuli = get(gcbo,'value');
            case 'MinifyRuntime', MLConfig.MinifyRuntime = get(gcbo,'value');
            case 'RunButton'
                try
                    set(gcbo,'enable','off');
                    h = findobj('tag','mlmonitor'); if ~isempty(h), close(h); end
                    for m=1:2
                        if 1<MLConfig.EyeCalibration(m) && isempty(MLConfig.EyeTransform{m,MLConfig.EyeCalibration(m)})
                            error('Eye #%d is not calibrated yet. Calibrate them first or choose ''Raw Signal''',m);
                        end
                        if 1<MLConfig.JoystickCalibration(m) && isempty(MLConfig.JoystickTransform{m,MLConfig.JoystickCalibration(m)})
                            error('Joystick #%d is not calibrated yet. Calibrate them first or choose ''Raw Signal''',m);
                        end
                    end

                    if ~datafilename_manually_typed, MLPath.DataFile = MLConfig.FormattedName; set(hTag.DataFile,'string',MLPath.DataFile); end
                    datafile = [MLPath.ExperimentDirectory MLPath.DataFile MLConfig.Filetype];
                    if 2==exist(datafile,'file')
                        newfilepath = datafile;
                        fileno = 0;
                        while 2==exist(newfilepath,'file')
                            fileno = fileno + 1;
                            newfilename = [MLPath.DataFile sprintf('(%d)',fileno) MLConfig.Filetype];
                            newfilepath = [MLPath.ExperimentDirectory newfilename];
                        end
                        options.Interpreter = 'tex';
                        options.Default = 'No';
                        qstring = ['\fontsize{10}Overwrite the existing data file?' newline ...
                            'If yes, the old file will be moved to Recycle Bin.' newline ...
                            'If no, the new filename will be ' regexprep(newfilename,'([\^_\\])','\\$1')];
                        button = questdlg(qstring,'Data file already exists','Yes','No','Cancel',options);
                        switch button
                            case {'Cancel',''}, error('RunButton:doNothing','Task cancelled');
                            case 'Yes'
                                previousState = recycle('on');
                                delete(datafile);
                                recycle(previousState);
                                if 2==exist(datafile,'file'), error('Can''t delete %s. Please choose a different name.',datafile); end
                            case 'No'
                                datafile = newfilepath;
                        end
                    end

                    % minify adapters
                    adapter_dest = [tempdir 'mladapters'];
                    adapter_src = [MLPath.BaseDirectory 'ext'];
                    if ~exist(adapter_dest,'dir'), mkdir(adapter_dest); end
                    delete([adapter_dest filesep '*.*']);
                    if MLConfig.MinifyRuntime
                        mlminifier(adapter_dest,adapter_src);
                        addpath(adapter_dest);
                    else
                        mlminifier(adapter_dest,adapter_src,true);
                        addpath(adapter_src);
                    end
                    addpath(MLPath.ExperimentDirectory); % to add the task directory to the top

                    create(DAQ,MLConfig); MLConfig.VoiceRecording.Info = DAQ.VoiceInfo;
                    start_cam(DAQ);
                    create(Screen,MLConfig);
                    if all_DAQ_accounted, savecfg(MLPath.ConfigurationFile); end  % ensure the existence of the configuration file
                    cd(MLPath.ExperimentDirectory);
                    result = run_trial(MLConfig,datafile);
                    if isa(result,'mlconfig')  % MLConfig could be modified during the task, so save it again
                        MLConfig = result;
                        if all_DAQ_accounted, savecfg(MLPath.ConfigurationFile); end
                    end
                    if exist(datafile,'file')
                        behaviorsummary = get_function_handle(MLPath.validate_path('behaviorsummary.m'));
                        behaviorsummary(datafile);
                    end
                catch err
                end
                set(gcbo,'enable','on');
                if ~isempty(err) && (strncmpi(err.message,'mgl::Wait4VBlank',16) || strcmp(err.identifier,'RunButton:doNothing')), err = []; end
            case 'CollapsedMenu', collapsed_menu = true; setpref('NIMH_MonkeyLogic','CollapsedMenu',collapsed_menu); init_menu();
            case 'ExpandedMenu', collapsed_menu = false; setpref('NIMH_MonkeyLogic','CollapsedMenu',collapsed_menu); init_menu();
            case 'VideoSetting'
                if isempty(hTag.hVideo)
                    mlmainmenu = get(hTag.hFig,'position');
                    screen_pos = GetMonitorPosition(Pos2Rect(mlmainmenu));
                    w = 288 ; h = 507;
                    x = mlmainmenu(1) - w - 13;
                    top = mlmainmenu(2) + mlmainmenu(4);
                    y = top - h;
                    if x < screen_pos(1), x = screen_pos(1); end
                    screen_top = screen_pos(2) + screen_pos(4);
                    if screen_top < top, y = screen_top - h - 30; end
                    hTag.hVideo = figure;
                    set(hTag.hVideo,'units','pixels','position',[x y w h],'tag','VideoSettingWindow','closerequestfcn',@close_video_setting,'menubar','none','numbertitle','off','name','Video Settings','color',figure_bgcolor);
                    menu_video(5,505);
                    set(hTag.VideoSetting,'string','Close');
                else
                    close(hTag.hVideo);
                end
            case 'IOSetting'
                if isempty(hTag.hIO)
                    mlmainmenu = get(hTag.hFig,'position');
                    screen_pos = GetMonitorPosition(Pos2Rect(mlmainmenu));
                    w = 308 ; h = 603;
                    x = mlmainmenu(1) + mlmainmenu(3) + 13;
                    top = mlmainmenu(2) + mlmainmenu(4);
                    y = top - h;
                    screen_right = screen_pos(1) + screen_pos(3) - w;
                    if screen_right < x, x = screen_right; end
                    screen_top = screen_pos(2) + screen_pos(4);
                    if screen_top < top, y = screen_top - h - 30; end
                    hTag.hIO = figure;
                    set(hTag.hIO,'units','pixels','position',[x y w h],'tag','IOSettingWindow','closerequestfcn',@close_io_setting,'menubar','none','numbertitle','off','name','I/O Settings','color',figure_bgcolor);
                    menu_io(5,600);
                    set(hTag.IOSetting,'string','Close');
                else
                    close(hTag.hIO);
                end
            case 'TaskSetting'
                if isempty(hTag.hTask)
                    mlmainmenu = get(hTag.hFig,'position');
                    screen_pos = GetMonitorPosition(Pos2Rect(mlmainmenu));
                    w = 593 ; h = 165;
                    x = mlmainmenu(1);
                    y = mlmainmenu(2) - h - 30;
                    if x < screen_pos(1), x = screen_pos(1); end
                    screen_right = screen_pos(1) + screen_pos(3) - w;
                    if screen_right < x, x = screen_right; end
                    if y < screen_pos(2), y = screen_pos(2); end
                    hTag.hTask = figure;
                    set(hTag.hTask,'units','pixels','position',[x y w h],'tag','TaskSettingWindow','closerequestfcn',@close_task_setting,'menubar','none','numbertitle','off','name','Task Settings','color',figure_bgcolor);
                    menu_task(5,163);
                    set(hTag.TaskSetting,'string','Close');
                else
                    close(hTag.hTask);
                end
        end
        error_handler(err);
        update_UI();
    end

    function DlgChartBlocks()
        cvals = fi(isscalar(MLConditions.UIVars.TimingFiles),1,linspace(0.5,1.5,length(MLConditions.UIVars.TimingFiles)));
        numblocks = length(MLConditions.UIVars.BlockList);
        numconds = length(MLConditions.Conditions);
        bc = NaN(numblocks+1,numconds+1);
        for bnum = 1:numblocks
            usedconds = false(1,numconds);
            for cnum = 1:numconds, usedconds(cnum) = any(bnum==MLConditions.Conditions(cnum).Block); end
            bc(bnum,usedconds) = cvals(MLConditions.UIVars.TimingFilesNo(usedconds));
        end

        w = 635 ; h = 480;
        xymouse = pointerlocation(hTag.ChartBlocks);
        x = xymouse(1);
        y = xymouse(2) - h/2;

        hDlg = figure;
        try
            bgcolor = [0.9255 0.9137 0.8471];
            set(hDlg,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','Block chart','color',bgcolor,'windowstyle','modal');

            h = pcolor(bc);
            set(h,'buttondownfcn',@dlg_proc);
            caxis([0 2]); %#ok<CAXIS>
            yspace = ceil(numblocks/10);
            xspace = ceil(numconds/10);
            yticks = 1:yspace:numblocks;
            xticks = 1:xspace:numconds;
            if numconds*numblocks > 1000
                shading('flat');
            else
                shading('faceted');
            end
            set(gca,'units','pixels','position',[50 50 360 360],'xtick',1.5:xspace:numconds+0.5,'ytick',1.5:yspace:numblocks+0.5,'xticklabel',xticks,'yticklabel',yticks,'ydir','reverse','xaxislocation','top');
            h(1) = xlabel('Condition #');
            h(2) = ylabel('Block #');
            set(h,'fontsize',12,'fontweight','bold');

            uicontrol('parent',hDlg,'style','text','position',[425 385 200 60],'string',['Click on a condition to the left' newline 'for details'],'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
            tag(1) = uicontrol('parent',hDlg,'style','listbox','position',[425 50 200 360],'tag','taskobjects','string','TaskObject List...','fontsize',fontsize);
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-90 10 80 25],'tag','done','string','Done','fontsize',fontsize,'callback',@dlg_proc);

            exit_code = 0; dlg_wait();
        catch err
            warning_handler(err);
        end
        if ishandle(hDlg), close(hDlg); end

        function dlg_wait()
            kbdflush;
            while 0==exit_code
                if ~ishandle(hDlg), exit_code = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, exit_code = -1; end
                pause(0.05);
            end
        end
        function dlg_proc(hObject,~)
            switch get(hObject,'tag')
                case 'done', exit_code = 1;
                otherwise
                    cp = get(gca, 'currentpoint');
                    cond = max(1,min(floor(cp(1,1)),length(MLConditions.Conditions)));
                    label{1} = sprintf('Condition #%d',cond);
                    label{2} = sprintf('Timing File: %s',MLConditions.Conditions(cond).TimingFile);
                    label{3} = sprintf('Relative Frequency: %d',MLConditions.Conditions(cond).Frequency);
                    label{4} = '';
                    taskobj =  {MLConditions.Conditions(cond).TaskObject.Label};
                    for m = 1:length(taskobj)
                        label{m+4} = sprintf('%d: %s',m,taskobj{m});
                    end
                    set(tag(1),'string',label);
            end
        end
    end

    function val = DlgChooseBlock(old_val,bBlocksToRun)
        if ~exist('old_val','var'), old_val = []; end
        w = 155 ; h = 180;
        xymouse = pointerlocation(hTag.ChooseBlocksToRun);
        x = xymouse(1) - w;
        y = xymouse(2);

        hDlg = figure;
        try
            bgcolor = [0.9255 0.9137 0.8471];
            set(hDlg,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','Reward variables','color',bgcolor,'windowstyle','modal');

            blocks = MLConditions.UIVars.BlockList;
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-140 10 60 25],'tag','done','string','Done','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-70 10 60 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','text','position',[0 45 155 126],'string',fi(bBlocksToRun,'Blocks to Run','First Block'),'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
            if bBlocksToRun, selected = find(ismember(blocks,old_val)); else, selected = fi(isempty(old_val),0,find(ismember(blocks,old_val))) + 1; end
            hlist = uicontrol('parent',hDlg,'style','listbox','position',[50 45 60 106],'min',0,'max',fi(bBlocksToRun,2,1),'string',fi(bBlocksToRun,num2cell(blocks),['TBD' num2cell(blocks)]),'value',selected,'fontsize',fontsize);

            exit_code = 0; dlg_wait();
            if 1==exit_code
                if bBlocksToRun, val = blocks(get(hlist,'value')); else, val = get(hlist,'value'); if 1<val, val = blocks(val-1); else, val = []; end, end
            else
                val = old_val;
            end
        catch
            val = old_val;
        end
        if ishandle(hDlg), close(hDlg); end

        function dlg_wait()
            kbdflush;
            while 0==exit_code
                if ~ishandle(hDlg), exit_code = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, exit_code = -1; end
                pause(0.05);
            end
        end
        function dlg_proc(hObject,~)
            switch get(hObject,'tag')
                case 'done', exit_code = 1;
                case 'cancel', exit_code = -1;
            end
        end
    end

    function [config_by_subject,filename,filepath] = DlgSelectConfig()
        [filename,filepath] = uigetfile({'*_cfg2.mat','MonkeyLogic Configuration'},'Select a config file');
        config_by_subject = '';
        if 0~=filename
            err = [];
            try
                a = whos('-file',[filepath filename]);
                b = regexp({a.name},'MLConfig_(\S+)','tokens');
                b = b(~cellfun(@isempty,b));

                if isempty(b)  % There is only one config, which is MLConfig. Just load it.
                    config_by_subject = 'MLConfig';
                else
                    nb = length(b);
                    c = cell(1,nb); for m=1:length(b), c{m} = regexprep(b{m}{1}{1},'(^\S)','${upper($1)}'); end

                    w = 250 ; h = 200 + nb*16;
                    pos = get(hTag.hFig,'Position');
                    pos = pos(1:2) + pos(3:4)/2;
                    x = pos(1) - w/2;
                    y = pos(2) - h/2;

                    hDlg = figure;
                    try
                        bgcolor = [0.9255 0.9137 0.8471];
                        set(hDlg,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','Choose the config to import','color',bgcolor,'windowstyle','modal');

                        uicontrol('parent',hDlg,'style','pushbutton','position',[w-160 10 70 25],'tag','done','string','Done','fontsize',fontsize,'callback',@dlg_proc);
                        uicontrol('parent',hDlg,'style','pushbutton','position',[w-80 10 70 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',@dlg_proc);
                        uicontrol('parent',hDlg,'style','text','position',[10 h-30 230 25],'string','Choose a configuration to import','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
                        tag(1) = uicontrol('parent',hDlg,'style','listbox','position',[10 48 230 125+nb*16],'tag','ConfigList','string',c,'fontsize',fontsize);

                        exit_code = 0; dlg_wait();
                        if 1==exit_code, config_by_subject = ['MLConfig_' b{get(tag(1),'value')}{1}{1}]; end
                    catch err
                    end
                    if ishandle(hDlg), close(hDlg); end
                end
            catch err
            end
            warning_handler(err);
        end

        function dlg_wait()
            kbdflush;
            while 0==exit_code
                if ~ishandle(hDlg), exit_code = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, exit_code = -1; end
                pause(0.05);
            end
        end
        function dlg_proc(hObject,~)
            switch get(hObject,'tag')
                case 'done', exit_code = 1;
                case 'cancel', exit_code = -1;
            end
        end
    end

    function DlgStrobePulseSpec()
        w = 435 ; h = 305;
        xymouse = pointerlocation(hTag.StrobePulseSpec);
        x = xymouse(1) - w;
        y = xymouse(2);

        hDlg = figure;
        try
            bgcolor = [0.9255 0.9137 0.8471];
            set(hDlg,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','Strobe timing specification','color',bgcolor,'windowstyle','modal');

            load('mlimagedata.mat','strobe_timing');
            uicontrol('style','pushbutton','position',[0 0 265 305],'tag','StrobeTiming','enable','inactive','cdata',strobe_timing);
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-160 10 70 25],'tag','done','string','Done','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-80 10 70 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','text','position',[280 260 20 25],'string','T1','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
            uicontrol('parent',hDlg,'style','text','position',[280 230 20 25],'string','T2','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
            tag(1) = uicontrol('parent',hDlg,'style','edit','position',[310 260+4 50 25],'tag','T1','string',num2str(MLConfig.StrobePulseSpec.T1),'fontsize',fontsize);
            tag(2) = uicontrol('parent',hDlg,'style','edit','position',[310 230+4 50 25],'tag','T2','string',num2str(MLConfig.StrobePulseSpec.T2),'fontsize',fontsize);
            microseconds = [char(956) 's'];
            uicontrol('parent',hDlg,'style','text','position',[365 260 40 25],'string',microseconds,'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hDlg,'style','text','position',[365 230 40 25],'string',microseconds,'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hDlg,'style','pushbutton','position',[280 200 90 25],'tag','reset','string','Set default','fontsize',fontsize,'callback',@dlg_proc);

            exit_code = 0; dlg_wait();
            if 1==exit_code
                MLConfig.StrobePulseSpec.T1 = str2double(get(tag(1),'string'));
                MLConfig.StrobePulseSpec.T2 = str2double(get(tag(2),'string'));
            end
        catch err
            warning_handler(err);
        end
        if ishandle(hDlg), close(hDlg); end

        function dlg_wait()
            kbdflush;
            while 0==exit_code
                if ~ishandle(hDlg), exit_code = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, exit_code = -1; end
                pause(0.05);
            end
        end
        function dlg_proc(hObject,~)
            switch get(hObject,'tag')
                case 'done', exit_code = 1;
                case 'cancel', exit_code = -1;
                case 'reset', set(tag,'string','125');
            end
        end
    end

    function DlgRewardTest()
        w = 270 ; h = 275;
        xymouse = pointerlocation(hTag.RewardTest);
        x = xymouse(1) - w;
        y = xymouse(2);
        r = MLConfig.RewardFuncArgs;

        hDlg = figure;
        try
            bgcolor = [0.9255 0.9137 0.8471];
            set(hDlg,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','Reward variables','color',bgcolor,'windowstyle','modal');

            x = 10;
            y = h - 40;
            uicontrol('parent',hDlg,'style','text','position',[x y 120 25],'string','JuiceLine','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            tag(1) = uicontrol('parent',hDlg,'style','edit','position',[x+130 y+3 120 25],'tag','RewardJuiceLine','string',num2str(r.JuiceLine),'fontsize',fontsize);
            y = y - 30;
            uicontrol('parent',hDlg,'style','text','position',[x y 120 25],'string','Duration (ms)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            tag(2) = uicontrol('parent',hDlg,'style','edit','position',[x+130 y+3 120 25],'tag','RewardDuration','string',num2str(r.Duration),'fontsize',fontsize);
            y = y - 30;
            uicontrol('parent',hDlg,'style','text','position',[x y 120 25],'string','Number of Pulses','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            tag(3) = uicontrol('parent',hDlg,'style','edit','position',[x+130 y+3 120 25],'tag','RewardNumReward','string',num2str(r.NumReward),'fontsize',fontsize);
            y = y - 30;
            uicontrol('parent',hDlg,'style','text','position',[x y 140 25],'string','Time b/w Pulses (ms)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            tag(4) = uicontrol('parent',hDlg,'style','edit','position',[x+130 y+3 120 25],'tag','RewardPauseTime','string',num2str(r.PauseTime),'fontsize',fontsize);
            y = y - 30;
            uicontrol('parent',hDlg,'style','text','position',[x y 120 25],'string','Trigger Voltage','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            tag(5) = uicontrol('parent',hDlg,'style','edit','position',[x+130 y+3 120 25],'tag','RewardTriggerVal','string',num2str(r.TriggerVal),'fontsize',fontsize);
            y = y - 30;
            uicontrol('parent',hDlg,'style','text','position',[x y 120 25],'string','Custom Variables','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            tag(6) = uicontrol('parent',hDlg,'style','edit','position',[x+130 y+3 120 25],'tag','RewardCustom','string',r.Custom,'fontsize',fontsize);
            y = y - 35;
            uicontrol('parent',hDlg,'style','pushbutton','position',[30 y 210 30],'tag','Trigger','string','Trigger','backgroundcolor',green_bgcolor,'fontsize',fontsize+2,'fontweight','bold','fontsize',fontsize,'callback',@dlg_proc);
            tag(7) = uicontrol('parent',hDlg,'style','pushbutton','position',[w-180 10 80 25],'tag','done','string','Done','fontsize',fontsize,'callback',@dlg_proc);
            tag(8) = uicontrol('parent',hDlg,'style','pushbutton','position',[w-90 10 80 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',@dlg_proc);

            exit_code = 0; dlg_wait();
            if 1==exit_code, MLConfig.RewardFuncArgs = update_from_controls(); end
        catch err
            warning_handler(err);
        end
        if ishandle(hDlg), close(hDlg); end

        function r = update_from_controls()
            str = get(tag(1),'string'); val = str2double(str); r.JuiceLine = fi(isnan(val),str,val);
            r.Duration = str2double(get(tag(2),'string'));
            r.NumReward = str2double(get(tag(3),'string'));
            r.PauseTime = str2double(get(tag(4),'string'));
            r.TriggerVal = str2double(get(tag(5),'string'));
            r.Custom = get(tag(6),'string');
        end
        function dlg_wait()
            kbdflush;
            while 0==exit_code
                if ~ishandle(hDlg), exit_code = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, exit_code = -1; end
                pause(0.05);
            end
        end
        function dlg_proc(hObject,~)
            switch get(hObject,'tag')
                case 'Trigger'
                    exit_code = 1; err = [];
                    try
                        set(gcbo,'string','Initializing...','backgroundcolor',purple_bgcolor,'enable','inactive'); drawnow;
                        set(tag(7),'enable','off');
                        set(tag(8),'string','Stop (ESC)');

                        r = update_from_controls();
                        MLConfig.RewardFuncArgs = r;
                        create(DAQ,MLConfig);
    
                        alertfunc = get_function_handle(MLPath.AlertFunction);
                        alert = ~isempty(alertfunc) && MLConfig.RemoteAlert;
                        if alert, TrialRecord = mltrialrecord; alertfunc('init',MLConfig,TrialRecord); end
    
                        if ~DAQ.reward_present, error('''Reward'' is not assigned in the I/O menu'); end
                        kbdflush;
                        for m=1:r.NumReward
                            DAQ.goodmonkey(r.Duration,'juiceline',r.JuiceLine,'numreward',1,'eval',r.Custom);
                            set(gcbo,'string',sprintf('%d / %d',m,r.NumReward)); drawnow;
                            fprintf('JuiceLine %s, Duration %d ms (%d/%d)\n',num2str(r.JuiceLine),r.Duration,m,r.NumReward);
                            ml_kb = kbdgetkey; if (~isempty(ml_kb) && 1==ml_kb) || 0==exit_code, mlmessage('Reward Test: aborted by user','e'); break, end
                            if m < r.NumReward, mdqmex(42,103,r.PauseTime); end
                        end
    
                        if alert, alertfunc('fini',MLConfig,TrialRecord); end
                    catch err
                    end
                    destroy(DAQ);
                    set(gcbo,'string','Trigger','backgroundcolor',green_bgcolor,'enable','on');
                    set(tag(7),'enable','on');
                    set(tag(8),'string','Cancel'); drawnow;
                    exit_code = 0;
                    error_handler(err);
                case 'done', exit_code = 1;
                case 'cancel', exit_code = fi(0<exit_code,0,-1);
            end
        end
    end

    function DlgOtherDeviceSettings()
        AudioEngine = struct('ID',1,'Device',1','Format',1);
        try
            [AudioEngine.ID,AudioEngine.Device,AudioEngine.Format,deviceName,formatString,info] = mglaudioengine(MLConfig.AudioEngine.ID,MLConfig.AudioEngine.Device,MLConfig.AudioEngine.Format);
        catch
            deviceName = 'No device detected'; formatString = 'No device detected'; info = [];
        end
        audio_engine = {'XAudio2','WASAPI Shared (AC3)','WASAPI Exclusive'};
        audio_engine_idx = [1 2 3];
        if isempty(info) || 0==info.NumWasapiDevice, audio_engine([2 3]) = []; audio_engine_idx([2 3]) = []; end
        media_root = [getenv('SystemRoot') filesep 'Media' filesep];
        test_sound = [media_root 'Alarm01.wav'];
        if ~exist(test_sound,'file'), test_sound = [media_root 'notify.wav']; end

        hwinfo = daqhwinfo('all');
        hfreqid = {'None','',''}; for m=1:length(IOBoard), if ~strcmp(IOBoard(m).Adaptor,'winsound') && any(strcmp(IOBoard(m).Subsystem,'AnalogInput')), hfreqid(end+1,:) = {IOBoard(m).DevString,IOBoard(m).Adaptor,IOBoard(m).DevID}; end, end
        eyeid = {'None',''; 'My EyeTracker','myeye'; 'Arrington ViewPoint (via client)','viewpoint'; 'Arrington ViewPoint VPX2 (direct connection)','vpx2'; 'SR Research EyeLink','eyelink'; 'ISCAN Eye Tracker','iscan'; 'Thomas RECORDING TOM-rs','tomrs'; 'Tobii Pro','tobii'};
        joyid = {'None',''}; if any(strcmpi('joystick',hwinfo)), info = daqhwinfo('joystick'); for m=length(info.InstalledBoardIds):-1:1, joyid(m+1,:) = {sprintf('%s: %s',info.InstalledBoardIds{m},info.BoardNames{m}),info.InstalledBoardIds{m}}; end, end
        camid = {'None',''}; if any(strcmpi('webcam',hwinfo)), info = daqhwinfo('webcam'); for m=length(info.InstalledBoardIds):-1:1, camid(m+1,:) = {sprintf('%s: %s',info.InstalledBoardIds{m},info.BoardNames{m}),info.InstalledBoardIds{m}}; end, end
        comid = {'None',''}; if any(strcmpi('serial',hwinfo)), info = daqhwinfo('serial'); for m=length(info.InstalledBoardIds):-1:1, comid(m+1,:) = {info.BoardNames{m},info.InstalledBoardIds{m}}; end, end
        if ~isempty(MLConfig.SerialPort.Port) && ~strncmpi(MLConfig.SerialPort.Port,'COM',3)
            if verLessThan('matlab','9.7')
                warning('This MATLAB version does not support BLE devices!');
            else
                comid(end+1,:) = {sprintf('BLE:%s (%s)',MLConfig.SerialPort.Parity,MLConfig.SerialPort.Port),MLConfig.SerialPort.Port};
            end
        end
        voiceid = {'None',''}; if any(strcmpi('wasapi',hwinfo)), info = daqhwinfo('wasapi'); for m=length(info.InstalledBoardIds):-1:1, voiceid(m+1,:) = {sprintf('%s: %s',info.InstalledBoardIds{m},info.BoardNames{m}),info.InstalledBoardIds{m}}; end, end
        hDev = struct;

        hDlg = findobj('tag','DlgOtherDeviceSettings');
        if isempty(hDlg)
            xymouse = pointerlocation(hTag.OtherDeviceSettings);
            pos = [0 0 375 620];
            pos(1) = xymouse(1) - pos(3);
            pos(2) = xymouse(2) - 290;
        else
            pos = get(hDlg,'position');
            close(hDlg);
        end

        hDlg = figure;
        try
            bgcolor = [0.9255 0.9137 0.8471];
            set(hDlg,'tag','DlgOtherDeviceSettings','units','pixels','position',pos,'menubar','none','numbertitle','off','name','Other device settings','color',bgcolor,'windowstyle','modal','resize','off');
            callback = @dlg_proc;

            x0 = 10; y0 = pos(4)-40;
            uicontrol('parent',hDlg,'style','text','position',[x0 y0 200 25],'string','Audio Engine','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hDev.AudioEngine(1) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+95 y0+7 165 22],'string',audio_engine,'value',fi(isempty(info),1,AudioEngine.ID),'fontsize',fontsize,'callback',callback);
            hDev.AudioEngine(6) = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+270 y0+5 25 25],'string','...','fontsize',fontsize,'callback','system(''mmsys.cpl'');');
            hDev.AudioEngine(7) = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+300 y0+5 25 25],'tag','PlaySound','enable',fi(exist(test_sound,'file'),'on','off'),'cdata',play_button,'callback',callback,'tooltip','Play a test sound');
            hDev.ReloadDeviceList = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+335 y0+9 17 17],'tag','RefreshDev','cdata',refresh_icon,'callback',callback,'tooltip','Reload device lists (F5)');

            y0 = y0-27;
            uicontrol('parent',hDlg,'style','text','position',[x0+45 y0+3 45 22],'string','Device','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
            hDev.AudioEngine(2) = uicontrol('parent',hDlg,'style','edit','position',[x0+95 y0+7 230 22],'string',deviceName,'enable','inactive','fontsize',fontsize);
            hDev.AudioEngine(3) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+95 y0+7 230 22],'string',deviceName,'value',fi(isempty(info),1,AudioEngine.Device),'fontsize',fontsize,'callback',callback);
            hDev.AudioEngine(8) = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+330 y0+6 25 25],'tag','SoundDriver','string','...','fontsize',fontsize,'callback',callback);

            y0 = y0-27;
            uicontrol('parent',hDlg,'style','text','position',[x0+45 y0+3 45 22],'string','Format','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
            hDev.AudioEngine(4) = uicontrol('parent',hDlg,'style','edit','position',[x0+95 y0+7 230 22],'string',formatString,'enable','inactive','fontsize',fontsize);
            hDev.AudioEngine(5) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+95 y0+7 230 22],'string',formatString,'value',AudioEngine.Format,'fontsize',fontsize,'callback',callback);

            y0 = y0-35;
            uicontrol('parent',hDlg,'style','text','position',[x0 y0 200 25],'string','High-freq Sampling','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hDev.HighFrequencyDAQ(1) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+125 y0+7 135 22],'string',hfreqid(:,1),'fontsize',fontsize,'callback',callback);
            hDev.HighFrequencyDAQ(2) = uicontrol('parent',hDlg,'style','edit','position',[x0+270 y0+6 55 22],'tag','HFSampleRate','fontsize',fontsize,'callback',callback);
            uicontrol('parent',hDlg,'style','text','position',[x0+330 y0 30 25],'string','Hz','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');

            y0 = y0-30;
            uicontrol('parent',hDlg,'style','text','position',[x0 y0 200 25],'string','Mouse / Key','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hDev.MouseKey(1) = uicontrol('parent',hDlg,'style','checkbox','position',[x0+125 y0+10 15 15],'value',MLConfig.MouseKey.Mouse,'backgroundcolor',bgcolor,'callback',callback);
            uicontrol('parent',hDlg,'style','text','position',[x0+160 y0 80 25],'string','Key code','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hDev.MouseKey(2) = uicontrol('parent',hDlg,'style','edit','position',[x0+218 y0+6 107 22],'string',num2str(MLConfig.MouseKey.KeyCode),'fontsize',fontsize,'horizontalalignment','left','tooltip','Space-separated numbers');
            hDev.MouseKey(3) = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+330 y0+5 25 25],'string','...','fontsize',fontsize,'callback',['web(''' MLPath.DocDirectory 'docs_KeycodeTable.html'',''-browser'')'],'tooltip','Open the key code table');

            y0 = y0-30;
            uicontrol('parent',hDlg,'style','text','position',[x0 y0 200 25],'string','Touchscreen','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hDev.Touchscreen(1) = uicontrol('parent',hDlg,'style','checkbox','position',[x0+125 y0+10 15 15],'value',MLConfig.Touchscreen.On,'backgroundcolor',bgcolor,'callback',callback);
            uicontrol('parent',hDlg,'style','text','position',[x0+160 y0 80 25],'string','Multi-touch','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hDev.Touchscreen(2) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+230 y0+7 40 22],'string',1:10,'value',MLConfig.Touchscreen.NumTouch,'fontsize',fontsize);
            uicontrol('parent',hDlg,'style','pushbutton','position',[x0+330 y0+5 25 25],'string','...','fontsize',fontsize,'callback','system(''control'');');

            y0 = y0-30;
            uicontrol('parent',hDlg,'style','text','position',[x0 y0 200 25],'string','USB / Network','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hDlg,'style','text','position',[x0+15 y0-15 200 25],'string','Joystick','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            for m=1:length(MLConfig.USBJoystick)
                uicontrol('parent',hDlg,'style','text','position',[x0+95 y0 30 25],'string',sprintf('#%d',m),'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                hDev.USBJoystick(m,1) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+125 y0+7 200 22],'tag',sprintf('JoystickList%d',m),'string',joyid(:,1),'fontsize',fontsize,'callback',callback);
                hDev.USBJoystick(m,2) = uicontrol('parent',hDlg,'style','pushbutton','position', [x0+330 y0+6 25 25],'tag',sprintf('JoystickSetu%d',m),'string','...','fontsize',fontsize,'callback',callback);
                y0 = y0-30;
            end

            y0 = y0-5; y1 = y0+7;
            uicontrol('parent',hDlg,'style','text','position',[x0 y0 200 25],'string','Webcam','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hDlg,'style','text','position',[x0+95 y0 50 25],'string','Export','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hDev.WebcamExportAs = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+140 y1 185 22],'tag','WebcamExportAs','string',{'to data file (no compression)','to data file (MP4)','as separate files (MP4)'},'value',MLConfig.WebcamExportAs,'fontsize',fontsize,'callback',callback);
            y0 = y0-30; y1 = y1-30;
            for m=1:length(MLConfig.Webcam)
                uicontrol('parent',hDlg,'style','text','position',[x0+95 y0 30 25],'string',sprintf('#%d',m),'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                hDev.Webcam(m,1) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+125 y1 200 22],'tag',sprintf('WebcamList%d',m),'string',camid(:,1),'fontsize',fontsize,'callback',callback);
                hDev.Webcam(m,2) = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+330 y1-2 25 25],'tag',sprintf('WebcamSetup%d',m),'string','...','fontsize',fontsize,'callback',callback);
                y0 = y0-30; y1 = y1-30;
            end

            y0 = y0-5;
            uicontrol('parent',hDlg,'style','text','position',[x0 y0 200 25],'string','TCP/IP Eye Tracker','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hDev.EyeTracker(1) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+125 y0+8 200 22],'string',eyeid(:,1),'fontsize',fontsize,'callback',callback);
            hDev.EyeTracker(2) = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+330 y0+6 25 25],'tag','EyeTrackerSetup','string','...','fontsize',fontsize,'callback',callback);

            y0 = y0-30;
            uicontrol('parent',hDlg,'style','text','position',[x0 y0 200 25],'string','Arduino for Reward','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hDev.SerialPort(1) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+125 y0+8 200 22],'string',comid(:,1),'fontsize',fontsize,'callback',callback);
            hDev.SerialPort(2) = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+330 y0+6 25 25],'tag','SerialPortSetup','string','...','fontsize',fontsize,'callback',callback);

            y0 = y0-30;
            uicontrol('parent',hDlg,'style','text','position',[x0 y0 200 25],'string','Voice Recording','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hDev.VoiceRecording(1) = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+125 y0+8 200 22],'string',voiceid(:,1),'fontsize',fontsize,'callback',callback);
            hDev.VoiceRecording(2) = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+330 y0+6 25 25],'tag','VoiceRecordingSetup','string','...','fontsize',fontsize,'callback',callback);

            y0 = y0-30;
            uicontrol('parent',hDlg,'style','text','position',[x0 y0 200 25],'string','Lab Streaming Layer','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hDev.LabStreamingLayer(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+125 y0+8 200 22],'enable','inactive','fontsize',fontsize,'callback',callback);
            hDev.LabStreamingLayer(2) = uicontrol('parent',hDlg,'style','pushbutton','position',[x0+330 y0+6 25 25],'tag','LabStreamingLayer','string','...','fontsize',fontsize,'callback',callback);

            uicontrol('parent',hDlg,'style','text','position',[20 60 pos(3) 25],'string','* These devices have priority over voltage-generating devices','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            uicontrol('parent',hDlg,'style','text','position',[30 40 pos(3) 25],'string','that are connected to the DAQ board.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            uicontrol('parent',hDlg,'style','pushbutton','position',[pos(3)-160 10 70 25],'tag','done','string','Done','fontsize',fontsize,'callback',callback);
            uicontrol('parent',hDlg,'style','pushbutton','position',[pos(3)-80 10 70 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',callback);

            idx = find(strcmp(MLConfig.HighFrequencyDAQ.Adaptor,hfreqid(:,2))&strcmp(MLConfig.HighFrequencyDAQ.DevID,hfreqid(:,3)),1);
            if ~isempty(idx), set(hDev.HighFrequencyDAQ(1),'value',idx); end
            set(hDev.HighFrequencyDAQ(2),'string',MLConfig.HighFrequencyDAQ.SampleRate);
            for m=1:length(MLConfig.USBJoystick)
                if 1<m
                    items = get(hDev.USBJoystick(m-1,1),'string');
                    val = get(hDev.USBJoystick(m-1,1),'value');
                    if 1<val, items(val) = []; end
                    set(hDev.USBJoystick(m,1),'string',items);
                end
                MLConfig.USBJoystick(m).ID = set_selected_id(hDev.USBJoystick(m,1),MLConfig.USBJoystick(m).ID,joyid);
            end
            hDev.USBJoystickProperty = MLConfig.USBJoystick;
            for m=1:length(MLConfig.Webcam)
                if 1<m
                    items = get(hDev.Webcam(m-1,1),'string');
                    val = get(hDev.Webcam(m-1,1),'value');
                    if 1<val, items(val) = []; end
                    set(hDev.Webcam(m,1),'string',items);
                end
                MLConfig.Webcam(m).ID = set_selected_id(hDev.Webcam(m,1),MLConfig.Webcam(m).ID,camid);
            end
            hDev.WebcamProperty = MLConfig.Webcam;
            MLConfig.EyeTracker.ID = set_selected_id(hDev.EyeTracker(1),MLConfig.EyeTracker.ID,eyeid);
            hDev.EyeTrackerProperty = MLConfig.EyeTracker;
            MLConfig.SerialPort.Port = set_selected_id(hDev.SerialPort(1),MLConfig.SerialPort.Port,comid);
            hDev.SerialPortProperty = MLConfig.SerialPort;
            MLConfig.VoiceRecording.ID = set_selected_id(hDev.VoiceRecording(1),MLConfig.VoiceRecording.ID,voiceid);
            hDev.VoiceRecordingProperty = MLConfig.VoiceRecording;
            hDev.LabStreamingLayerProperty = MLConfig.LabStreamingLayer;
            dlg_update();

            exit_code = 0; dlg_wait();
            if 1==exit_code
                try
                    [MLConfig.AudioEngine.ID,MLConfig.AudioEngine.Device,MLConfig.AudioEngine.Format,deviceName,formatString,info] = mglaudioengine(audio_engine_idx(get(hDev.AudioEngine(1),'value')),get(hDev.AudioEngine(3),'value'),get(hDev.AudioEngine(5),'value'));
                    switch MLConfig.AudioEngine.ID
                        case 1, MLConfig.AudioEngine.DeviceDesc = deviceName; MLConfig.AudioEngine.FormatDesc = formatString;
                        case 2, MLConfig.AudioEngine.DeviceDesc = deviceName{MLConfig.AudioEngine.Device}; MLConfig.AudioEngine.FormatDesc = formatString;
                        case 3, MLConfig.AudioEngine.DeviceDesc = deviceName{MLConfig.AudioEngine.Device}; MLConfig.AudioEngine.FormatDesc = formatString{MLConfig.AudioEngine.Format};
                    end
                    MLConfig.AudioEngine.DriverInfo = info;
                catch
                end
                idx = get(hDev.HighFrequencyDAQ(1),'value');
                MLConfig.HighFrequencyDAQ.Adaptor = fi(1==idx,[],hfreqid{idx,2});
                MLConfig.HighFrequencyDAQ.DevID = fi(1==idx,[],hfreqid{idx,3});
                val = str2double(get(hDev.HighFrequencyDAQ(2),'string'));
                MLConfig.HighFrequencyDAQ.SampleRate = fi(isnan(val),[],val);
                MLConfig.MouseKey.Mouse = logical(get(hDev.MouseKey(1),'value'));
                MLConfig.MouseKey.KeyCode = str2num(get(hDev.MouseKey(2),'string')); %#ok<ST2NM>
                MLConfig.Touchscreen.On = logical(get(hDev.Touchscreen(1),'value'));
                MLConfig.Touchscreen.NumTouch = get(hDev.Touchscreen(2),'value');
                MLConfig.USBJoystick = hDev.USBJoystickProperty;
                for m=1:length(MLConfig.USBJoystick)
                    MLConfig.USBJoystick(m).ID = get_selected_id(hDev.USBJoystick(m,1),joyid);
                end
                MLConfig.WebcamExportAs = get(hDev.WebcamExportAs,'value');
                for m=1:length(MLConfig.Webcam)
                    MLConfig.Webcam(m).ID = get_selected_id(hDev.Webcam(m,1),camid);
                    MLConfig.Webcam(m).Property = hDev.WebcamProperty(m).Property;
                end
                MLConfig.EyeTracker = hDev.EyeTrackerProperty;
                MLConfig.EyeTracker.Name = get_listbox_item(hDev.EyeTracker(1));
                MLConfig.EyeTracker.ID = get_selected_id(hDev.EyeTracker(1),eyeid);
                MLConfig.SerialPort = hDev.SerialPortProperty;
                MLConfig.SerialPort.Port = get_selected_id(hDev.SerialPort(1),comid);
                str = get_listbox_item(hDev.SerialPort(1)); if strncmp(str,'BLE',3), MLConfig.SerialPort.Parity = str(5:find('('==str,1,'last')-2); end
                MLConfig.VoiceRecording = hDev.VoiceRecordingProperty;
                MLConfig.VoiceRecording.ID = get_selected_id(hDev.VoiceRecording(1),voiceid);
                MLConfig.LabStreamingLayer = hDev.LabStreamingLayerProperty;
            end
        catch err
            warning_handler(err);
        end
        if ishandle(hDlg), close(hDlg); end

        function refresh_devices()
            err = [];
            try
                set(hDev.ReloadDeviceList,'enable','inactive','cdata',refresh_active); drawnow;
                mglreset; if ~isempty(hTag.hVideo), set(hTag.SubjectScreenDevice,'string',num2cell(1:System.NumberOfScreenDevices),'value',min(get(hTag.SubjectScreenDevice,'value'),System.NumberOfScreenDevices)); end
                daqreset; refresh_boards();
            catch err
            end
            DlgOtherDeviceSettings();
            error_handler(err);
        end
        function str = set_selected_id(h,id,ids)
            items = get(h,'string');
            val = find(strcmp(id,ids(:,2)),1);
            if isempty(val), val = 1; end
            str = ids{val,2};
            val = find(strcmp(ids{val,1},items),1);
            if isempty(val), val = 1; end
            set(h,'value',val);
        end
        function str = get_selected_id(h,ids)
            items = get(h,'string');
            val = find(strcmp(items(get(h,'value')),ids(:,1)),1);
            if isempty(val), val = 1; end
            str = ids{val,2};
        end
        function dlg_wait()
            kbdflush;
            while 0==exit_code
                if ~ishandle(hDlg), exit_code = -1; break, end
                kb = kbdgetkey();
                if ~isempty(kb)
                    switch(kb)
                        case 1, exit_code = -1;
                        case 63, refresh_devices();
                    end
                end
                pause(0.05);
            end
        end
        function dlg_proc(hObject,~)
            obj_tag = get(hObject,'tag');
            switch obj_tag(1:min(length(obj_tag),10))
                case 'done', exit_code = 1;
                case 'cancel', exit_code = -1;
                case 'RefreshDev', refresh_devices(); return
                case 'PlaySound'
                    try
                        set(gcbo,'enable','off'); drawnow;
                        id = mgladdsound(test_sound);
                        mglplaysound(id);
                        kbdinit; mouse = pointingdevice;
                        while mglgetproperty(id,'isplaying')
                            keypress = kbdgetkey; [~,button] = getsample(mouse);
                            if ~isempty(keypress) || any(button), break; end
                        end
                        mgldestroysound(id);
                    catch
                        % do nothing
                    end
                    set(gcbo,'enable','on');
                case 'SoundDrive'
                    [~,~,~,~,~,info] = mglaudioengine(audio_engine_idx(get(hDev.AudioEngine(1),'value')),get(hDev.AudioEngine(3),'value'),get(hDev.AudioEngine(5),'value'));
                    PopupSoundDriverInfo(info);
                case 'HFSampleRa'
                    val = str2double(get(gcbo,'string'));
                    set(gcbo,'string',fi(isnan(val),[],val));
                case 'JoystickLi'
                    no = str2double(regexp(obj_tag,'\d+','match'));
                    items = get(hDev.USBJoystick(no,1),'string');
                    val = get(hDev.USBJoystick(no,1),'value');
                    if 1<val, items(val) = []; end
                    for n=no+1:length(MLConfig.USBJoystick), set(hDev.USBJoystick(n,1),'string',items,'value',1); end
                case 'JoystickSe'
                    no = str2double(regexp(obj_tag,'\d+','match'));
                    hDev.USBJoystickProperty(no) = PopupUSBJoystickSetup(hDev.USBJoystickProperty(no),get_selected_id(hDev.USBJoystick(no,1),joyid));
                case 'WebcamList'
                    no = str2double(regexp(obj_tag,'\d+','match'));
                    items = get(hDev.Webcam(no,1),'string');
                    val = get(hDev.Webcam(no,1),'value');
                    if 1<val, items(val) = []; end
                    for n=no+1:length(MLConfig.Webcam), set(hDev.Webcam(n,1),'string',items,'value',1); end
                case 'WebcamSetu'
                    no = str2double(regexp(obj_tag,'\d+','match'));
                    hDev.WebcamProperty(no).Property = mlwebcamsetup(get_selected_id(hDev.Webcam(no),camid),hDev.WebcamProperty(no).Property);
                case 'EyeTracker'
                    try
                        hDev.EyeTrackerProperty = mleyetrackersetup(hDev.EyeTrackerProperty,eyeid(get(hDev.EyeTracker(1),'value'),:));
                    catch err
                        error_handler(err);
                    end
                case 'SerialPort'
                    prop = PopupBLESetup(hDev.SerialPortProperty);
                    if ~strcmp(hDev.SerialPortProperty.Port,prop.Port) || ~strcmp(hDev.SerialPortProperty.Parity,prop.Parity)
                        row = strncmp(comid(:,1),'BLE',3); comid(row,:) = [];
                        comid = [comid; {sprintf('BLE:%s (%s)',prop.Parity,prop.Port),prop.Port}];
                        set(hDev.SerialPort(1),'string',comid(:,1),'value',size(comid,1));
                    end
                    hDev.SerialPortProperty = prop;
                case 'VoiceRecor', hDev.VoiceRecordingProperty = PopupVoiceRecordingSetup(hDev.VoiceRecordingProperty);
                case 'LabStreami', hDev.LabStreamingLayerProperty = mllabstreaminglayersetup(hDev.LabStreamingLayerProperty);
            end
            dlg_update();
        end
        function dlg_update()
            try
                [AudioEngine.ID,AudioEngine.Device,AudioEngine.Format,deviceName,formatString] = mglaudioengine(audio_engine_idx(get(hDev.AudioEngine(1),'value')),get(hDev.AudioEngine(3),'value'),get(hDev.AudioEngine(5),'value'));
                set(hDev.AudioEngine(1),'value',find(audio_engine_idx == AudioEngine.ID,1));
                switch AudioEngine.ID
                    case 1
                        set(hDev.AudioEngine(2),'string',deviceName);
                        set(hDev.AudioEngine(4),'string',formatString);
                        set(hDev.AudioEngine([3 5]),'visible','off');
                        set(hDev.AudioEngine([2 4]),'visible','on');
                    case 2
                        set(hDev.AudioEngine(3),'string',deviceName,'value',AudioEngine.Device);
                        set(hDev.AudioEngine(4),'string',formatString);
                        set(hDev.AudioEngine([2 5]),'visible','off');
                        set(hDev.AudioEngine([3 4]),'visible','on');
                    case 3
                        set(hDev.AudioEngine(3),'string',deviceName,'value',AudioEngine.Device);
                        set(hDev.AudioEngine(5),'string',formatString,'value',AudioEngine.Format);
                        set(hDev.AudioEngine([2 4]),'visible','off');
                        set(hDev.AudioEngine([3 5]),'visible','on');
                end
            catch
                set(hDev.AudioEngine,'enable','off');
                set(hDev.AudioEngine([3 5]),'visible','off');
                set(hDev.AudioEngine([2 4]),'visible','on');
            end
            set(hDev.HighFrequencyDAQ,'enable',fi(size(hfreqid,1)<2,'off','on'));
            set(hDev.MouseKey(2),'enable',fi(get(hDev.MouseKey(1),'value'),'on','off'));
            set(hDev.Touchscreen(2),'enable',fi(get(hDev.Touchscreen(1),'value'),'on','off'));
            for n=1:size(hDev.USBJoystick,1)
                if 1<n, set(hDev.USBJoystick(n,1),'enable',fi(1==get(hDev.USBJoystick(n-1,1),'value'),'off','on')); end
                set(hDev.USBJoystick(n,2),'enable',fi(1==get(hDev.USBJoystick(n,1),'value'),'off','on'));
            end
            for n=1:size(hDev.Webcam,1)
                if 1<n, set(hDev.Webcam(n,1),'enable',fi(1==get(hDev.Webcam(n-1,1),'value'),'off','on')); end
                set(hDev.Webcam(n,2),'enable',fi(1==get(hDev.Webcam(n,1),'value'),'off','on'));
            end
            set(hDev.EyeTracker(2),'enable',fi(1==get(hDev.EyeTracker(1),'value'),'off','on'));
            set(hDev.SerialPort(2),'enable',fi(verLessThan('matlab','9.7'),'off','on'));
            set(hDev.VoiceRecording(2),'enable',fi(1==get(hDev.VoiceRecording(1),'value'),'off','on'));
            set(hDev.LabStreamingLayer(1),'string',sprintf('%d s, %d stream(s) selected',hDev.LabStreamingLayerProperty.BufferLength,sum(~cellfun(@isempty,hDev.LabStreamingLayerProperty.Stream(:,1)))));
        end
    end

    function PopupSoundDriverInfo(info)
        w = 300 ; h = 140;
        xymouse = pointerlocation('SoundDriver');
        x = xymouse(1) - w + 20;
        y = xymouse(2) - h - 10;
        bgcolor = figure_bgcolor;

        hPop = figure;
        set(hPop,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','Sound Driver Info','color',bgcolor,'windowstyle','modal');
        try
            x0 = 10; y0 = h-40;
            uicontrol('parent',hPop,'style','text','position',[x0 y0 80 25],'string','Driver','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hPop,'style','edit','position',[x0+70 y0+5 210 22],'string',info.Driver,'fontsize',fontsize);
            y0 = y0 - 30;
            uicontrol('parent',hPop,'style','text','position',[x0 y0 80 25],'string','Version','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hPop,'style','edit','position',[x0+70 y0+5 210 22],'string',info.DriverVersion,'fontsize',fontsize);
            y0 = y0 - 30;
            uicontrol('parent',hPop,'style','text','position',[x0 y0 80 25],'string','Date','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hPop,'style','edit','position',[x0+70 y0+5 210 22],'string',info.DriverDate,'fontsize',fontsize);
            y0 = y0 - 30;
            uicontrol('parent',hPop,'style','text','position',[x0 y0 80 25],'string','Provider','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hPop,'style','edit','position',[x0+70 y0+5 210 22],'string',info.DriverProvider,'fontsize',fontsize);

            pop_exit = 0; pop_wait();
        catch err
            warning_handler(err);
        end
        if ishandle(hPop), close(hPop); end

        function pop_wait()
            kbdflush;
            while 0==pop_exit
                if ~ishandle(hPop), pop_exit = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, pop_exit = -1; end
                pause(0.05);
            end
        end
    end

    function prop = PopupUSBJoystickSetup(prop, id)
        old_prop = prop;
        w = 200; h = 140;
        show_ip = 'off'; show_port = 'off'; show_test = 'off';
        if any(strcmp(id,{'C','D'})), show_ip = 'on'; show_test = 'on'; h = h + 30; end
        if any(strcmp(id,{'A','B','C','D'})), show_port = 'on'; show_test = 'on'; h = h + 30; end
        xymouse = pointerlocation('JoystickSetu1');
        x = xymouse(1) - w;
        y = xymouse(2);
        bgcolor = figure_bgcolor;
        callback = @pop_proc;

        hPop = figure; hc = [];
        set(hPop,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','Serial port configuration','color',bgcolor,'windowstyle','modal');
        try
            x0 = 10; y0 = h-40;
            uicontrol('parent',hPop,'style','text','position',[x0 y0 80 25],'string','# of buttons','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hc(1) = uicontrol('parent',hPop,'style','popupmenu','position',[x0+80 y0+5 50 22],'fontsize',fontsize);
            if strcmpi(show_ip,'on'), y0 = y0 - 30; end
            uicontrol('parent',hPop,'style','text','position',[x0 y0 80 25],'string','IP address','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left','visible',show_ip);
            hc(2) = uicontrol('parent',hPop,'style','edit','position',[x0+80 y0+5 100 22],'string',prop.IP_address,'fontsize',fontsize,'visible',show_ip);
            if strcmpi(show_port,'on'), y0 = y0 - 30; end
            uicontrol('parent',hPop,'style','text','position',[x0 y0 80 25],'string','Port','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left','visible',show_port);
            hc(3) = uicontrol('parent',hPop,'style','edit','position',[x0+80 y0+5 80 22],'string',prop.Port,'fontsize',fontsize,'visible',show_port);
            if  strcmpi(show_test,'on'), y0 = y0 - 30; end
            hc(4) = uicontrol('parent',hPop,'style','pushbutton','position',[x0 y0 120 25],'string','Connection Test','fontsize',fontsize,'callback',@test_joystick_connection,'visible',show_test);
            hc(5) = uicontrol('parent',hPop,'style','text','position',[x0+130 y0 50 22],'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','visible',show_test);
            uicontrol('parent',hPop,'style','pushbutton','position',[w-160 10 70 25],'tag','done','string','Done','fontsize',fontsize,'callback',callback);
            uicontrol('parent',hPop,'style','pushbutton','position',[w-80 10 70 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',callback);

            if ~isempty(id)
                try
                    hwInfo = daqhwinfo(pointingdevice('joystick',id));
                    set(hc(1),'string',0:hwInfo.Buttons,'value',min(hwInfo.Buttons,prop.NumButton)+1);
                catch
                    % do nothing
                end
            end

            pop_exit = 0; pop_wait();
            if 1==pop_exit
                prop.NumButton = get(hc(1),'value')-1;
                prop.IP_address = get(hc(2),'string');
                prop.Port = get(hc(3),'string');
            else
                prop = old_prop;
            end
        catch err
            warning_handler(err);
        end
        if ishandle(hPop), close(hPop); end

        function test_joystick_connection(varargin)
            set(hc(4),'enable','off');
            set(hc(5),'string',''); drawnow; pause(1);
            joy = pointingdevice('joystick',id);
            joy.setProperty('IP_address',get(hc(2),'string'));
            switch id
                case {'A','B'}
                    try
                        joy.setProperty('Port',get(hc(3),'string'));
                        tic;
                        while toc<2
                            packet_count = joy.getProperty('PacketCount');
                            connected = 0 < packet_count;
                            set(hc(5),'string',sprintf('%d',packet_count),'foregroundcolor',fi(connected,[0 1 0],[1 0 0]));
                            drawnow;
                        end
                    catch
                        connected = false;
                    end
                case {'C','D'}
                    try
                        joy.setProperty('Port',get(hc(3),'string'));
                        connected = joy.getProperty('Connected');
                    catch
                        connected = false;
                    end
                otherwise, error('Unknown network joystick type!!!');
            end
            set(hc(5),'string',fi(connected,'Success','Failed'),'foregroundcolor',fi(connected,[0 1 0],[1 0 0]));
            delete(joy);
            set(hc(4),'enable','on');
        end
        function pop_wait()
            kbdflush;
            while 0==pop_exit
                if ~ishandle(hPop), pop_exit = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, pop_exit = -1; end
                pause(0.05);
            end
        end
        function pop_proc(hObject,~)
            switch get(hObject,'tag')
                case 'done', pop_exit = 1;
                case 'cancel', pop_exit = -1;
            end
        end
    end

    function prop = PopupBLESetup(prop)
        old_prop = prop;
        timeout = [3 5 10 15 20];
        dev = [];

        w = 290 ; h = 150;
        xymouse = pointerlocation('SerialPortSetup');
        x = xymouse(1) - w;
        y = xymouse(2);
        bgcolor = figure_bgcolor;
        callback = @pop_proc;

        hPop = figure; hc = [];
        set(hPop,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','BLE device setup','color',bgcolor,'windowstyle','modal');
        
        err = [];
        try
            x0 = 10; y0 = h-50;
            uicontrol('parent',hPop,'style','text','position',[x0 y0 80 25],'string','Timeout','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hc(1) = uicontrol('parent',hPop,'style','popupmenu','position',[x0+70 y0+7 40 22],'string',timeout,'fontsize',fontsize);
            uicontrol('parent',hPop,'style','text','position',[x0+115 y0 50 25],'string','sec','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            uicontrol('parent',hPop,'style','pushbutton','position',[w-110 y0+2 100 30],'tag','SearchBLE','string','Search BLE','backgroundcolor',purple_bgcolor,'fontsize',fontsize,'fontweight','bold','callback',callback);
            y0 = y0 - 40;
            uicontrol('parent',hPop,'style','text','position',[x0 y0 80 25],'string','BLE device','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hc(2) = uicontrol('parent',hPop,'style','popupmenu','position',[x0+70 y0+8 200 22],'string','None','fontsize',fontsize);
            uicontrol('parent',hPop,'style','pushbutton','position',[w-160 10 70 25],'tag','done','string','Done','fontsize',fontsize,'callback',callback);
            uicontrol('parent',hPop,'style','pushbutton','position',[w-80 10 70 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',callback);

            pop_exit = 0; pop_wait();
            if 1==pop_exit
                if ~isempty(dev)
                    val = get(hc(2),'value');
                    prop.Port = char(dev{val,3});
                    prop.Parity = char(dev{val,2});
                end
            else
                prop = old_prop;
            end
        catch err
            warning_handler(err);
        end
        if ishandle(hPop), close(hPop); end

        function pop_wait()
            kbdflush;
            while 0==pop_exit
                if ~ishandle(hPop), pop_exit = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, pop_exit = -1; end
                pause(0.05);
            end
        end
        function pop_proc(hObject,~)
            switch get(hObject,'tag')
                case 'SearchBLE'
                    err = [];
                    try
                        set(gcbo,'string','Searching...','backgroundcolor',green_bgcolor); drawnow;
                        dev = blelist('Services','01951185-e572-7a1f-86b6-a20018e7dbf2','Timeout',timeout(get(hc(1),'value')));
                        ndev = size(dev,1); str = cell(ndev,1); for m=1:ndev, str{m} = sprintf('BLE:%s (%s)',dev{m,2:3}); end
                        set(hc(2),'string',fi(isempty(str),'No BLE device found',str));
                    catch err % do nothing
                    end
                    set(gcbo,'string','Search BLE','backgroundcolor',purple_bgcolor);
                    error_handler(err);
                case 'done', pop_exit = 1;
                case 'cancel', pop_exit = -1;
            end
        end
    end

    function prop = PopupVoiceRecordingSetup(prop)
        old_prop = prop;
        sample_rate = {11025,22050,32000,44100,48000};
        stereo = {'Mono','Stereo'};

        w = 210 ; h = 160;
        xymouse = pointerlocation('VoiceRecordingSetup');
        x = xymouse(1) - w;
        y = xymouse(2);
        bgcolor = figure_bgcolor;
        callback = @pop_proc;

        hPop = figure; hc = [];
        set(hPop,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','Voice recording configuration','color',bgcolor,'windowstyle','modal');
        try
            x0 = 10; y0 = h-40;
            uicontrol('parent',hPop,'style','text','position',[x0 y0 80 25],'string','Sample rate','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hc(1) = uicontrol('parent',hPop,'style','popupmenu','position',[x0+110 y0+5 80 22],'string',sample_rate,'value',find(cellfun(@(x)x==prop.SampleRate,sample_rate),1),'fontsize',fontsize);
            y0 = y0 - 30;
            uicontrol('parent',hPop,'style','text','position',[x0 y0 80 25],'string','Stereo','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hc(2) = uicontrol('parent',hPop,'style','popupmenu','position',[x0+110 y0+5 80 22],'string',stereo,'value',find(strcmpi(prop.Stereo,stereo),1),'fontsize',fontsize);
            y0 = y0 - 30;
            uicontrol('parent',hPop,'style','text','position',[x0 y0 150 25],'string','Exclusive mode','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hc(3) = uicontrol('parent',hPop,'style','checkbox','position',[x0+110 y0+10 15 15],'value',prop.Exclusive,'backgroundcolor',bgcolor);
            uicontrol('parent',hPop,'style','pushbutton','position',[w-160 10 70 25],'tag','done','string','Done','fontsize',fontsize,'callback',callback);
            uicontrol('parent',hPop,'style','pushbutton','position',[w-80 10 70 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',callback);

            pop_exit = 0; pop_wait();
            if 1==pop_exit
                prop.SampleRate = sample_rate{get(hc(1),'value')};
                prop.Stereo = stereo{get(hc(2),'value')};
                prop.Exclusive = get(hc(3),'value');
            else
                prop = old_prop;
            end
        catch err
            warning_handler(err);
        end
        if ishandle(hPop), close(hPop); end

        function pop_wait()
            kbdflush;
            while 0==pop_exit
                if ~ishandle(hPop), pop_exit = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, pop_exit = -1; end
                pause(0.05);
            end
        end
        function pop_proc(hObject,~)
            switch get(hObject,'tag')
                case 'done', pop_exit = 1;
                case 'cancel', pop_exit = -1;
            end
        end
    end

    function DIOInfo = DlgAssignDIOLine()
        DIOInfo = [];
        if 3~=io.Subsystem, return, end

        nport = length(io.Channel);
        npanel = 5;
        if 2 < ceil(nport/npanel), npanel = 10; end
        w = 100 + 55 * fi(0==floor(nport/npanel),nport,npanel) - 50 * fi(1==nport,0,1); h = 60 + 120 * ceil(nport/npanel);
        xymouse = pointerlocation(hTag.IOAssign);
        x = xymouse(1) - fi(325<w,w-325,w);
        y = xymouse(2) + 170 - h;

        hPop = figure;
        try
            bgcolor = [0.9255 0.9137 0.8471];
            set(hPop,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','Line panel','color',bgcolor,'windowstyle','modal');

            hListbox = zeros(1,nport);
            for m=1:nport
                x = w - 55 * mod(m-1,npanel) - 55; y = 45 + 120 * floor((m-1)/npanel);
                lines = IOBoard(io.Board).DIOInfo{io.Channel(m)+1,1};
                if 1==mod(m,5), uicontrol('parent',hPop,'style','text','position',[10 y+35 40 22],'string','Lines','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left'); end
                uicontrol('parent',hPop,'style','text','position',[x-5-45*fi(1==nport,1,0) y+90 55 22],'string',sprintf('Port%d',io.Channel(m)),'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
                hListbox(m) = uicontrol('parent',hPop,'style','listbox','position',[x-45*fi(1==nport,1,0) y 45 95],'string',num2cell(lines),'fontsize',fontsize,'min',0,'max',fi(1==io.Spec{3}(2),2,1));
            end
            uicontrol('parent',hPop,'style','pushbutton','position',[w-140 10 60 25],'tag','done','string','Done','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hPop,'style','pushbutton','position',[w-70 10 60 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',@dlg_proc);
            if 1<nport, uicontrol('parent',hPop,'style','text','position',[0 h-25 w 20],'string',fi(2==nport,'<- Most sig. bit | Least sig. bit ->','<- Most significant bit | Least significant bit ->'),'backgroundcolor',bgcolor,'fontsize',7); end

            exit_code = 0; dlg_wait();
            if 1==exit_code
                DIOInfo = cell(nport,2);
                for m=1:nport
                    str = get(hListbox(m),'string');
                    val = get(hListbox(m),'value');
                    DIOInfo{m,1} = cellfun(@str2double,str(val))';
                    DIOInfo{m,2} = fi(1==io.Spec{3}(1),'out','in');
                end
            end
        catch
            warning_handler(err);
        end
        if ishandle(hPop), close(hPop); end

        function dlg_wait()
            kbdflush;
            while 0==exit_code
                if ~ishandle(hPop), exit_code = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, exit_code = -1; end
                pause(0.05);
            end
        end
        function dlg_proc(hObject,~)
            switch get(hObject,'tag')
                case 'done', exit_code = 1;
                case 'cancel', exit_code = -1;
            end
        end
    end

    function valid = assign_IO(entry)
        valid = [];
        if ~isempty(entry)
            nentry = length(entry);
            valid = true(nentry,1);
            for m=1:nentry
                signaltype = find(strcmp(MLConfig.IOList(:,1),entry(m).SignalType),1);
                if isempty(signaltype), valid(m) = false; mlmessage('''%s'': no such signal type',entry(m).SignalType,'e'); continue, end
                board = find(strcmp({IOBoard.Adaptor},entry(m).Adaptor) & strcmp({IOBoard.DevID},entry(m).DevID),1);
                if isempty(board), valid(m) = false; mlmessage('''%s'': can''t find %s:%s',entry(m).SignalType,entry(m).Adaptor,entry(m).DevID,'e'); continue, end
                subsystem = find(strcmp(IOBoard(board).Subsystem,entry(m).Subsystem),1);
                if isempty(subsystem), valid(m) = false; mlmessage('''%s'': %s:%s doesn''t support %s',entry(m).SignalType,entry(m).Adaptor,entry(m).DevID,entry(m).Subsystem,'e'); continue, end
                subsystem = find(strcmp(entry(m).Subsystem,{'AnalogInput','AnalogOutput','DigitalIO'}),1);
                channels = IOBoard(board).Channel{subsystem};
                ch_str = fi(3==subsystem,'Port','Ch');
                no_chan = ~ismember(entry(m).Channel,channels);
                if any(no_chan), valid(m) = false; mlmessage(['''%s'': %s ' ch_str '%s doesn''t exist on %s:%s or is assigned already'],entry(m).SignalType,entry(m).Subsystem,sprintf(' %d',entry(m).Channel(no_chan)),entry(m).Adaptor,entry(m).DevID,'e'); continue, end
                if 3==subsystem
                    nport = length(entry(m).Channel);
                    for n=1:nport
                        no_line = ~ismember(entry(m).DIOInfo{n,1},IOBoard(board).DIOInfo{entry(m).Channel(n)+1,1});
                        if any(no_chan), valid(m) = false; mlmessage('''%s'': Port%d Line%s is(are) assigned already',entry(m).SignalType,entry(m).Channel,sprintf(' %d',entry(m).DIOInfo{n,1}(no_line)),'e'); break, end
                    end
                    if ~valid(m), continue, end

                    for n=1:nport
                        IOBoard(board).DIOInfo{entry(m).Channel(n)+1,1} = mlsetdiff(IOBoard(board).DIOInfo{entry(m).Channel(n)+1,1},entry(m).DIOInfo{n,1});
                        IOBoard(board).DIOInfo{entry(m).Channel(n)+1,2} = entry(m).DIOInfo{n,2};
                    end
                else
                    IOBoard(board).Channel{subsystem} = mlsetdiff(channels,entry(m).Channel);
                end
                IOName{signaltype} = ['{ ' fi(entry(m).Invert,'~','') MLConfig.IOList{signaltype,1} ' }'];
            end
        end
        if ~isempty(hTag.hIO), set(hTag.SignalType,'string',IOName); end
    end

    function clear_IO(signaltype,update)
        if ~exist('update','var'), update = true; end
        if ischar(signaltype), signaltype = {signaltype}; end
        nentry = length(signaltype);
        for m=1:nentry
            row = strcmp({MLConfig.IO.SignalType},signaltype{m});
            if ~any(row), continue, end

            board = find(strcmp({IOBoard.Adaptor},MLConfig.IO(row).Adaptor) & strcmp({IOBoard.DevID},MLConfig.IO(row).DevID),1);
            subsystem = find(strcmp(MLConfig.IO(row).Subsystem,{'AnalogInput','AnalogOutput','DigitalIO'}),1);
            channels = MLConfig.IO(row).Channel;
            IOBoard(board).Channel{subsystem} = union(IOBoard(board).Channel{subsystem},channels);
            if 3==subsystem
                for n=1:length(channels)
                    IOBoard(board).DIOInfo{channels(n)+1,1} = union(IOBoard(board).DIOInfo{channels(n)+1,1},MLConfig.IO(row).DIOInfo{n,1});
                    if length(IOBoard(board).DIOInfo{channels(n)+1,1})==IOBoard(board).DIOInfo{channels(n)+1,3}, IOBoard(board).DIOInfo{channels(n)+1,2} = IOBoard(board).DIOInfo{channels(n)+1,4}; end
                end
            end
            MLConfig.IO(row) = [];
            if isempty(MLConfig.IO), MLConfig.IO = []; end

            if update
                row = strcmp(MLConfig.IOList(:,1),signaltype{m});
                IOName{row} = MLConfig.IOList{row,1};
            end
        end
        if ~isempty(hTag.hIO), set(hTag.SignalType,'string',IOName); end
    end

    function refresh_boards(DAQ_accounted)
        if ~exist('DAQ_accounted','var'), DAQ_accounted = all_DAQ_accounted; end
        IOBoard = get_board_info();
        IOName = MLConfig.IOList(:,1);
        valid = assign_IO(MLConfig.IO);
        all_DAQ_accounted = DAQ_accounted & all(valid);
        MLConfig.IO = MLConfig.IO(valid);
        if isempty(MLConfig.IO), MLConfig.IO = []; end
        update_boards();
    end

    function update_boards(err_display)
        if isempty(hTag.hIO), return, end
        if ~exist('err_display','var'), err_display = false; end

        io.SignalType = get(hTag.SignalType,'value');
        io.Spec = MLConfig.IOList(io.SignalType,:);  % label, subsystems, [dio_out multilines]
        if ~iscell(io.Spec{2}), io.Spec{2} = io.Spec(2); end

        if ~isempty(MLConfig.IO) && any(strcmp({MLConfig.IO.SignalType},io.Spec{1}))
            row = strcmp({MLConfig.IO.SignalType},io.Spec{1});
            board_status = sprintf('%s:%s',MLConfig.IO(row).Adaptor,MLConfig.IO(row).DevID);
            subsystem_status = MLConfig.IO(row).Subsystem;
            switch subsystem_status
                case {'AnalogInput','AnalogOutput'}, channels_status = ['Channel' sprintf(' %d',MLConfig.IO(row).Channel)];
                case 'DigitalIO'
                    subsystem_status = [subsystem_status sprintf(', ''%s''',MLConfig.IO(row).DIOInfo{1,2})];
                    switch length(MLConfig.IO(row).Channel)
                        case 1, channels_status = ['Port ' sprintf('%d',MLConfig.IO(row).Channel) ', Line ' num2range(MLConfig.IO(row).DIOInfo{1})];
                        otherwise, channels_status = ['Port ' num2range(MLConfig.IO(row).Channel)];
                    end
            end
        else
            board_status = '';
            subsystem_status = 'Not assigned';
            channels_status = '';
        end
        set(hTag.IOSignalType,'string',io.Spec{1});
        set(hTag.IOStatusBoard,'string',board_status);
        set(hTag.IOStatusSubsystem,'string',subsystem_status);
        set(hTag.IOStatusChannels,'string',channels_status);

        nboard = length(IOBoard);
        supported_subsystem = cell(nboard,1);
        for m=1:nboard, supported_subsystem{m} = intersect(IOBoard(m).Subsystem,io.Spec{2}); end
        board = {IOBoard(~cellfun(@isempty,supported_subsystem)).DevString};
        val = get(hTag.IOBoards,'value');
        set(hTag.IOBoards,'string',board,'value',fi(val<=length(board),val,1));
        if isempty(board)
            if err_display, mlmessage('No IO board supports %sfor %s',sprintf('%s ',io.Spec{2}{:}),io.Spec{1},'e'); end
            enable = 'off';
        else
            update_subsystem();
            enable = 'on';
        end
        set(hTag.IOAssign,'enable',enable);
    end

    function update_subsystem()
        if isempty(hTag.hIO), return, end
        items = get(hTag.IOBoards,'string');
        val = get(hTag.IOBoards,'value');
        io.Board = find(strcmp(items{val},{IOBoard.DevString}),1);

        subsystem_supported = intersect(IOBoard(io.Board).Subsystem,io.Spec{2});
        val = get(hTag.Subsystem,'value');
        set(hTag.Subsystem,'string',subsystem_supported,'value',fi(val<=length(subsystem_supported),val,1));
        update_channels();
    end

    function update_channels()
        if isempty(hTag.hIO), return, end
        items = get(hTag.Subsystem,'string');
        val = get(hTag.Subsystem,'value');
        io.SubsystemLabel = items{val};
        io.Subsystem = find(strcmp(io.SubsystemLabel,{'AnalogInput','AnalogOutput','DigitalIO'}),1);

        channels = IOBoard(io.Board).Channel{io.Subsystem};
        if 3==io.Subsystem
            direction = fi(1==io.Spec{3}(1),'out','in');
            col = fi(IOBoard(io.Board).DIOLineByLineConfig,4,2);
            channels = channels(~cellfun(@isempty,IOBoard(io.Board).DIOInfo(:,1)) & ~cellfun(@isempty,strfind(IOBoard(io.Board).DIOInfo(:,col),direction))); %#ok<STRCLFH>
        end
        val = get(hTag.Channels,'value');
        str = num2cell(channels);
        set(hTag.Channels,'string',str,'value',fi(val<=length(str),val,1),'min',0,'max',fi(3==io.Subsystem & 1==io.Spec{3}(2),2,1));
    end

    function preview()
        figure(hTag.hFig); axis(hTag.StimulusFigure);
        if ~isconditionsfile(MLConditions), mglimage(earth_image); return, end
        selected = get(hTag.StimulusList,'value');
        if ~isscalar(selected), return, end  % sometimes selected becomes empty because of mouse-clicking timing
        stim = MLConditions.UIVars.StimulusList(selected).Attribute;
        try
            switch lower(stim{1})
                case {'fix','dot'}, mglimage(load_cursor(MLConfig.FixationPointImage,MLConfig.FixationPointShape,MLConfig.FixationPointColor,MLConfig.FixationPointDeg*Screen.PixelsPerDegree));
                case {'pic','mov'}, mglimage(mglimread(stim{2}));
                case 'crc', mglimage(make_circle(Screen.PixelsPerDegree*stim{2},stim{3},stim{4}));
                case 'sqr', mglimage(make_rectangle(Screen.PixelsPerDegree*stim{2},stim{3},stim{4}));
                case 'snd', y = load_waveform(stim); if isscalar(y), mgldestroysound(y); mglimage(sound_icon); else, plot(y); end
                case 'stm', plot(load_waveform({'stm',stim{3}}));
                case 'ttl', mglimage(ttl_icon);
                case 'gen'
                    func = get_function_handle(stim{2});
                    trialrecord = mltrialrecord(MLConfig).new_trial(MLConfig,true);
                    try
                        if 1==nargin(func), imdata = func(trialrecord); else, imdata = func(trialrecord,MLConfig); end
                        if ischar(imdata)
                            [~,~,e] = fileparts(imdata);
                            switch e
                                case {'.m',''}, mglimage(earth_image);  % non-image filename
                                otherwise, mglimage(mglimread(imdata));
                            end
                        else
                            mglimage(imdata);
                        end
                    catch
                        mglimage(earth_image);
                    end
            end
            set(gca,'Color',MLConfig.SubjectScreenBackground);
        catch err
            mlmessage('%s: %s',upper(stim{1}),err.message,'e');
            rethrow(err);
        end
    end

    function movie_playback(id)
        mouse = pointingdevice;
        mov = mglgetproperty(id,'info');
        line_interval = 15 * Screen.DPI_ratio;
        mglsetorigin(mgladdtext(sprintf('Size: %d x %d',mov.Size),9),[10 0]);
        txt_frame  = mgladdtext('',9); mglsetorigin(txt_frame, [10 line_interval]);
        mglsetorigin(mgladdtext(sprintf('Time per frame: %0.3f ms',mov.TimePerFrame * 1000),9),[10 line_interval*2]);
        txt_buf    = mgladdtext('',9); mglsetorigin(txt_buf,   [10 line_interval*3]);
        txt_render = mgladdtext('',9); mglsetorigin(txt_render,[10 line_interval*4]);
        txt_cur    = mgladdtext('',9); mglsetorigin(txt_cur,   [10 line_interval*5]);
        looping = mov.Looping;
        mglsetproperty(id,'looping',true);

        frame_number = 0; rendering_time = 0; keypress = []; kbdinit; [~,button] = getsample(mouse);
        while isempty(keypress) && ~any(button)
            mov = mglgetproperty(id,'info');
            mglsetproperty(txt_frame, 'text',sprintf('Frame number: %07d / %07d (%d)',floor(mov.CurrentPosition/mov.TimePerFrame)+1,mov.TotalFrames,floor(frame_number/mov.DurationInRefreshCounts)));
            mglsetproperty(txt_buf,   'text',sprintf('Buffered frames: %d',mov.BufferedFrames));
            mglsetproperty(txt_render,'text',sprintf('Rendering time: %0.3f ms',rendering_time));
            mglsetproperty(txt_cur,   'text',sprintf('Current position: %0.3f s / %0.3f s',mov.CurrentPosition,mov.Duration));
            mglsetproperty(id,'setnextframe',frame_number); % for frame-by-frame movies
            tic;
            mglrendergraphic(frame_number);
            rendering_time = toc * 1000;
            mglpresent;
            frame_number = frame_number + 1;
            keypress = kbdgetkey;
            [~,button] = getsample(mouse);
        end
        mglsetproperty(id,'looping',looping);
    end

    function boards = get_board_info()
        hwinfo = daqhwinfo();
        board_count = 0;
        for m=1:length(hwinfo.InstalledAdaptors)
            adaptor = daqhwinfo(hwinfo.InstalledAdaptors{m});
            board_count = board_count + length(adaptor.InstalledBoardIds);
        end
        boards(board_count).DevString = ''; idx = 0;
        for m=1:length(hwinfo.InstalledAdaptors)
            adaptor = daqhwinfo(hwinfo.InstalledAdaptors{m});
            for n=1:length(adaptor.InstalledBoardIds)
                idx = idx + 1;
                boards(idx).DevString = sprintf('%s:%s (%s)',hwinfo.InstalledAdaptors{m},adaptor.InstalledBoardIds{n},adaptor.BoardNames{n});
                boards(idx).Adaptor = hwinfo.InstalledAdaptors{m};
                boards(idx).DevID = adaptor.InstalledBoardIds{n};
                boards(idx).Subsystem = {'','',''}';
                boards(idx).Channel = {'','',''}';
                boards(idx).DIOInfo = [];
                boards(idx).DIOLineByLineConfig = [];
                for k=1:3
                    if ~isempty(adaptor.ObjectConstructorName{n,k})
                        try
                            obj = eval(adaptor.ObjectConstructorName{n,k});
                            obj_info = daqhwinfo(obj);
                            delete(obj);
                            boards(idx).Subsystem{k} = obj_info.SubsystemType;
                            switch k
                                case 1, if isempty(obj_info.SingleEndedIDs), boards(idx).Channel{k} = obj_info.DifferentialIDs; else, boards(idx).Channel{k} = obj_info.SingleEndedIDs; end
                                case 2, boards(idx).Channel{k} = obj_info.ChannelIDs;
                                case 3, boards(idx).Channel{k} = [obj_info.Port.ID];
                                    boards(idx).DIOInfo = [{obj_info.Port.LineIDs}' {obj_info.Port.Direction}' num2cell(cellfun(@length,{obj_info.Port.LineIDs}')) {obj_info.Port.Direction}'];
                                    switch adaptor.BoardNames{n}
                                        case {'PCI-6509','PXI-6509','USB-6509'}, boards(idx).DIOLineByLineConfig = false;
                                        otherwise, boards(idx).DIOLineByLineConfig = true;
                                    end
                            end
                        catch err
                            warning('%s: %s',boards(idx).DevString, err.message);
                        end
                    end
                end
            end
        end
    end

    function init()
        hTag.hFig = findobj('tag','mlmainmenu'); if ~isempty(hTag.hFig), figure(hTag.hFig); return, end
        hFig = findobj('tag','mlplayer'); if ~isempty(hFig), close(hFig); drawnow; pause(0.3); end  % to reset mgl

        % https://www.mathworks.com/support/requirements/previous-releases.html
        if System.OSVersion(1) < 10, disp([newline 'This version of NIMH MonkeyLogic requires <strong>Windows 10 or later</strong>.' newline 'For earlier Windows, install the previous version (v2.0).' newline '<a href="https://monkeylogic.nimh.nih.gov/download.html">https://monkeylogic.nimh.nih.gov/download.html</a>']); return, end
        if ~strcmp(computer,'PCWIN64'), disp([newline 'This version of NIMH MonkeyLogic supports <strong>64-bit Windows</strong> only.' newline 'For 32-bit Windows, install the previous version (v2.0).' newline '<a href="https://monkeylogic.nimh.nih.gov/download.html">https://monkeylogic.nimh.nih.gov/download.html</a>']); return, end
        if verLessThan('matlab','8.4'), disp([newline 'This version of NIMH MonkeyLogic requires <strong>MATLAB 8.4 (R2014b) or later</strong>.' newline 'Please upgrade your MATLAB first.']); return, end
        if ~usejava('desktop'), disp([newline 'MATLAB interactive desktop is not running.' newline 'Please enable all Java features and remove <strong>''-nodesktop''</strong> in the startup option.']); return, end

        MLPath.BaseDirectory = mfilename('fullpath');
        basedir = MLPath.BaseDirectory; 
        addpath(basedir,[basedir 'mgl'],[basedir 'daqtoolbox'],[basedir 'ext'], ...
            [basedir 'daqtoolbox' filesep 'liblsl'],[basedir 'daqtoolbox' filesep 'liblsl' filesep 'bin'], ...
            [basedir 'ext' filesep 'playback'],[basedir 'ext' filesep 'SlackMatlab'],[basedir 'ext' filesep 'deprecated']);

        try
            daqreset;
            mglreset;
        catch err
            try
                switch mglcheckdx9
                    case 1
                        msg = [newline 'NIMH MonkeyLogic requires <strong>DirectX End-User Runtime</strong>.' newline ...
                            'Please download and install it from the following URL.' newline ...
                            '<a href="https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe">https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe</a>' newline ...
                            ];
                        fprintf(2,'%s\n',msg);
                        return
                    case 2
                        msg = [newline 'Windows N requires <strong>Media Feature Pack</strong> to run NIMH MonkeyLogic.' newline ...
                            'Please follow the instructions in the link below and install it.' newline ...
                            '<a href="https://support.microsoft.com/en-us/topic/media-feature-pack-list-for-windows-n-editions-c1c6fffa-d052-8338-7a79-a4bb980a700a">https://support.microsoft.com/en-us/topic/media-feature-pack-list-for-windows-n-editions-c1c6fffa-d052-8338-7a79-a4bb980a700a</a>' newline ...
                            ];
                        fprintf(2,'%s\n',msg);
                        return
                end
            catch err
            end
            if ~isempty(strfind(err.identifier,'nvalidMEXFile'))
                msg = [newline 'NIMH MonkeyLogic requires <strong>Microsoft Visual C++ Redistributable' newline 'for Visual Studio 2022</strong>.' newline ...
                    'Here is a direct link to the package. Please install it first.' newline ...
                    '<a href="https://aka.ms/vs/17/release/vc_redist.x64.exe">https://aka.ms/vs/17/release/vc_redist.x64.exe</a>' newline newline ...
                    'If the above link does not work, visit the following website' newline 'and download the <strong>x64</strong> package (vc_redist.x64.exe).' newline ...
                    '<a href="https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170#visual-studio-2015-2017-2019-and-2022">https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170#visual-studio-2015-2017-2019-and-2022</a>' newline ...
                    ];
                fprintf(2,'%s\n',msg);
                return
            end
            rethrow(err);
        end

        rng('shuffle');
        MLConfig.MLVersion = fileread([basedir 'NIMH_MonkeyLogic_version.txt']);
        MLConfig.IOList = mliolist();
        IOName = MLConfig.IOList(:,1);  % for UI
        IOBoard = get_board_info();

        init_menu();

        fprintf('\n\n');
        if ~isempty(MLConfig.MLVersion), mlmessage('NIMH MonkeyLogic %s',MLConfig.MLVersion); end
        if ~isempty(System.OperatingSystem), mlmessage(System.OperatingSystem); end
        mlmessage('MATLAB %s', version);
        hwinfo = daqhwinfo; daqdriver = daq.getVendors; %#ok<SESSIONGV>
        mlmessage('%s %s', hwinfo.ToolboxName, hwinfo.ToolboxVersion);
        mlmessage('%s %s', daqdriver.FullName, daqdriver.DriverVersion);
        if ~isempty(System.ProcessorID), mlmessage(System.ProcessorID); end
        if ~isempty(System.NumberOfProcessors), mlmessage('Detected %s "%s" processors',System.NumberOfProcessors,System.ProcessorArchitecture,'i'); end
        mlmessage('Found %i video device(s)...', System.NumberOfScreenDevices);
        mlmessage('Found %d DAQ adaptor(s), %d board(s)', length(hwinfo.InstalledAdaptors), length(IOBoard));

        try loadcfg(MLPath.ConfigurationFile); catch err, warning_handler(err); end
        update_UI(); old_MLConfig = MLConfig;  % in case loadcfg() does not do this
    end

    function init_menu()
        filetype = {'.bhv2','.bhvz','.h5','.mat'};
        message_str = []; if ~isempty(hMessagebox), message_str = get(hMessagebox,'string'); end

        % get the state of collapsed_menu
        if ispref('NIMH_MonkeyLogic','CollapsedMenu'), collapsed_menu = getpref('NIMH_MonkeyLogic','CollapsedMenu'); end
        screen_pos = GetMonitorPosition(mglgetcommandwindowrect); if screen_pos(3) < 900 || screen_pos(4) < 880, collapsed_menu = true; end

        if collapsed_menu
            fig_pos = [0 0 593 528];
            x0 = 5; y0 = fig_pos(4)-178;  % conditions file box
            x1 = 310; y1 = 267;   % run box
            x2 = 305; y2 = 29;    % config box
            dx = 20;              % width adjustment
        else
            fig_pos = [0 0 898 767];
            x0 = 5; y0 = fig_pos(4)-178;
            x1 = 5; y1 = 215;
            x2 = 595; y2 = 29;
            dx = 0;
        end

        % determine fig_pos
        if isempty(hTag.hFig)
            hTag.hFig = figure;
            new_position = true;
            if ispref('NIMH_MonkeyLogic','LastMonitorPosition') && ispref('NIMH_MonkeyLogic','LastMLMainMenuPosition')
                old_mon = getpref('NIMH_MonkeyLogic','LastMonitorPosition');
                new_mon = GetMonitorPosition;
                new_position = size(old_mon,1)~=size(new_mon,1) || any(any(old_mon~=new_mon));
            end
            if new_position, pos = get(hTag.hFig,'position'); else, pos = getpref('NIMH_MonkeyLogic','LastMLMainMenuPosition'); end
            fig_pos(1:2) = [pos(1) pos(2)+pos(4)-fig_pos(4)];
        else
            pos = get(hTag.hFig,'position');
            fig_pos(1:2) = [pos(1) pos(2)+pos(4)-fig_pos(4)];
            associated_figures = {'VideoSettingWindow','IOSettingWindow','TaskSettingWindow'};
            for m = 1:length(associated_figures)
                h = findobj('tag',associated_figures{m});
                if ~isempty(h), close(h); end
            end
            set(hTag.hFig,'closerequestfcn','closereq');
            close(hTag.hFig);
            hTag.hFig = figure;
        end

        set(hTag.hFig,'tag','mlmainmenu','units','pixels','position',fig_pos,'numbertitle','off','name',sprintf('NIMH MonkeyLogic %s',MLConfig.MLVersion),'menubar','none','toolbar','none','resize','off','color',figure_bgcolor);
        try set(hTag.hFig,'theme','light'); catch, end
        set(hTag.hFig,'closerequestfcn',@closeDlg);

        x = x0 + 305; y = fig_pos(4)-94;
        uicontrol('style','pushbutton','position',[x y 280 90],'cdata',threemonkeys_image,'callback','web(''https://monkeylogic.nimh.nih.gov'',''-browser'')','tooltip','Go to the NIMH MonkeyLogic website');
        if collapsed_menu
            uicontrol('style','pushbutton','position',[x+255 y+65 25 25],'tag','ExpandedMenu','cdata',expand_icon,'callback',callbackfunc,'tooltip','Expand the menu');
        else
            uicontrol('style','pushbutton','position',[x+255 y+65 25 25],'tag','CollapsedMenu','cdata',collapse_icon,'callback',callbackfunc,'tooltip','Collapse the menu');
        end
        uicontrol('style','pushbutton','position',[x y+65 25 25],'cdata',help_icon,'callback',['web(''' MLPath.DocDirectory 'docs.html'',''-browser'')'],'tooltip','Open the manual');

        x = x0; y = fig_pos(4)-126; bgcolor = figure_bgcolor;
        uicontrol('style','text','position',[x+50 y+104 200 21],'string','Messages from MonkeyLogic','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hMessagebox = uicontrol('style','list','position',[x y 300 110],'string',{'<html><font color="gray">>> End of the messages</font></html>'},'backgroundcolor',[1 1 1],'fontsize',fontsize);
        if ~isempty(message_str), set(hMessagebox,'string',message_str,'value',length(message_str)); end

        x = x0 + 5; y = y0; bgcolor = 0.85 * figure_bgcolor;
        uicontrol('style','frame','position',[x-5 y-5 300 54],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        hTag.LoadConditionsFile = uicontrol('style','pushbutton','position',[x y 230 44],'tag','LoadConditionsFile','backgroundcolor',purple_bgcolor,'fontsize',fontsize,'fontweight','bold','callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+235 y+22 55 22],'string','Help','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',['web(''' MLPath.DocDirectory 'docs_TaskObjects.html'',''-browser'')'],'tooltip','Open the TaskObjects manual page');
        hTag.EditConditionsFile = uicontrol('style','pushbutton','position',[x+235 y 55 22],'tag','EditConditionsFile','string','Edit','fontsize',fontsize,'callback',callbackfunc,'tooltip','Edit the conditions file');
        x = x0; y = y - 120;
        hTag.StimulusFigure = axes('units','pixels','position',[x+210 y+26 90 90],'xtick',[],'ytick',[],'box','on'); mglimage(earth_image);
        uicontrol('style','frame','position',[x y 300 26],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        uicontrol('style','frame','position',[x y 210 116],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x+300 y 5 26],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        x = x0 + 5; bgcolor = 0.85 * figure_bgcolor;
        uicontrol('style','text','position',[x y+94 200 22],'string','Stimulus list','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hTag.StimulusList = uicontrol('style','listbox','position',[x y 200 100],'tag','StimulusList','fontsize',fontsize,'callback',callbackfunc);
        hTag.StimulusTest = uicontrol('style','pushbutton','position',[x+205 y 90 22],'tag','StimulusTest','string','Test','fontsize',fontsize,'callback',callbackfunc,'tooltip','Test the selected stimlus');
        uicontrol('style','frame','position',[x-5 y-225 300 225],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);

        x = x0; y = y - 28;
        uicontrol('style','text','position',[x+72 y+3 200 19],'string','Total # of cond. in this file','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.TotalNumberOfConditions = uicontrol('style','edit','position',[x+240 y+3 55 22],'tag','TotalNumberOfConditions','enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        bgcolor = 0.5 * figure_bgcolor;
        uicontrol('style','frame','position',[x y-100 300 102],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        uicontrol('style','frame','position',[x y-100 69 126],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        x = x0 + 5; fgcolor = [1 1 1];
        uicontrol('style','text','position',[x y+3 60 22],'string','Blocks','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        hTag.BlockList = uicontrol('style','listbox','position',[x y-97 60 106],'tag','BlockList','fontsize',fontsize,'callback',callbackfunc);
        x = x0; y = y - 25;
        uicontrol('style','text','position',[x+72 y 200 22],'string','Total # of cond. in this block','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.TotalNumberOfConditionsInThisBlock = uicontrol('style','edit','position',[x+240 y+3 55 22],'tag','TotalNumberOfConditionsInThisBlock','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x+72 y 200 22],'string','# of trials to run in this block','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.NumberOfTrialsToRunInThisBlock = uicontrol('style','edit','position',[x+240 y+3 55 22],'tag','NumberOfTrialsToRunInThisBlock','fontsize',fontsize,'callback',callbackfunc,'tooltip','The block switches after this number of trials');
        y = y - 25;
        uicontrol('style','text','position',[x+72 y 200 22],'string','Count correct trials only','backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.CountOnlyCorrectTrials = uicontrol('style','checkbox','position',[x+240 y+6 15 15],'tag','CountOnlyCorrectTrials','backgroundcolor',bgcolor,'callback',callbackfunc);
        x = x0 + 5; y = y - 22;
        hTag.ChartBlocks = uicontrol('style','pushbutton','position',[x+65 y 110 22],'tag','ChartBlocks','string','Chart blocks','fontsize',fontsize,'callback',callbackfunc);
        hTag.ApplyToAll = uicontrol('style','pushbutton','position',[x+180 y 110 22],'tag','ApplyToAll','string','Apply to all','fontsize',fontsize,'callback',callbackfunc);
        y = y - 30; bgcolor = 0.85 * figure_bgcolor;
        uicontrol('style','text','position',[x y 105 22],'string','Blocks to run','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.BlocksToRun = uicontrol('style','edit','position',[x+85 y+3 145 22],'tag','BlocksToRun','enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        hTag.ChooseBlocksToRun = uicontrol('style','pushbutton','position',[x+235 y+3 55 22],'tag','ChooseBlocksToRun','string','Choose','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','First block to run','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.FirstBlockToRun = uicontrol('style','edit','position',[x+105 y+3 55 22],'tag','FirstBlockToRun','enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        hTag.ChooseFirstBlockToRun = uicontrol('style','pushbutton','position',[x+235 y+3 55 22],'tag','ChooseFirstBlockToRun','string','Choose','fontsize',fontsize,'callback',callbackfunc);
        y = y - 40;
        uicontrol('style','text','position',[x y+17 50 20],'string','Timing','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','text','position',[x y-2 40 20],'string','files','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hTag.TimingFiles = uicontrol('style','listbox','position',[x+45 y 185 40],'tag','TimingFiles','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+235 y+20 55 20],'string','Help','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',['web(''' MLPath.DocDirectory 'docs_RuntimeFunctions.html'',''-browser'')'],'tooltip','Open the runtime functions manual');
        hTag.EditTimingFiles = uicontrol('style','pushbutton','position',[x+235 y 55 20],'tag','EditTimingFiles','string','Edit','fontsize',fontsize,'callback',callbackfunc,'tooltip','Edit the selected timing file');

        x = x1 + 5; y = y1; bgcolor = figure_bgcolor;
        uicontrol('style','text','position',[x y 140 22],'string','Total # of trials to run','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.TotalNumberOfTrialsToRun = uicontrol('style','edit','position',[x+140 y+3 55 22],'tag','TotalNumberOfTrialsToRun','fontsize',fontsize,'callback',callbackfunc,'tooltip','The task stops when the trial count reaches this number');
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Total # of blocks to run','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.TotalNumberOfBlocksToRun = uicontrol('style','edit','position',[x+140 y+3 55 22],'tag','TotalNumberOfBlocksToRun','fontsize',fontsize,'callback',callbackfunc,'tooltip','The task stops when the block count reaches this number');
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Experiment name','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.ExperimentName = uicontrol('style','edit','position',[x+110 y+3 180-dx 22],'tag','ExperimentName','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Investigator','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.Investigator = uicontrol('style','edit','position',[x+110 y+3 180-dx 22],'tag','Investigator','fontsize',fontsize,'callback',callbackfunc);
        bgcolor = purple_bgcolor;
        uicontrol('style','frame','position',[x-5 y-135 300-dx 135],'backgroundcolor',bgcolor);
        y = y - 30;
        uicontrol('style','text','position',[x y 140 22],'string','Subject name','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.SubjectName = uicontrol('style','edit','position',[x+100 y+3 190-dx 22],'tag','SubjectName','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 100 22],'string','Filename format','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.FilenameFormat = uicontrol('style','edit','position',[x+100 y+3 190-dx 22],'tag','FilenameFormat','fontsize',fontsize,'callback',callbackfunc,'tooltip',['expname or ename: Experiment Name' newline 'yourname or yname: Investigator' newline 'condname or cname: Conditions file name' newline 'subjname or sname: Subject name' newline 'yyyy: Year in full (1990, 2002)' newline 'yy: Year in two digits (90, 02)' newline 'mmm: Month using first three letters (Mar, Dec)' newline 'mm: Month in two digits (03, 12)' newline 'ddd: Day using first three letters (Mon, Tue)' newline 'dd: Day in two digits (05, 20)' newline 'HH: Hour in two digits (05, 24)' newline 'MM: Minute in two digits (12, 02)' newline 'SS: Second in two digits (07, 59)']);
        y = y - 25;
        uicontrol('style','text','position',[x y+3 50 19],'string','Data file','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.DataFile = uicontrol('style','edit','position',[x+55 y+3 235-dx 22],'tag','DataFile','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 100 22],'string','Filetype','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.Filetype = uicontrol('style','popupmenu','position',[x+55 y+3 55 22],'tag','Filetype','string',filetype,'fontsize',fontsize,'callback',callbackfunc);
%         uicontrol('style','text','position',[x y 100 22],'string','Minify runtime','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
%         hTag.MinifyRuntime = uicontrol('style','checkbox','position',[x+95 y+6 15 15],'tag','MinifyRuntime','backgroundcolor',bgcolor,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 100 22],'string','Save stimuli','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.SaveStimuli = uicontrol('style','checkbox','position',[x+82 y+6 15 15],'tag','SaveStimuli','backgroundcolor',bgcolor,'callback',callbackfunc,'tooltip','Save file-based stimuli to the data file');
        hTag.RunButton = uicontrol('style','pushbutton','position',[x+135-dx y 155 48],'tag','RunButton','enable','inactive','cdata',runbuttondim_image,'callback',callbackfunc);

        if collapsed_menu
            hTag.hVideo = []; hTag.hIO = []; hTag.hTask = [];
            x = 310; y = 295; bgcolor = frame_bgcolor;
            uicontrol('style','frame','position',[x y 280 135],'backgroundcolor',bgcolor);
            uicontrol('style','pushbutton','position',[x+5 y+10 90 30],'cdata',taskheader_image,'enable','inactive');
            hTag.TaskSetting = uicontrol('style','pushbutton','position',[x+190 y+15 80 25],'tag','TaskSetting','string','Settings','fontsize',fontsize,'callback',callbackfunc);
            uicontrol('style','pushbutton','position',[x+4 y+53 180 30],'cdata',ioheader_image,'enable','inactive');
            hTag.IOSetting = uicontrol('style','pushbutton','position',[x+190 y+55 80 25],'tag','IOSetting','string','Settings','fontsize',fontsize,'callback',callbackfunc);
            uicontrol('style','pushbutton','position',[x+2 y+88 100 30],'cdata',videoheader_image,'enable','inactive');
            hTag.VideoSetting = uicontrol('style','pushbutton','position',[x+190 y+95 80 25],'tag','VideoSetting','string','Settings','fontsize',fontsize,'callback',callbackfunc);
        else
            hTag.hVideo = hTag.hFig; hTag.hIO = hTag.hFig; hTag.hTask = hTag.hFig;
            menu_video(310,668);
            menu_io(595,763);
            menu_task(310,163);
        end

        x = x2; y = y2; bgcolor = figure_bgcolor;
        x = x + 10;
        uicontrol('style','text','position',[x y 50 22],'string','Config:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.ConfigurationFile = uicontrol('style','text','position',[x+45 y 530 22],'tag','ConfigurationFile','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left','callback',callbackfunc);
        hTag.OpenConfigurationFolder = uicontrol('style','pushbutton','position',[x+235-dx y+3 55 22],'tag','OpenConfigurationFolder','string','Locate','fontsize',fontsize,'callback',callbackfunc,'tooltip','Open the configuration file location');
        y = y - 24;
        hTag.SetPath = uicontrol('style','pushbutton','position',[x y 60 24],'tag','SetPath','string','Set path','fontsize',fontsize,'callback','mlsetpath');
        hTag.LoadSettings = uicontrol('style','pushbutton','position',[x+65 y 110-dx/2 24],'tag','LoadSettings','string','Load settings','fontsize',fontsize,'callback',callbackfunc);
        hTag.SaveSettings = uicontrol('style','pushbutton','position',[x+180-dx/2 y 110-dx/2 24],'tag','SaveSettings','enable','off','string','Save settings','fontsize',fontsize,'callback',callbackfunc);
    end

    function menu_video(x0,y0)
        x = x0; y = y0; bgcolor = frame_bgcolor;
        uicontrol('style','frame','position',[x y-500 280 500],'backgroundcolor',bgcolor);
        x = x0 + 180; y = y - 27; bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x y 100 27],'backgroundcolor',bgcolor);
        uicontrol('style','frame','position',[x+1 y+1 100 27],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        hTag.LatencyTest = uicontrol('style','pushbutton','position',[x+5 y+5 95 22],'tag','LatencyTest','string','Latency test','fontsize',fontsize,'callback',callbackfunc,'tooltip','Performance test with pictures and movies');
        x = x0 + 1; y = y - 10;
        uicontrol('style','pushbutton','position',[x y 100 30],'cdata',videoheader_image,'enable','inactive');
        hTag.IORefresh1 = uicontrol('style','pushbutton','position',[x+155 y+12 17 17],'tag','IORefresh','cdata',refresh_icon,'callback',callbackfunc,'tooltip','Refresh screen devices');
        x = x0 + 10; y = y - 23; bgcolor = frame_bgcolor;
        uicontrol('style','text','position',[x y 170 22],'string','Subject screen device','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.SubjectScreenDevice = uicontrol('style','popupmenu','position',[x+145 y+3 50 22],'tag','SubjectScreenDevice','string',num2cell(1:System.NumberOfScreenDevices),'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 100 22],'string','Resolution','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left','tooltip','To change the resolution,use the screen menu of Windows');
        hTag.Resolution = uicontrol('style','edit','position',[x+75 y+3 120 22],'tag','Resolution','enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize);
        hTag.VideoTest = uicontrol('style','pushbutton','position',[x+203 y 58 52],'tag','VideoTest','string','Test','fontsize',fontsize,'callback',callbackfunc,'tooltip','Test the selected subject screen device');
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Diagonal size (cm)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.DiagonalSize = uicontrol('style','edit','position',[x+135 y+3 60 22],'tag','DiagonalSize','fontsize',fontsize,'callback',callbackfunc,'tooltip','Diagonal size of the subject screen');
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Viewing distance (cm)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.ViewingDistance = uicontrol('style','edit','position',[x+135 y+3 60 22],'tag','ViewingDistance','fontsize',fontsize,'callback',callbackfunc,'tooltip','Distance between the subject''eye and the screen');
        y = y - 25;
        uicontrol('style','text','position',[x y 140 22],'string','Pixels per degree','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.PixelsPerDegree = uicontrol('style','edit','position',[x+135 y+3 60 22],'tag','PixelsPerDegree','enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize);
        hTag.AdjustedPPD = uicontrol('style','checkbox','position',[x+204 y+6 15 15],'tag','AdjustedPPD','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+222 y 46 22],'string','Adjust','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        x = x0 + 5; bgcolor = 0.9 * frame_bgcolor;
        uicontrol('style','frame','position',[x y-56 270 55],'backgroundcolor',bgcolor,'foregroundcolor',0.8 * frame_bgcolor);
        x = x0 + 10; y = y - 30;
        uicontrol('style','text','position',[x y 140 22],'string','Fallback screen rect.','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.FallbackScreenRect = uicontrol('style','edit','position',[x+125 y+3 135 22],'tag','FallbackScreenRect','fontsize',fontsize,'callback',callbackfunc,'tooltip',['Format: [LEFT,TOP,RIGHT,BOTTOM]' newline 'This window will be used as the subject screen' newline 'when there is only one monitor available' newline 'or when forced to use it']);
        y = y - 25;
        uicontrol('style','text','position',[x y 180 22],'string','Forced use of fallback screen','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.ForcedUseOfFallbackScreen = uicontrol('style','checkbox','position',[x+180 y+6 15 15],'tag','ForcedUseOfFallbackScreen','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 30; bgcolor = frame_bgcolor;
        uicontrol('style','text','position',[x-3 y 170 22],'string','Subject screen background','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.SubjectScreenBackground = uicontrol('style','pushbutton','position',[x+160 y+3 105 22],'tag','SubjectScreenBackground','string','Color','fontsize',fontsize,'callback',callbackfunc);
        y = y - 29;
        uicontrol('style','text','position',[x-3 y 115 22],'string','Fixation point','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.FixationPointImage = uicontrol('style','pushbutton','position',[x+80 y+3 185 22],'tag','FixationPointImage','fontsize',fontsize,'callback',callbackfunc);
        y = y - 24;
        uicontrol('style','text','position',[x+50 y 25 22],'string','or','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.FixationPointShape = uicontrol('style','popupmenu','position',[x+80 y+3 65 22],'tag','FixationPointShape','string',{'Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.FixationPointColor = uicontrol('style','pushbutton','position',[x+150 y+3 55 22],'tag','FixationPointColor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        hTag.FixationPointDeg = uicontrol('style','edit','position',[x+210 y+3 35 22],'tag','FixationPointDeg','fontsize',fontsize,'callback',callbackfunc,'tooltip','Radius in degrees');
        uicontrol('style','text','position',[x+245 y 24 22],'string','deg','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        y = y - 30;
        uicontrol('style','text','position',[x y+5 95 22],'string','Eye','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','text','position',[x-5 y-9 95 22],'string','tracer','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.EyeNumber(1) = uicontrol('style','popupmenu','position',[x+35 y+3 40 22],'tag','EyeNumber','string',{'#1','#2'},'value',1,'fontsize',fontsize,'callback',callbackfunc);
        hTag.EyeTracerShape = uicontrol('style','popupmenu','position',[x+80 y+3 65 22],'tag','EyeTracerShape','string',{'Line','Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.EyeTracerColor = uicontrol('style','pushbutton','position',[x+150 y+3 55 22],'tag','EyeTracerColor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        hTag.EyeTracerSize = uicontrol('style','edit','position',[x+210 y+3 35 22],'tag','EyeTracerSize','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+245 y 20 22],'string','px','backgroundcolor',bgcolor,'fontsize',fontsize);
        y = y - 30;
        uicontrol('style','text','position',[x y+5 80 18],'string','Joy','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','text','position',[x-5 y-9 80 18],'string','cursor','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.JoystickNumber(1) = uicontrol('style','popupmenu','position',[x+35 y+3 40 22],'tag','JoystickNumber','string',{'#1','#2'},'value',1,'fontsize',fontsize,'callback',callbackfunc);
        hTag.JoystickCursorImage = uicontrol('style','pushbutton','position',[x+80 y+3 185 22],'tag','JoystickCursorImage','fontsize',fontsize,'callback',callbackfunc);
        y = y - 24;
        uicontrol('style','text','position',[x+50 y 25 22],'string','or','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.JoystickCursorShape = uicontrol('style','popupmenu','position',[x+80 y+3 65 22],'tag','JoystickCursorShape','string',{'Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.JoystickCursorColor = uicontrol('style','pushbutton','position',[x+150 y+3 55 22],'tag','JoystickCursorColor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        hTag.JoystickCursorSize = uicontrol('style','edit','position',[x+210 y+3 35 22],'tag','JoystickCursorSize','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+245 y 20 22],'string','px','backgroundcolor',bgcolor,'fontsize',fontsize);
        y = y - 30;
        uicontrol('style','text','position',[x-3 y 115 22],'string','Touch cursor','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.TouchCursorImage = uicontrol('style','pushbutton','position',[x+80 y+3 185 22],'tag','TouchCursorImage','fontsize',fontsize,'callback',callbackfunc);
        y = y - 24;
        uicontrol('style','text','position',[x+50 y 25 22],'string','or','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.TouchCursorShape = uicontrol('style','popupmenu','position',[x+80 y+3 65 22],'tag','TouchCursorShape','string',{'Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.TouchCursorColor = uicontrol('style','pushbutton','position',[x+150 y+3 55 22],'tag','TouchCursorColor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        hTag.TouchCursorSize = uicontrol('style','edit','position',[x+210 y+3 35 22],'tag','TouchCursorSize','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+245 y 20 22],'string','px','backgroundcolor',bgcolor,'fontsize',fontsize);
        y = y - 30;
        uicontrol('style','text','position',[x-5 y 115 22],'string','Mouse cursor','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.MouseCursorType = uicontrol('style','popupmenu','position',[x+80 y+3 185 22],'tag','MouseCursorType','string',{'White small','White large','White extra large','Black small','Black large','Black extra large'},'fontsize',fontsize,'callback',callbackfunc);
        y = y - 30;
        uicontrol('style','text','position',[x-3 y 140 22],'string','Photodiode','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.PhotoDiodeTrigger = uicontrol('style','popupmenu','position',[x+70 y+3 85 22],'tag','PhotoDiodeTrigger','string',{'None','Upper left','Upper right','Lower right','Lower left'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.PhotoDiodeTriggerSize = uicontrol('style','edit','position',[x+160 y+3 30 22],'tag','PhotoDiodeTriggerSize','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+190 y 20 22],'string','px','backgroundcolor',bgcolor,'fontsize',fontsize);
        hTag.PhotoDiodeTuning = uicontrol('style','pushbutton','position',[x+210 y+3 55 22],'tag','PhotoDiodeTuning','string','Tune','fontsize',fontsize,'callback',callbackfunc);
    end

    function menu_io(x0,y0)
        ai_configuration = {'Differential','SingleEnded','NonReferencedSingleEnded'};
        reward_polarity = {'trigger on HIGH','trigger on LOW'};
        strobe_trigger = {'on rising edge','on falling edge','send and clear'};

        x = x0; y = y0; bgcolor = frame_bgcolor;
        uicontrol('style','frame','position',[x y-595 300 595],'backgroundcolor',bgcolor);
        x = x0 + 185; y = y - 27; bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x y 115 27],'backgroundcolor',bgcolor);
        uicontrol('style','frame','position',[x+1 y+1 115 27],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        hTag.EditBehavioralCodesFile = uicontrol('style','pushbutton','position',[x+5 y+5 110 22],'tag','EditBehavioralCodesFile','string','Edit behav. codes','fontsize',fontsize,'callback',callbackfunc);
        x = x0 + 1; y = y - 5; bgcolor = frame_bgcolor;
        uicontrol('style','pushbutton','position',[x y 180 30],'cdata',ioheader_image,'enable','inactive');
        x = x0 + 5; y = y - 169;
        uicontrol('style','text','position',[x y+140 135 22],'string','Signal type','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hTag.SignalType = uicontrol('style','listbox','position',[x y 135 145],'tag','SignalType','string',IOName,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+140 y+140 150 22],'string','I/O boards','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hTag.IORefresh2 = uicontrol('style','pushbutton','position',[x+270 y+150 17 17],'tag','IORefresh','cdata',refresh_icon,'callback',callbackfunc,'tooltip','Refresh I/O boards');
        hTag.IOBoards = uicontrol('style','listbox','position',[x+140 y 150 145],'tag','IOBoards','fontsize',fontsize,'callback',callbackfunc);
        y = y - 115;
        uicontrol('style','text','position',[x y+90 100 22],'string','Subsystem','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hTag.Subsystem = uicontrol('style','listbox','position',[x y 100 95],'tag','Subsystem','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+100 y+90 55 22],'string','Ch/Ports','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hTag.Channels = uicontrol('style','listbox','position',[x+105 y 45 95],'tag','Channels','fontsize',fontsize);
        uicontrol('style','text','position',[x+165 y+90 115 22],'string','Status','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        uicontrol('style','frame','position',[x+155 y+25 135 70],'backgroundcolor',purple_bgcolor,'foregroundcolor',0.8 * purple_bgcolor);
        hTag.IOSignalType = uicontrol('style','text','position',[x+156 y+72 133 20],'tag','IOSignalType','string','Signal type','backgroundcolor',purple_bgcolor,'fontsize',fontsize,'fontweight','bold');
        hTag.IOStatusBoard = uicontrol('style','text','position',[x+156 y+56 133 20],'tag','IOStatusBoard','string','IO board','backgroundcolor',purple_bgcolor,'fontsize',fontsize);
        hTag.IOStatusSubsystem = uicontrol('style','text','position',[x+156 y+40 133 20],'tag','IOStatusSubsystem','string','Subsystem','backgroundcolor',purple_bgcolor,'fontsize',fontsize);
        hTag.IOStatusChannels = uicontrol('style','text','position',[x+156 y+26 133 18],'tag','IOStatusChannels','string','Channels/Ports','backgroundcolor',purple_bgcolor,'fontsize',fontsize);
        hTag.IOAssign = uicontrol('style','pushbutton','position',[x+155 y 66 22],'tag','IOAssign','string','Assign','fontsize',fontsize,'callback',callbackfunc,'tooltip',['1. Signal type' newline '2. IO Boards' newline '3. Subsystem' newline '4. Channels/Ports' newline '5. Assign']);
        hTag.IOClear = uicontrol('style','pushbutton','position',[x+225 y 66 22],'tag','IOClear','string','Clear','fontsize',fontsize,'callback',callbackfunc);
        x = x0 + 10; y = y - 30;
        uicontrol('style','text','position',[x-3 y 250 22],'string','Other device settings (USB, etc.)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.OtherDeviceSettings = uicontrol('style','pushbutton','position',[x+190 y+3 95 22],'tag','OtherDeviceSettings','string','Settings','fontsize',fontsize,'callback',callbackfunc,'tooltip',['TCP I/P eyetrackers and USB joysticks have priority' newline 'over the eyetrackers and joysticks connected to' newline 'the DAQ boards above.']);
        x = x0 + 5; bgcolor = 0.9 * frame_bgcolor;
        uicontrol('style','frame','position',[x y-56 290 55],'backgroundcolor',bgcolor,'foregroundcolor',0.8 * frame_bgcolor);
        uicontrol('style','frame','position',[x+165 y+29-56 125 26],'backgroundcolor',bgcolor,'foregroundcolor',0.8 * frame_bgcolor);
        uicontrol('style','frame','position',[x+166 y+30-56 125 26],'backgroundcolor',frame_bgcolor,'foregroundcolor',frame_bgcolor);
        hTag.IOTestButton = uicontrol('style','pushbutton','position',[x+170 y+59-81 120 22],'tag','IOTestButton','string','I/O Test','fontsize',fontsize,'callback',callbackfunc,'tooltip','You can test all assigned input/output here.');
        x = x0 + 10; y = y - 30;
        uicontrol('style','text','position',[x y 90 22],'string','AI sample rate','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.AISampleRate = uicontrol('style','popupmenu','position',[x+95 y+3 55 22],'tag','AISampleRate','string',{'1000';'500';'250';'100'},'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 120 22],'string','AI configuration','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.AIConfiguration = uicontrol('style','popupmenu','position',[x+95 y+3 185 23],'tag','AIConfiguration','string',ai_configuration,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 30; bgcolor = frame_bgcolor;
        uicontrol('style','text','position',[x y 120 22],'string','Strobe','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.StrobeTrigger = uicontrol('style','popupmenu','position',[x+50 y+3 110 22],'tag','StrobeTrigger','string',strobe_trigger,'fontsize',fontsize,'callback',callbackfunc);
        hTag.StrobePulseSpec = uicontrol('style','pushbutton','position',[x+165 y+3 55 22],'tag','StrobePulseSpec','string','Spec','fontsize',fontsize,'callback',callbackfunc,'tooltip','Set the strobe pulse specification');
        hTag.StrobeTest = uicontrol('style','pushbutton','position',[x+225 y+3 55 22],'tag','StrobeTest','string','Test','fontsize',fontsize,'callback',callbackfunc,'tooltip','Test Behavioral Codes strobing');
        y = y - 25;
        uicontrol('style','text','position',[x y 120 22],'string','Reward polarity','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.RewardPolarity = uicontrol('style','popupmenu','position',[x+95 y+3 125 22],'tag','RewardPolarity','string',reward_polarity,'fontsize',fontsize,'callback',callbackfunc);
        hTag.RewardTest = uicontrol('style','pushbutton','position',[x+225 y+3 55 22],'tag','RewardTest','string','Test','fontsize',fontsize,'callback',callbackfunc,'tooltip','Send a test reward pulse');
        x = x0;
        hTag.UseDefaultIO = uicontrol('style','frame','position',[x+1 y-1 4 401],'foregroundcolor',green_bgcolor,'backgroundcolor',green_bgcolor);
        x = x0 + 5; bgcolor = 0.9 * frame_bgcolor;
        uicontrol('style','frame','position',[x y-81 290 80],'backgroundcolor',bgcolor,'foregroundcolor',0.8 * frame_bgcolor);
        x = x0 + 10; y = y - 30;
        uicontrol('style','text','position',[x y 120 22],'string','Eye cal','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.EyeNumber(2) = uicontrol('style','popupmenu','position',[x+50 y+3 40 22],'tag','EyeNumber','string',{'#1','#2'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.EyeCalibration = uicontrol('style','popupmenu','position',[x+95 y+3 185 22],'tag','EyeCalibration','string',calibration_method,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        hTag.ResetEyeCalibration = uicontrol('style','pushbutton','position',[x+35 y+3 55 22],'tag','ResetEyeCalibration','string','Reset','fontsize',fontsize,'callback',callbackfunc);
        hTag.EyeCalibrationButton = uicontrol('style','pushbutton','position',[x+95 y+3 90 22],'tag','EyeCalibrationButton','fontsize',fontsize,'callback',callbackfunc);
        hTag.EyeCalibrationImportButton = uicontrol('style','pushbutton','position',[x+190 y+3 90 22],'tag','EyeCalibrationImportButton','string','Import Eye Cal','fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x+50 y 125 22],'string','Auto drift correction','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.EyeAutoDriftCorrection = uicontrol('style','edit','position',[x+175 y+3 30 22],'tag','EyeAutoDriftCorrection','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+207 y 20 22],'string','%','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        y = y - 30; bgcolor = frame_bgcolor;
        uicontrol('style','text','position',[x y 120 22],'string','Joy cal','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.JoystickNumber(2) = uicontrol('style','popupmenu','position',[x+50 y+3 40 22],'tag','JoystickNumber','string',{'#1','#2'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.JoystickCalibration = uicontrol('style','popupmenu','position',[x+95 y+3 185 22],'tag','JoystickCalibration','string',calibration_method,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        hTag.ResetJoystickCalibration = uicontrol('style','pushbutton','position',[x+35 y+3 55 22],'tag','ResetJoystickCalibration','string','Reset','fontsize',fontsize,'callback',callbackfunc);
        hTag.JoystickCalibrationButton = uicontrol('style','pushbutton','position',[x+95 y+3 90 22],'tag','JoystickCalibrationButton','fontsize',fontsize,'callback',callbackfunc);
        hTag.JoystickCalibrationImportButton = uicontrol('style','pushbutton','position',[x+190 y+3 90 22],'tag','JoystickCalibrationImportButton','string','Import Joy Cal','fontsize',fontsize,'callback',callbackfunc);

        update_boards();
    end

    function menu_task(x0,y0)
        errorlogic = {'ignore','repeat immediately','repeat delayed'};
        condlogic = {'random with replacement','random without replacement','increasing','decreasing','user-defined'};
        blocklogic = condlogic;

        x = x0; y = y0; bgcolor = frame_bgcolor;
        uicontrol('style','frame','position',[x y-158 585 158],'backgroundcolor',bgcolor);
        x = x0 + 285 + 160; y = y - 27; bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x y 140 27],'backgroundcolor',bgcolor);
        uicontrol('style','frame','position',[x+1 y+1 140 27],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        hTag.RemoteAlert = uicontrol('style','pushbutton','position',[x+5 y+5 75 22],'tag','RemoteAlert','fontsize',fontsize,'callback',callbackfunc);
        hTag.EditAlertFunc = uicontrol('style','pushbutton','position',[x+85 y+5 55 22],'tag','EditAlertFunc','string','Edit','fontsize',fontsize,'callback',callbackfunc,'tooltip','Edit the alert function');
        x = x0 + 10; y = y - 4; bgcolor = frame_bgcolor;
        uicontrol('style','text','position',[x y 120 22],'string','On error','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.ErrorLogic = uicontrol('style','popupmenu','position',[x+70 y+3 135 22],'tag','ErrorLogic','string',errorlogic,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','pushbutton','position',[x+210 y+3 55 22],'string','Help','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',['web(''' MLPath.DocDirectory 'docs_TaskflowControl.html'',''-browser'')'],'tooltip','Open the task control manual');
        y = y - 28;
        uicontrol('style','text','position',[x y 120 22],'string','Conditions','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.CondLogic = uicontrol('style','popupmenu','position',[x+70 y+3 195 22],'tag','CondLogic','string',condlogic,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        hTag.CondSelectFunction = uicontrol('style','pushbutton','position',[x+70 y+3 195 22],'tag','CondSelectFunction','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left','callback',callbackfunc);
        y = y - 25;
        uicontrol('style','text','position',[x y 120 22],'string','Blocks','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.BlockLogic = uicontrol('style','popupmenu','position',[x+70 y+3 195 22],'tag','BlockLogic','string',blocklogic,'fontsize',fontsize,'callback',callbackfunc);
        y = y - 25;
        hTag.BlockSelectFunction = uicontrol('style','pushbutton','position',[x+70 y+3 195 22],'tag','BlockSelectFunction','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left','callback',callbackfunc);
        y = y - 22;
        hTag.BlockChangeFunction = uicontrol('style','pushbutton','position',[x+70 y+3 195 22],'tag','BlockChangeFunction','fontsize',fontsize,'callback',callbackfunc);
        x = x0 + 285 + 1; y = y0 - 35;
        uicontrol('style','pushbutton','position',[x y 90 30],'cdata',taskheader_image,'enable','inactive');
        x = x0 + 285 + 10; y = y0 - 59;
        uicontrol('style','text','position',[x y 160 22],'string','Inter-trial interval (ITI)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.InterTrialInterval = uicontrol('style','edit','position',[x+130 y+3 75 22],'tag','InterTrialInterval','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+210 y 45 22],'string','msec','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        y = y - 23;
        uicontrol('style','text','position',[x y+2 200 20],'string','During ITI,  show traces','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.SummarySceneDuringITI = uicontrol('style','checkbox','position',[x+140 y+6 15 15],'tag','SummarySceneDuringITI','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x+162 y+2 100 20],'string','&  record signals','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.NonStopRecording = uicontrol('style','checkbox','position',[x+265 y+6 15 15],'tag','NonStopRecording','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);
        y = y0 - 105;
        hTag.UserPlotFunction = uicontrol('style','pushbutton','position',[x y+3 280 22],'tag','UserPlotFunction','fontsize',fontsize,'callback',callbackfunc);

        x = x0 + 285; y = y0 - 158; bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x y 300 52],'backgroundcolor',bgcolor);
        bgcolor = figure_bgcolor;
        uicontrol('style','frame','position',[x+1 y-1 300 52],'backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
    end

    function closeDlg(varargin)
        check_cfg_change();
        setpref('NIMH_MonkeyLogic','LastMonitorPosition',GetMonitorPosition);
        setpref('NIMH_MonkeyLogic','LastMLMainMenuPosition',get(hTag.hFig,'position'));

        delete(MLConfig);
        associated_figures = {'mlmonitor','mlcalibrate','VideoSettingWindow','IOSettingWindow','TaskSettingWindow'};
        for m = 1:length(associated_figures)
            h = findobj('tag',associated_figures{m});
            if ~isempty(h), close(h); end
        end

        mlmessage('Closed MonkeyLogic...');
        fprintf('\n\n');

        closereq;
    end
    function close_video_setting(varargin)
        hTag.hVideo = []; closereq;
        set(hTag.VideoSetting,'string','Settings');
    end
    function close_io_setting(varargin)
        hTag.hIO = []; closereq;
        set(hTag.IOSetting,'string','Settings');
    end
    function close_task_setting(varargin)
        hTag.hTask = []; closereq;
        set(hTag.TaskSetting,'string','Settings');
    end

    function check_cfg_change()
        if isequal(MLConfig,old_MLConfig), return, end
        options.Interpreter = 'tex';
        options.Default = 'No';
        button = questdlg('\fontsize{10}Do you want to save the current configuration?','The configuration has changed.','Yes','No',options);
        if strcmp(button,'Yes'), savecfg(MLPath.ConfigurationFile); end
    end
    function savecfg(filepath)
        if 2==exist(filepath,'file'), config = load(filepath); end
        if ~isempty(MLConfig.SubjectName), config.(['MLConfig_' lower(MLConfig.SubjectName)]) = MLConfig; end
        config.MLConfig = MLConfig;
        save(filepath,'-struct','config');
        old_MLConfig = MLConfig;

        try
            if exist(MLPath.DefaultConfigPath,'file')
                config = load(MLPath.DefaultConfigPath,'MLConfig'); field = MLConfig.IOFields;
                for m=1:length(field), config.MLConfig.(field{m}) = MLConfig.(field{m}); end
                save(MLPath.DefaultConfigPath,'-struct','config');
            end
        catch
            mlmessage('Invalid default IO configuration file!!!','e');
        end
    end
    function loaded = loadcfg(filepath,config_by_subject)
        loaded = true;
        if ~exist('filepath','var') || 2~=exist(filepath,'file'), return, end
        if ~exist('config_by_subject','var'), config_by_subject = 'MLConfig'; end

        content = whos('-file',filepath,config_by_subject);
        if isempty(content) || 0==content.bytes, loaded = false; return, end
        content = load(filepath,config_by_subject);
        if ~isa(content.(config_by_subject),'mlconfig')
            if isfield(content.(config_by_subject),'ImportFromStruct')
                content.(config_by_subject) = update(mlconfig,content.(config_by_subject));
            else
                error('Invalid config file: %s',strip_path(filepath));
            end
        end

        field = intersect(fieldnames(content.(config_by_subject)),fieldnames(MLConfig));
        for m=1:length(field), MLConfig.(field{m}) = content.(config_by_subject).(field{m}); end

        try
            if exist(MLPath.DefaultConfigPath,'file')
                config = load(MLPath.DefaultConfigPath,'MLConfig'); field = MLConfig.IOFields;
                for m=1:length(field), MLConfig.(field{m}) = config.MLConfig.(field{m}); end
            end
        catch
            mlmessage('Invalid default IO configuration file!!!','e');
        end

        if isempty(MLConfig.IO), MLConfig.IO = []; end
        refresh_boards(true);

        try
            [MLConfig.AudioEngine.ID,MLConfig.AudioEngine.Device,MLConfig.AudioEngine.Format,deviceName,formatString,info] = mglaudioengine(MLConfig.AudioEngine.ID,MLConfig.AudioEngine.Device,MLConfig.AudioEngine.Format);
            switch MLConfig.AudioEngine.ID
                case 1, MLConfig.AudioEngine.DeviceDesc = deviceName; MLConfig.AudioEngine.FormatDesc = formatString;
                case 2, MLConfig.AudioEngine.DeviceDesc = deviceName{MLConfig.AudioEngine.Device}; MLConfig.AudioEngine.FormatDesc = formatString;
                case 3, MLConfig.AudioEngine.DeviceDesc = deviceName{MLConfig.AudioEngine.Device}; MLConfig.AudioEngine.FormatDesc = formatString{MLConfig.AudioEngine.Format};
            end
            MLConfig.AudioEngine.DriverInfo = info;
        catch
            mlmessage('Incompatible audio engine settings!!!','e');
        end

        update_UI(true);  % sanity check
        old_MLConfig = MLConfig;
    end

    function mlmessage(text,varargin)
        if isempty(text), return, end
        nvarargs = length(varargin);
        if 0==nvarargs
            type = 'i';
        else
            nformat = length(regexp(text,'%[0-9\.\-+ #]*[diuoxXfeEgGcs]'));
            text = sprintf(text,varargin{1:nformat});
            if nformat < nvarargs
                type = varargin{end};
            elseif nvarargs == nformat
                type = 'i';
            else
                error('Not enough input arguments');
            end
        end
        fprintf('<<< MonkeyLogic >>> %s\n',text);

        switch lower(type(1))
            case 'e',  icon = 'warning.gif'; color = 'red';  % beep;
            case 'w',  icon = 'help_ex.png'; color = 'blue';
            otherwise, icon = 'help_gs.png'; color = 'black';
        end
        icon = fullfile(matlabroot,'toolbox/matlab/icons',icon);
        str = get(hMessagebox,'string');
        if verLessThan('matlab','25.1')
            str{end} =  sprintf('<html><img src="file:///%s" height="16" width="16">&nbsp;<font color="%s">%s</font></html>',icon,color,text);
            str{end+1} = '<html><font color="gray">>> End of the messages</font></html>';
        else
            str{end} =  text;
            str{end+1} = 'End of the messages';
        end
        set(hMessagebox,'string',str,'value',length(str));
        drawnow;
    end
    function error_handler(err)
        if isempty(err), return, end
        mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'e');
        rethrow(err);
    end
    function warning_handler(err)
        if isempty(err), return, end
        mlmessage('%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line,'w');
        warning(err.identifier,'%s (%s, Line %d)',err.message,err.stack(1).name,err.stack(1).line);
    end

    function op = fi(tf,op1,op2)
        if tf, op = op1; else, op = op2; end
    end
    function set_button_color(h,color,varargin)
        set(h,'backgroundcolor',color,'foregroundcolor',hsv2rgb(rem(rgb2hsv(color)+0.5,1)),varargin{:});
    end
    function str = set_listbox_item(h,item,varargin)
        items = get(h,'string');
        val = find(strcmpi(items,item),1);
        if isempty(val), val = 1; end
        set(h,'value',val,varargin{:});
        str = items{val};
    end
    function str = get_listbox_item(h)
        items = get(h,'string');
        val = get(h,'value');
        str = items{val};
    end
    function filename = strip_path(filepath,replacement)
        filename = '';
        if ~isempty(filepath)
            [~,filename,ext] = fileparts(filepath);
            filename = [filename ext];
        elseif exist('replacement','var')
            filename = replacement;
        end
    end
    function str = num2range(val)
        val = sort(val);
        c = 0; str = num2str(val(1));
        for m=2:length(val)
            if 1==val(m)-val(m-1)
                c = c + 1;
                continue;
            else
                switch c
                    case 0, str = [str ',' num2str(val(m))]; %#ok<*AGROW>
                    case 1, str = [str sprintf(',%d,%d',val(m-1:m))];
                    otherwise, str = [str sprintf(':%d,%d',val(m-1:m))];
                end
                c = 0;
            end
        end
        if 1==c, str = [str ',' num2str(val(end))]; elseif 1<c, str = [str ':' num2str(val(end))]; end
    end
    function xy = pointerlocation(h)
        if ischar(h), h = findobj('tag',h); end
        pos = get(gcf,'position') + get(h,'position');
        xy =  pos(1:2);
    end
end
