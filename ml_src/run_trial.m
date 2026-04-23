function varargout = run_trial(MLConfig,datafile)

varargout = cell(1);  % default output

MLPath = MLConfig.MLPath;
MLConditions = MLConfig.MLConditions;
DAQ = MLConfig.DAQ;
Screen = MLConfig.Screen;

TrialRecord = mltrialrecord(MLConfig);
userplotpath = MLConfig.UserPlotFunction; userplotfunc = get_function_handle(userplotpath);
if isempty(userplotfunc), userplotpath = [MLPath.ExperimentDirectory 'userplot.m']; userplotfunc = get_function_handle(userplotpath); end
if isempty(userplotfunc), TrialRecord.TaskInfo.UserPlotFunction = ''; else, TrialRecord.TaskInfo.UserPlotFunction = fileread(userplotpath); end
alertfunc = get_function_handle(MLPath.AlertFunction);
alert = ~isempty(alertfunc) && MLConfig.RemoteAlert;

hFig = [];
hTag = struct('Timeline',struct);
hListener = [];
MaxMessage = 5;
MessageString = {'<html><font color="gray">>> Message Box</font></html>'};
MenuItem = [];
MenuItemRect = [];
MenuHeight = [];
[~,ConditionsFileName] = fileparts(MLPath.ConditionsFile);
looping = true;
ControlScreenZoomRange = [5 300];
daq_warning = [];

uiTotalCorrectTrials = 0;
uiPerformanceOverAll = zeros(10,1);
uiPerformanceThisBlock = zeros(10,1);
uiPerformanceThisCond = zeros(10,1);

task_start_alerted = false;
block_start_alerted = false;
trial_start_alerted = false;

exception1 = [];
exception2 = [];
try
    init();
    
    % need to embed timining files before calling pause_menu() to make [v] work
    if isuserloopfile(MLConditions)
        userloop_handle = get_function_handle(MLConditions.Conditions);
        [taskobject,timingfile,trialholder] = userloop_handle(MLConfig,TrialRecord);
        if ischar(timingfile), timingfile = {timingfile}; end
        if iscell(timingfile)
            ntimingfile = length(timingfile);
            runtime_handle = cell(ntimingfile,2);
            for m=1:ntimingfile
                runtime_handle{m,1} = timingfile{m};
                runtime_handle{m,2} = get_function_handle(embed_timingfile(MLConfig,timingfile{m},trialholder));
            end
            runtime = runtime_handle{1,2};
        else
            runtime = timingfile;
        end
    else
        timingfile = MLConditions.UIVars.TimingFiles;
        ntimingfile = length(timingfile);
        runtime_handle = cell(ntimingfile,1);
        for m=1:ntimingfile, runtime_handle{m} = get_function_handle(embed_timingfile(MLConfig,timingfile{m})); end %#ok<*FXUP>
        runtime = runtime_handle{1};
        TrialRecord.TaskInfo.TimingFileByCond = MLConditions.UIVars.TimingFiles(MLConditions.UIVars.TimingFilesNo);
    end
    
    if TrialRecord.TestTrial
        TrialRecord.Pause = false;  % to turn off 'Escape'
        varargout{1} = runtime(MLConfig,TrialRecord,mltaskobject(taskobject,MLConfig),mltrialdata(DAQ));
        close(hFig);
        return
    end
    
    if isempty(MLConfig.SubjectName), editable_by_subject = 'MLEditable'; else, editable_by_subject = ['MLEditable_' lower(MLConfig.SubjectName)]; end
    editable = whos('-file',MLPath.ConfigurationFile,editable_by_subject);
    if ~isempty(editable), editable = load(MLPath.ConfigurationFile,editable_by_subject); TrialRecord.setEditable(editable.(editable_by_subject)); end
    TrialRecord.setDataFile(datafile);  % datafile does not exist for TestTrial
    
    if alert, alertfunc('init',MLConfig,TrialRecord); end
    if TrialRecord.Pause, set(hFig,'resize','on'); pause_menu(); if ishandle(hFig), set(hFig,'resize','off'); end, varargout{1} = MLConfig; end
    if TrialRecord.Quit || ~looping, error('early exit'); end
    
    fout = mlfileopen(datafile,'w');  % open data file
    MLConfig.export_to_file(fout);
    
    if alert, alertfunc('task_start',MLConfig,TrialRecord); task_start_alerted = true; end
    TrialRecord.TaskInfo.StartTime = now;
    
    TaskObject = [];
    clip_cursor = (MLConfig.Touchscreen.On||MLConfig.MouseKey.Mouse) && 1<mglgetadaptercount;
    for trial=1:MLConfig.TotalNumberOfTrialsToRun
        if clip_cursor && ~TrialRecord.SimulationMode, mglsetcursorpos(1); else, mglsetcursorpos(-1); end
        
        if isuserloopfile(MLConditions)
            [taskobject,timingfile] = userloop_handle(MLConfig,TrialRecord);  % keep in mind that the userloop function is called before the trial number counts up
            if ~isempty(TrialRecord.NextBlock) && TrialRecord.NextBlock < 0, break, end  % early exit
            BlockChange = TrialRecord.BlockChange; TrialRecord.new_trial(MLConfig);
            switch class(timingfile)
                case 'function_handle', runtime = timingfile;
                case 'char', runtime = runtime_handle{strcmpi(timingfile,runtime_handle(:,1)),2};
                case 'cell', runtime = runtime_handle{strcmpi(timingfile{1},runtime_handle(:,1)),2};
                otherwise, error('Unknown timing file type');
            end
        elseif isconditionsfile(MLConditions)
            BlockChange = TrialRecord.BlockChange; TrialRecord.new_trial(MLConfig);
            if ~isempty(TrialRecord.NextBlock) && TrialRecord.NextBlock < 0, break, end  % early exit
            taskobject = MLConditions.Conditions(TrialRecord.CurrentCondition).TaskObject;
            runtime = runtime_handle{MLConditions.UIVars.TimingFilesNo(TrialRecord.CurrentCondition)};
        end
        delete(TaskObject); TaskObject = mltaskobject(taskobject,MLConfig,TrialRecord);
        
        TrialData = mltrialdata(DAQ);
        TrialData.Trial = TrialRecord.CurrentTrialNumber;
        TrialData.BlockCount = TrialRecord.CurrentBlockCount;
        TrialData.TrialWithinBlock = TrialRecord.CurrentTrialWithinBlock;
        TrialData.Block = TrialRecord.CurrentBlock;
        TrialData.Condition = TrialRecord.CurrentCondition;
        TrialData.VariableChanges = copyfield(TrialData.VariableChanges,TrialRecord.Editable,mlsetdiff(fieldnames(TrialRecord.Editable),'editable'));
        if isfield(TaskObject.Info,'Attribute'), TrialData.TaskObject = struct('Attribute',{TaskObject.Info.Attribute},'Size',TaskObject.Size); else, TrialData.TaskObject = struct('Attribute',TaskObject.Info,'Size',TaskObject.Size); end
        
        if alert
            if BlockChange, alertfunc('block_start',MLConfig,TrialRecord); block_start_alerted = true; end
            alertfunc('trial_start',MLConfig,TrialRecord); trial_start_alerted = true;
        end
        pretrial_uiupdate();
        
        runtime(MLConfig,TrialRecord,TaskObject,TrialData);
        
        TrialData.export_to_file(fout);
        TrialRecord.update_trial_result(TrialData,MLConfig);
        
        editable = TrialRecord.Editable; TrialRecord.setEditable(copyfield(editable,TrialData.VariableChanges));
        MLConfig.EyeTransform{1,MLConfig.EyeCalibration(1)} = TrialData.NewEyeTransform;
        MLConfig.EyeTransform{2,MLConfig.EyeCalibration(2)} = TrialData.NewEye2Transform;
        for m=1:length(TrialData.UserMessage), mlmessage(TrialData.UserMessage{m}{:}); end
        
        posttrial_uiupdate();
        if alert
            trial_start_alerted = false; alertfunc('trial_end',MLConfig,TrialRecord);
            if TrialRecord.BlockChange, block_start_alerted = false; alertfunc('block_end',MLConfig,TrialRecord); end
        end
        
        if TrialRecord.Pause, TrialRecord.InterTrialIntervalTimer = []; set(hFig,'resize','on'); pause_menu(); if ishandle(hFig), set(hFig,'resize','off'); end, varargout{1} = MLConfig; end
        if TrialRecord.Quit || ~looping, break, end
    end
catch exception1
    if strcmp('early exit',exception1.message), exception1 = []; end
    mdqmex(40,2,3);  % terminate threads
end

if trial_start_alerted, try alertfunc('trial_end',MLConfig,TrialRecord); catch e, warning(e.message); end, end
if block_start_alerted, try alertfunc('block_end',MLConfig,TrialRecord); catch e, warning(e.message); end, end
if task_start_alerted, try alertfunc(fi(isempty(exception1),'task_end','task_aborted'),MLConfig,TrialRecord); catch e, warning(e.message); end, end
if ishandle(hFig), close(hFig); end

if exist('fout','var')
    try
        TrialRecord.TaskInfo.Stimuli = TrialRecord.TaskInfo.Stimuli(~cellfun(@isempty,TrialRecord.TaskInfo.Stimuli))';
        TrialRecord.export_to_file(fout);
        
        % save stimuli
        if MLConfig.SaveStimuli && ~isempty(TrialRecord.TaskInfo.Stimuli)
            Stimuli = struct;
            for m=1:length(TrialRecord.TaskInfo.Stimuli)
                if 2~=exist(TrialRecord.TaskInfo.Stimuli{m},'file'), continue, end
                [~,n,e] = fileparts(TrialRecord.TaskInfo.Stimuli{m});
                Stimuli(m).name = [n e];
                fid = fopen(TrialRecord.TaskInfo.Stimuli{m},'r');
                Stimuli(m).contents = fread(fid,Inf,'*uint8');
                fclose(fid);
            end
            if ~isopen(fout), open(fout,fout.filename,'a'); end
            fout.write(Stimuli,'Stimuli',false);
        end
    catch exception2
    end
    close(fout);
end

if alert, try alertfunc('fini',MLConfig,TrialRecord); catch e, warning(e.message); end, end
if ~isempty(exception1), rethrow(exception1); end
if ~isempty(exception2), rethrow(exception2); end


    function pretrial_uiupdate()
        set(hFig,'name',sprintf('[%s: %s]  Start: %s  (Elapsed: %s)',ConditionsFileName,MLConfig.SubjectName,datestr(TrialRecord.TaskInfo.StartTime,'yyyy-mm-dd HH:MM:SS'), ...
            datestr(now-TrialRecord.TaskInfo.StartTime,'HH:MM:SS')));
        
        set(hTag.TrialNo,'string',num2str(TrialRecord.CurrentTrialNumber));
        set(hTag.BlockNo,'string',num2str(TrialRecord.CurrentBlock));
        set(hTag.CondNo,'string',num2str(TrialRecord.CurrentCondition));
        set(hTag.TrialsInThisBlock,'string',num2str(TrialRecord.CurrentTrialWithinBlock));
        set(hTag.BlocksCompleted,'string',num2str(TrialRecord.CurrentBlockCount-1));
        
        if 32<length(TrialRecord.TrialErrors), TrialErrorsInAllConds = sprintf('%d',TrialRecord.TrialErrors(end-31:end)); else, TrialErrorsInAllConds = sprintf('%d',TrialRecord.TrialErrors); end
        set(hTag.TrialErrorsInAllConds1,'string',TrialErrorsInAllConds);
        set(hTag.TrialErrorsInAllConds2,'string','');
        
        count = TrialRecord.TrialErrors(TrialRecord.ConditionsPlayed==TrialRecord.CurrentCondition);
        if 32<length(count), TrialErrorsInThisCond = sprintf('%d',count(end-31:end)); else, TrialErrorsInThisCond = sprintf('%d',count); end
        set(hTag.TrialErrorsInThisCond1,'string',TrialErrorsInThisCond);
        set(hTag.TrialErrorsInThisCond2,'string','');
        
        if size(uiPerformanceThisBlock,2)<TrialRecord.CurrentBlock, uiPerformanceThisBlock(end,TrialRecord.CurrentBlock) = 0; end
        if size(uiPerformanceThisCond,2)<TrialRecord.CurrentCondition, uiPerformanceThisCond(end,TrialRecord.CurrentCondition) = 0; end
        f = uiPerformanceOverAll; s = sum(f);
        set(hTag.PerformanceOverAll2,'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceOverAll',f);
        f = uiPerformanceThisBlock(:,TrialRecord.CurrentBlock); s = sum(f);
        set(hTag.PerformanceThisBlock2,'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceThisBlock',f);
        f = uiPerformanceThisCond(:,TrialRecord.CurrentCondition); s = sum(f);
        set(hTag.PerformanceThisCond2,'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceThisCond',f);
        
        if ~isempty(TrialRecord.InterTrialIntervalTimer)
            iti_elapsed = toc(TrialRecord.InterTrialIntervalTimer) * 1000;
            if TrialRecord.InterTrialInterval < iti_elapsed, mlmessage('Trial %d: Desired ITI exceeded (ITI ~= %d ms)',TrialData.Trial-1,round(iti_elapsed),'w'); end
        end
        drawnow;
    end
    function posttrial_uiupdate()
        TrialRecord.TaskInfo.EndTime = now;
        set(hFig,'name',sprintf('[%s: %s]  Start: %s  (Elapsed: %s)',ConditionsFileName,MLConfig.SubjectName,datestr(TrialRecord.TaskInfo.StartTime,'yyyy-mm-dd HH:MM:SS'), ...
            datestr(TrialRecord.TaskInfo.EndTime-TrialRecord.TaskInfo.StartTime,'HH:MM:SS')));
        
        if TrialRecord.BlockChange, set(hTag.BlocksCompleted,'string',num2str(TrialRecord.CurrentBlockCount)); end
        if 0==TrialData.TrialError, uiTotalCorrectTrials = uiTotalCorrectTrials + 1; end
        set(hTag.TotalCorrectTrials,'string',num2str(uiTotalCorrectTrials));
        switch TrialData.Ver
            case 1
                set(hTag.MaxLatency,'string',sprintf('%.1f ms',TrialData.CycleRate(1)));
                set(hTag.CycleRate,'string',sprintf('%d Hz',TrialData.CycleRate(2)));
            otherwise
                set(hTag.MaxLatency,'string',sprintf('%.2f ms',TrialData.CycleRate(1)));
                set(hTag.CycleRate,'string',sprintf('%.2f ms',TrialData.CycleRate(2)));
        end
        set(hTag.TrialErrorsInAllConds2,'string',num2str(TrialData.TrialError));
        set(hTag.TrialErrorsInThisCond2,'string',num2str(TrialData.TrialError));
        
        % update performance bar
        row = TrialData.TrialError + 1;
        uiPerformanceOverAll(row) = uiPerformanceOverAll(row) + 1;
        uiPerformanceThisBlock(row,TrialData.Block) = uiPerformanceThisBlock(row,TrialData.Block) + 1;
        uiPerformanceThisCond(row,TrialData.Condition) = uiPerformanceThisCond(row,TrialData.Condition) + 1;
        f = uiPerformanceOverAll; s = sum(f);
        set(hTag.PerformanceOverAll2,'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceOverAll',f);
        f = uiPerformanceThisBlock(:,TrialData.Block); s = sum(f);
        set(hTag.PerformanceThisBlock2,'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceThisBlock',f);
        f = uiPerformanceThisCond(:,TrialData.Condition); s = sum(f);
        set(hTag.PerformanceThisCond2,'string',sprintf(fi(1==f(1)/s,'%.0f%%','%.1f%%'),fi(0==s,0,f(1)*100/s)));
        performance_bar_update('PerformanceThisCond',f);
        
        % update timeline
        if TrialRecord.DrawTimeLine
            set(hFig,'CurrentAxes',hTag.hTimeline);
            for m=fieldnames(hTag.Timeline)', delete(hTag.Timeline.(m{1})); end, hTag.Timeline = struct;
            fontsize = 9;
            hTag.Timeline.header = text(0.5,0.94,sprintf('Trial #%d, Cond #%d',TrialData.Trial,TrialData.Condition),'horizontalalignment','center');
            set(hTag.Timeline.header,'color',[1 1 1],'fontsize',fontsize,'fontweight','bold');
            code = TrialData.BehavioralCodes.CodeNumbers;
            if MLConfig.NonStopRecording
                time = TrialData.BehavioralCodes.CodeTimes - TrialData.BehavioralCodes.CodeTimes(1);
            else
                time = TrialData.BehavioralCodes.CodeTimes;
            end
            ncode = length(code);
            maxtime = max(time);
            if 0<ncode && 0<maxtime
                tick = 0:1000:maxtime;
                y = 0.9 - 0.85 * tick / maxtime;
                x1 = 0.25 * ones(size(y));
                x2 = 0.28 * ones(size(y));
                hTag.Timeline.sec = line([x1; x2],[y; y]);
                set(hTag.Timeline.sec,'color',[1 0 0],'linewidth',2);
                
                y = 0.9 - 0.85 * time' / maxtime;
                x1 = 0.24 * ones(size(y));
                x2 = 0.29 * ones(size(y));
                hTag.Timeline.tick = line([x1; x2],[y; y]);
                set(hTag.Timeline.tick,'color',[1 1 1],'linewidth',1);
                
                BehavioralCodes = TrialRecord.TaskInfo.BehavioralCodes;
                if ~isempty(BehavioralCodes)
                    [a,b] = ismember(code,BehavioralCodes.CodeNumbers);
                    b(~a) = length(BehavioralCodes.CodeNames)+1;
                    codenames = [BehavioralCodes.CodeNames; {''}];
                    hTag.Timeline.label = text(x2+0.03,y,codenames(b));
                    set(hTag.Timeline.label,'color',[1 1 1],'fontsize',fontsize,'fontweight','bold');
                end
                hTag.Timeline.time = text(x1-0.03,y,num2str(round(time)));
                set(hTag.Timeline.time,'color',[1 1 1],'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
            end
        end
        
        % update userplot
        set(hFig,'CurrentAxes',hTag.hUserplot);
        if isempty(userplotfunc)
            hist(TrialRecord.ReactionTimes); %#ok<HIST>
            xlabel('Time (msec)');
            ylabel('Number of trials');
            title('Reaction Times');
        else
            if 1<nargin(userplotfunc), userplotfunc(TrialRecord,MLConfig); else, userplotfunc(TrialRecord); end
        end
        drawnow;
    end
    function performance_bar_update(tag,rate)
        s = sum(rate); if 0==s, s=1; end
        sz = get(hTag.(tag),'position');
        if isscalar(rate), for m=1:10, set(hTag.PerformanceBar.(tag)(1,m),'visible','off'); end, return, end
        w = rate(:) / s * sz(3);
        left = [0; cumsum(w)];
        for m=1:10
            if 0<w(m)
                set(hTag.PerformanceBar.(tag)(1,m),'visible','on','position',[sz(1)+left(m) sz(2) w(m) sz(4)]);
            else
                set(hTag.PerformanceBar.(tag)(1,m),'visible','off');
            end
            if 11<w(m)
                set(hTag.PerformanceBar.(tag)(2,m),'visible','on','position',[sz(1)+left(m)+w(m)/2-5 sz(2)+1 10 16]);
            else
                set(hTag.PerformanceBar.(tag)(2,m),'visible','off');
            end
        end
    end

    function pause_menu()
        if 0~=TrialRecord.CurrentTrialNumber
            set(hFig,'name',sprintf('[%s: %s]  Start: %s  End: %s  (Elapsed: %s)',ConditionsFileName,MLConfig.SubjectName,datestr(TrialRecord.TaskInfo.StartTime,'yyyy-mm-dd HH:MM:SS'), ...
                datestr(TrialRecord.TaskInfo.EndTime,'yyyy-mm-dd HH:MM:SS'),datestr(TrialRecord.TaskInfo.EndTime-TrialRecord.TaskInfo.StartTime,'HH:MM:SS')));
            if alert, alertfunc('task_paused',MLConfig,TrialRecord); end
        end
        TrialRecord.Pause = false;
        set([hTag.operatorview1 hTag.operatorview2],'enable','on');
        
        show_screen(true,false);
        mglsetcursorpos(-1);
        mglactivategraphic(mglgetallobjects,false);
        
        fontface = 'Segoe UI'; fontsize = 20;
        x = -150; y = 0;
        MenuItem = [mgladdbox([0 0 0; 0 0 0],Screen.SubjectScreenFullSize,2) 0 0 NaN];  % [id x_offset y_offset keycode]
        
        MenuItem(end+1,:) = [mgladdtext('Paused',12) 0 y NaN];
        mglsetproperty(MenuItem(end,1),'font',fontface,fontsize,'bold','center');
        
        y = y + 60;
        MenuItem(end+1,:) = [mgladdtext(sprintf('Conditions: %s',ConditionsFileName),12) x y NaN];
        mglsetproperty(MenuItem(end,1),'color',[0 1 0]);
        
        y = y + 30;
        MenuItem(end+1,:) = [mgladdtext(sprintf('Subject: %s',MLConfig.SubjectName),12) x y NaN];
        mglsetproperty(MenuItem(end,1),'color',[0 1 0]);
        
        y = y + 40;
        MenuItem(end+1,:) = [mgladdtext(['[Space]: ' fi(0==TrialRecord.CurrentTrialNumber,'Start','Resume')],12) x y 57];
        MenuItem(end+1,:) = [mgladdtext('[Q]: Quit',12) x+200 y 16];
        
        y = y + 30;
        MenuItem(end+1,:) = [mgladdtext('[B]: Select a new block',12) x y 48];
        
        if MLConditions.isconditionsfile()
            y = y + 30;
            MenuItem(end+1,:) = [mgladdtext('[X]: Alter behavioral-error handling',12) x y 45];
        end
        
        eye_cal = DAQ.eye_present() && 1<MLConfig.EyeCalibration(1);
        eye2_cal = DAQ.eye2_present() && 1<MLConfig.EyeCalibration(2);
        if eye_cal
            y = y + 30;
            if ~eye2_cal
                MenuItem(end+1,:) = [mgladdtext('[E]: Recalibrate eye signals',12) x y 18];
            else
                MenuItem(end+1,:) = [mgladdtext('[E]: Recal Eye1',12) x y 18];
                MenuItem(end+1,:) = [mgladdtext('[R]: Recal Eye2',12) x+200 y 19];
            end
        elseif eye2_cal
            y = y + 30;
            MenuItem(end+1,:) = [mgladdtext('[R]: Recalibrate Eye2',12) x y 19];
        end
        
        if DAQ.eye_present() || DAQ.eye2_present()
            y = y + 30;
            MenuItem(end+1,:) = [mgladdtext('[D]: Eye auto drift correction',12) x y 32];
        end
        
        joy_cal = DAQ.joystick_present() && 1<MLConfig.JoystickCalibration(1);
        joy2_cal = DAQ.joystick2_present() && 1<MLConfig.JoystickCalibration(2);
        if joy_cal
            y = y + 30;
            if ~joy2_cal
                MenuItem(end+1,:) = [mgladdtext('[J]: Recalibrate joystick signals',12) x y 36];
            else
                MenuItem(end+1,:) = [mgladdtext('[J]: Recal Joystick1',12) x y 36];
                MenuItem(end+1,:) = [mgladdtext('[K]: Recal Joystick2',12) x+200 y 37];
            end
        elseif joy2_cal
            y = y + 30;
            MenuItem(end+1,:) = [mgladdtext('[K]: Recalibrate Joystick2',12) x y 37];
        end
        
        if 0 < DAQ.nIO()
            y = y + 30;
            if isempty(DAQ.Webcam{1})
                MenuItem(end+1,:) = [mgladdtext('[I]: I/O test',12) x y 23];
            else
                MenuItem(end+1,:) = [mgladdtext('[I]: I/O test',12) x y 23];
                MenuItem(end+1,:) = [mgladdtext('[W]: Webcam',12) x+200 y 17];
            end
        elseif ~isempty(DAQ.Webcam{1})
            y = y + 30;
            MenuItem(end+1,:) = [mgladdtext('[W]: Webcam setup',12) x y 17];
        end
        
        if ~isempty(TrialRecord.Editable)
            y = y + 30;
            MenuItem(end+1,:) = [mgladdtext('[V]: Edit timing file variables',12) x y 47];
        end
        
        y = y + 30;
        MenuItem(end+1,:) = [mgladdtext(['[S]: Simulation mode is ' fi(TrialRecord.SimulationMode,'ON','OFF')],12) x y 31];
        
        daq_warning = [mgladdtext('Data is still being recorded. Resume or quit before memory runs out.',12) mgladdtext('',12)];
        mglsetproperty(daq_warning,'active',DAQ.isrunning,'color',[0 1 1],'font',fontface,13,'bold','center');

        fontsize = 16; mglsetproperty(MenuItem(3:end,1),'font',fontface,fontsize,'bold');
        MenuItem(:,2:3) = MenuItem(:,2:3) * Screen.DPI_ratio;
        MenuItemRect = zeros(size(MenuItem,1)-4,4);
        MenuHeight = (y+35) * Screen.DPI_ratio;
        reposition_menuitem();
        
        if DAQ.mouse_present, mouse = DAQ.get_device('mouse'); else, mouse = pointingdevice; end
        selected = NaN;
        kbdflush;
        
        timer = tic;
        time_counter = -1;
        byte_to_mb = 1 / 2^20;
        mglenabletouchclick(true);
        while looping
            k = []; [xy,buttons] = getsample(mouse); buttons = buttons(1:2);  % remove keycodes
            cs = mglgetscreeninfo(2,'Rect');
            xy = xy - cs(1:2);
            hover = find(MenuItemRect(:,1)<xy(1) & xy(1)<MenuItemRect(:,3) & MenuItemRect(:,2)<xy(2) & xy(2)<MenuItemRect(:,4),1);
            mglsetproperty(MenuItem(5:end-1,1),'color',[1 1 1]);
            mglsetproperty(MenuItem(end,1),'color',fi(TrialRecord.SimulationMode,[1 0 0],[1 1 1]));
            if ~isempty(hover), mglsetproperty(MenuItem(4+hover,1),'color',[1 1 0]); end
            if any(buttons)
                if ~isempty(hover) && isnan(selected), selected = MenuItem(4+hover,4); end
            else
                if ~isnan(selected), k = selected; selected = NaN; else, k = kbdgetkey; end
            end
            if DAQ.isrunning
                a = floor(toc(timer));
                if time_counter~=a
                    time_counter = a;
                    b = memory; mglsetproperty(daq_warning(2),'text',sprintf('Used: %.0f MB, Available: %.0f MB',[b.MemUsedMATLAB b.MaxPossibleArrayBytes]*byte_to_mb));
                end
            end
            mglrendergraphic(0,2);
            mglpresent(2);
            
            if ~isempty(k)
                try
                    switch k
                        case 57  % space
                            if 0~=TrialRecord.CurrentTrialNumber && alert, alertfunc('task_resumed',MLConfig,TrialRecord); end
                            break;
                        case 16, TrialRecord.Quit = true; break;  % q
                        case 48, DlgSelectBlock();  % b
                        case 45  % x
                            if MLConditions.isconditionsfile(), DlgSelectErrorLogic(); end
                        case 18  % e
                            if eye_cal
                                set_on_move([]);  % old MATLAB versions (at least R2017b) trigger an unnecessary move event in the control screen window in Win10
                                switch MLConfig.EyeCalibration(1)
                                    case 2, MLConfig.EyeTransform{1,MLConfig.EyeCalibration(1)} = mlcalibrate_origin_gain(1,MLConfig,1);
                                    case 3, MLConfig.EyeTransform{1,MLConfig.EyeCalibration(1)} = mlcalibrate_spatial_transform(1,MLConfig,1);
                                end
                                set_on_move();
                            end
                        case 19  % r
                            if eye2_cal
                                set_on_move([]);
                                switch MLConfig.EyeCalibration(2)
                                    case 2, MLConfig.EyeTransform{2,MLConfig.EyeCalibration(2)} = mlcalibrate_origin_gain(1,MLConfig,2);
                                    case 3, MLConfig.EyeTransform{2,MLConfig.EyeCalibration(2)} = mlcalibrate_spatial_transform(1,MLConfig,2);
                                end
                                set_on_move();
                            end
                        case 32, if DAQ.eye_present() || DAQ.eye2_present(), DlgAutoDriftCorrection(); end  %d
                        case 36  % j
                            if joy_cal
                                set_on_move([]);
                                switch MLConfig.JoystickCalibration(1)
                                    case 2, MLConfig.JoystickTransform{1,MLConfig.JoystickCalibration(1)} = mlcalibrate_origin_gain(2,MLConfig,1);
                                    case 3, MLConfig.JoystickTransform{1,MLConfig.JoystickCalibration(1)} = mlcalibrate_spatial_transform(2,MLConfig,1);
                                end
                                set_on_move();
                            end
                        case 37  % k
                            if joy2_cal
                                set_on_move([]);
                                switch MLConfig.JoystickCalibration(2)
                                    case 2, MLConfig.JoystickTransform{2,MLConfig.JoystickCalibration(2)} = mlcalibrate_origin_gain(2,MLConfig,2);
                                    case 3, MLConfig.JoystickTransform{2,MLConfig.JoystickCalibration(2)} = mlcalibrate_spatial_transform(2,MLConfig,2);
                                end
                                set_on_move();
                            end
                        case 23, if 0 < DAQ.nIO(), set_on_move([]); MLConfig.IOTestParam = mliotest(MLConfig); set_on_move(); end  % i
                        case 17, if ~isempty(DAQ.Webcam{1}), DlgWebcamSetup(); end  % w
                        case 47, if ~isempty(TrialRecord.Editable), DlgEditableVariables(); end  % v
                        case 31  % s
                            TrialRecord.SimulationMode = ~TrialRecord.SimulationMode;
                            mglsetproperty(MenuItem(end,1),'text',['[S]: Simulation mode is ' fi(TrialRecord.SimulationMode,'ON','OFF')]);
                    end
                catch  % to prevent dialog errors from stopping the task 
                    set_on_move();
                end
                kbdflush;
            end
            pause(0.02);
        end
        mglenabletouchclick(false);
        
        if ishandle(hFig)
            mgldestroygraphic([MenuItem(:,1); daq_warning']); MenuItem = [];  % make sure that MenuItem is empty. See reposition_menuitem().
            set([hTag.operatorview1 hTag.operatorview2],'enable','off');
            show_screen(true,true);
        end
    end
    function reposition_menuitem()
        if isempty(MenuItem), return, end
        nMenuItem = size(MenuItem,1);
        csrc = mglgetscreeninfo(2,'Rect');
        cssz = csrc(3:4) - csrc(1:2);
        mglsetproperty(MenuItem(2:end,1),'origin',repmat(0.5*(cssz - [0 MenuHeight]),nMenuItem-1,1) + MenuItem(2:end,2:3));
        for item=1:nMenuItem-4, MenuItemRect(item,:) = mglgetproperty(MenuItem(item+4,1),'rect'); end
        if DAQ.isrunning, mglsetproperty(daq_warning,'origin',repmat([0.5 1].*cssz,2,1) + [0 -70; 0 -40]); end
    end

    function DlgWebcamSetup()
        show_screen(false,false);
        pos = get(hFig,'position'); w = 360; h = 30*DAQ.nWebcam + 90; xy = pos(1:2) + pos(3:4)/2 - [w h]/2;
        hDlg = figure; fontsize = 9; bgcolor = [0.9255 0.9137 0.8471];
        set(hDlg,'units','pixels','position',[xy w h],'menubar','none','numbertitle','off','name','WebcamSetup','color',bgcolor,'windowstyle','modal');
        
        err = [];
        try
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-140 10 60 25],'tag','done','string','Done','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-70 10 60 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',@dlg_proc);
            for m=1:DAQ.nWebcam
                if isempty(DAQ.Webcam{m}), continue, end
                y0 = h - 30*m - 10;
                uicontrol('parent',hDlg,'style','text','position',[10 y0 300 22],'string',[sprintf('#%d, ',m) DAQ.Webcam{m}.Name],'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
                uicontrol('parent',hDlg,'style','pushbutton','position',[325 y0 25 25],'tag',sprintf('WebcamSetup%d',m),'string','...','fontsize',fontsize,'callback',@dlg_proc);
            end
            
            property = MLConfig.Webcam;
            exit_code = 0; dlg_wait();
            if 1==exit_code, MLConfig.Webcam = property; end
        catch err
        end
        if ishandle(hDlg), close(hDlg); end
        show_screen(true,false);
        if ~isempty(err), rethrow(err); end
        
        function dlg_wait()
            kbdflush;
            while 0==exit_code
                if ~ishandle(hDlg), exit_code = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, exit_code = -1; end
                pause(0.05);
            end
        end
        function dlg_proc(hObject,~)
            obj_tag = get(hObject,'tag');
            switch obj_tag(1:min(length(obj_tag),10))
                case 'done', exit_code = 1;
                case 'cancel', exit_code = -1;
                case 'WebcamSetu'
                    no = str2double(regexp(obj_tag,'\d+','match'));
                    property(no).Property = mlwebcamsetup(DAQ.Webcam{no});
            end
        end
    end

    function DlgSelectBlock()
        show_screen(false,false);
        pos = get(hFig,'position'); w = 155 ; h = 180; xy = pos(1:2) + pos(3:4)/2 - [w h]/2;
        hDlg = figure; fontsize = 9; bgcolor = [0.9255 0.9137 0.8471];
        set(hDlg,'units','pixels','position',[xy w h],'menubar','none','numbertitle','off','name','Block Selection','color',bgcolor,'windowstyle','modal');
        
        err = [];
        try
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-140 10 60 25],'tag','done','string','Done','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-70 10 60 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','text','position',[0 149 155 22],'string','Next Block to Run','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
            hlist = uicontrol('parent',hDlg,'style','listbox','position',[50 45 60 106],'min',0,'max',1,'string',num2cell(TrialRecord.BlocksSelected),'fontsize',fontsize);
            
            exit_code = 0; dlg_wait();
            if 1==exit_code, TrialRecord.NextBlock = TrialRecord.BlocksSelected(get(hlist,'value')); end
        catch err
        end
        if ishandle(hDlg), close(hDlg); end
        show_screen(true,false);
        if ~isempty(err), rethrow(err); end
        
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

    function DlgSelectErrorLogic()
        show_screen(false,false);
        pos = get(hFig,'position'); w = 155 ; h = 180; xy = pos(1:2) + pos(3:4)/2 - [w h]/2;
        error_logic = {'ignore','repeat immediately','repeat delayed'};
        hDlg = figure; fontsize = 9; bgcolor = [0.9255 0.9137 0.8471];
        set(hDlg,'units','pixels','position',[xy w h],'menubar','none','numbertitle','off','name','Error Logic','color',bgcolor,'windowstyle','modal');
        
        err = [];
        try
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-140 10 60 25],'tag','done','string','Done','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-70 10 60 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','text','position',[0 149 155 22],'string','Error Handling','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
            hlist = uicontrol('parent',hDlg,'style','listbox','position',[10 45 135 106],'min',0,'max',1,'string',error_logic,'fontsize',fontsize);
            
            exit_code = 0; dlg_wait();
            if 1==exit_code, TrialRecord.setErrorLogic(get(hlist,'value')); end
        catch err
        end
        if ishandle(hDlg), close(hDlg); end
        show_screen(true,false);
        if ~isempty(err), rethrow(err); end
        
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

    function DlgAutoDriftCorrection()
        show_screen(false,false);
        pos = get(hFig,'position'); w = 255 ; h = 75; xy = pos(1:2) + pos(3:4)/2 - [w h]/2;
        hDlg = figure; fontsize = 9; bgcolor = [0.9255 0.9137 0.8471];
        set(hDlg,'units','pixels','position',[xy w h],'menubar','none','numbertitle','off','name','Eye auto drift correction','color',bgcolor,'windowstyle','modal');
        
        err = [];
        try
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-140 10 60 25],'tag','done','string','Done','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-70 10 60 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','text','position',[0 h-30 150 22],'string','Auto drift correction :','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
            hedit = uicontrol('parent',hDlg,'style','edit','position',[145 h-27 100 22],'string',MLConfig.EyeAutoDriftCorrection,'fontsize',fontsize,'fontweight','bold');
            
            exit_code = 0; dlg_wait();
            if 1==exit_code, MLConfig.EyeAutoDriftCorrection = str2double(get(hedit,'string')); end
        catch err
        end
        if ishandle(hDlg), close(hDlg); end
        show_screen(true,false);
        if ~isempty(err), rethrow(err); end
        
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

    function DlgEditableVariables()
        show_screen(false,false);
        MLEditable = TrialRecord.Editable;
        max_nfield = 25; field = fieldnames(MLEditable); field = field(~strcmp(field,'editable')); nfield = length(field);
        vscroll = max_nfield < nfield;
        
        sw = 515; sh = 25 * nfield;
        if vscroll
            w = sw + 23;
        else
            max_nfield = nfield;
            w = sw;
        end
        srange = 25 * (nfield-max_nfield);
        pb = 45; pw = sw; ph = 25 * max_nfield;
        h = 25 * max_nfield + 70;
        pos = get(hFig,'position');
        xy = pos(1:2) + pos(3:4)/2 - [w h]/2;
        
        hDlg = figure; fontsize = 9; bgcolor = [0.9255 0.9137 0.8471];
        set(hDlg,'units','pixels','position',[xy w h],'menubar','none','numbertitle','off','name','Editable variables','color',bgcolor,'windowstyle','modal');
        
        err = [];
        try
            hpanel = uipanel('parent',hDlg,'units','pixels','position',[0 pb pw ph],'bordertype','none','backgroundcolor',bgcolor);
            hEditable = uipanel('parent',hpanel,'units','pixels','position',[0 -srange sw sh],'bordertype','none','backgroundcolor',bgcolor);
            b = h-25;
            uicontrol('parent',hDlg,'style','text','position',[27 10 300 22],'string','* Resetting variables requires restarting the task.','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-140 10 60 25],'tag','done','string','Save','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-70 10 60 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','text','position',[5 b 60 22],'string','Reset','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
            uicontrol('parent',hDlg,'style','text','position',[65 b 195 22],'string','Variables','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
            uicontrol('parent',hDlg,'style','text','position',[265 b 245 22],'string','Values','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
            if vscroll, uicontrol('parent',hDlg,'style','slider','tag','scrolleditable','min',0,'max',srange,'sliderstep',[1 1]/(nfield-max_nfield),'value',srange,'position',[sw pb 18 ph],'callback',@dlg_proc); end
            
            tag = struct;
            for m=1:nfield
                f = field{m};
                v = MLEditable.(f);
                cb = sh - 25*m;
                tag.([f '_reset_']) = uicontrol('parent',hEditable,'style','checkbox','position',[27 cb+6 15 15],'backgroundcolor',bgcolor);
                uicontrol('parent',hEditable,'style','text','position',[65 cb 195 22],'string',[f ' :'],'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                switch MLEditable.editable.(f)
                    case 'file'
                        tag.(f) = uicontrol('parent',hEditable,'style','edit','position',[265 cb+3 215 22],'tag',f,'string',v,'fontsize',fontsize);
                        uicontrol('parent',hEditable,'style','pushbutton','position',[485 cb+3 25 22],'string','...','fontsize',fontsize,'fontweight','bold', ...
                            'callback',sprintf('p = uigetfile(''*.*''); if 0~=p, set(findobj(''tag'',''%s''),''string'',p); end, drawnow; pause(0.3); kbdflush;',f));
                    case 'dir'
                        tag.(f) = uicontrol('parent',hEditable,'style','edit','position',[265 cb+3 215 22],'tag',f,'string',v,'fontsize',fontsize);
                        uicontrol('parent',hEditable,'style','pushbutton','position',[485 cb+3 25 22],'string','...','fontsize',fontsize,'fontweight','bold', ...
                            'callback',sprintf('p = uigetdir; if 0~=p, set(findobj(''tag'',''%s''),''string'',p); end, drawnow; pause(0.3); kbdflush;',f));
                    case 'color'
                        uicontrol('parent',hEditable,'style','text','position',[265 cb 180 22],'tag',f,'string',sprintf('[%.3f  %.3f  %.3f]',v),'backgroundcolor',bgcolor,'fontsize',fontsize);
                        tag.(f) = uicontrol('parent',hEditable,'style','pushbutton','position',[450 cb+4 60 22],'string','Color','backgroundcolor',v,'foregroundcolor',1-v,'fontsize',fontsize, ...
                            'callback',sprintf('c = uisetcolor; if ~isscalar(c), set(findobj(''tag'',''%s''),''string'',sprintf(''[%%.3f  %%.3f  %%.3f]'',c)); set(gcbo,''backgroundcolor'',c,''foregroundcolor'',1-c); end, drawnow; pause(0.3); kbdflush;',f));
                    case 'category'
                        idx = find(strcmp(v(1:end-1),v{end}),1);
                        tag.(f) = uicontrol('parent',hEditable,'style','popupmenu','position',[265 cb+3 245 22],'string',v(1:end-1),'value',idx,'fontsize',fontsize);
                    case 'range'
                        tag.(f) = uicontrol('parent',hEditable,'style','edit','position',[265 cb+3 60 22],'tag',f,'string',v(end),'fontsize',fontsize, ...
                            'callback',sprintf('set(gcbo,''string'',max(%f,min(%f,str2double(get(gcbo,''string'')))));',v(1:2)));
                        uicontrol('parent',hEditable,'style','slider','Position',[330 cb+3 180 22],'min',v(1),'max',v(2),'value',v(end),'fontsize',fontsize, ...
                            'callback',sprintf('v = min(%f,%f+%f*round((get(gcbo,''value'')-%f)/%f)); set(findobj(''tag'',''%s''),''string'',v);',v([2 1 3 1 3]),f));
                    otherwise
                        if islogical(v)
                            for n=1:numel(v), x = 275 + (n-1)*40; tag.(f)(n) = uicontrol('parent',hEditable,'style','checkbox','position',[x cb+6 15 15],'value',v(n)); end
                        elseif isnumeric(v)
                            w = 250/numel(v); for n=1:numel(v), x = 265 + (n-1)*w; tag.(f)(n) = uicontrol('parent',hEditable,'style','edit','position',[x cb+3 w-5 22],'string',num2str(v(n)),'fontsize',fontsize); end
                        else
                            tag.(f) = uicontrol('parent',hEditable,'style','edit','position',[265 cb+3 245 22],'string',v,'fontsize',fontsize);
                        end
                end
            end
            
            exit_code = 0; dlg_wait();
            if 1==exit_code
                for m=1:nfield
                    f = field{m};
                    if get(tag.([f '_reset_']),'value')
                        MLEditable.editable = rmfield(MLEditable.editable,f);
                        MLEditable = rmfield(MLEditable,f);
                    else
                        switch MLEditable.editable.(f)
                            case 'color', MLEditable.(f) = get(tag.(f),'backgroundcolor');
                            case 'category', MLEditable.(f)(end) = MLEditable.(f)(get(tag.(f),'value'));
                            case 'range', MLEditable.(f)(end) = str2double(get(tag.(f),'string'));
                            otherwise
                                if islogical(MLEditable.(f))
                                    for n=1:numel(MLEditable.(f)), MLEditable.(f)(n) = logical(get(tag.(f)(n),'value')); end
                                elseif isnumeric(MLEditable.(f))
                                    for n=1:numel(MLEditable.(f)), MLEditable.(f)(n) = str2double(get(tag.(f)(n),'string')); end
                                else
                                    MLEditable.(f) = get(tag.(f),'string');
                                end
                        end
                    end
                end
                if 2==exist(MLPath.ConfigurationFile,'file'), config = load(MLPath.ConfigurationFile); end
                config.MLEditable = MLEditable;
                config.(editable_by_subject) = MLEditable;
                save(MLPath.ConfigurationFile,'-struct','config');
            end
            TrialRecord.setEditable(MLEditable);
        catch err
        end
        if ishandle(hDlg), close(hDlg); end
        show_screen(true,false);
        if ~isempty(err), rethrow(err); end
        
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
                case 'scrolleditable'
                    pos = get(hEditable,'position');
                    pos(2) = -get(gcbo,'value');
                    set(hEditable,'position',pos);
            end
        end
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
        
        switch lower(type(1))
            case 'e',  icon = 'warning.gif'; color = 'red';
            case 'w',  icon = 'help_ex.png'; color = 'blue';
            otherwise, icon = 'help_gs.png'; color = 'black';
        end
        icon = fullfile(matlabroot,'toolbox/matlab/icons',icon);
        if verLessThan('matlab','25.1')
            MessageString{end+1} = sprintf('<html><img src="file:///%s" height="16" width="16">&nbsp;<font color="%s">%s</font></html>',icon,color,text);
        else
            MessageString{end+1} = text;
        end
        if MaxMessage < length(MessageString), MessageString = MessageString(end-(MaxMessage-1):end); end
        set(hTag.Messagebox,'string',MessageString,'value',length(MessageString));
    end

    function init()
        mglrendergraphic; mglpresent;  % clear the second back buffer of the subject screen to prevent flickering

        mh = MaxMessage * 15 + 7; fig_pos = [0 0 993 787+mh];
        if ispref('NIMH_MonkeyLogic','LastMLMonitorPosition'), last_pos = getpref('NIMH_MonkeyLogic','LastMLMonitorPosition'); fig_pos(3:4) = max([fig_pos(3:4); last_pos(3:4)]); end
        
        h = findobj('tag','mlmainmenu');
        if isempty(h), screen_pos = GetMonitorPosition(mglgetcommandwindowrect); pos = screen_pos; else, pos = get(h,'position'); screen_pos = GetMonitorPosition(Pos2Rect(pos)); end
        if screen_pos(3) < fig_pos(3), fig_pos(3) = screen_pos(3); end
        if screen_pos(4)-110 < fig_pos(4), fig_pos(4) = screen_pos(4)-110; end  % taskbar (40*2) + titlebar (30)
        
        fig_pos(1) = min(max(pos(1) + 0.5 * (pos(3) - fig_pos(3)), screen_pos(1)), sum(screen_pos([1 3])) - fig_pos(3));
        fig_pos(2) = min(max(pos(2) + 0.5 * (pos(4) - fig_pos(4) - 30), screen_pos(2) + 40), sum(screen_pos([2 4])) - fig_pos(4) - 30);
        replica_pos = fig_pos + [4 183+mh -193 -(187+mh)];
        
        fontsize = 9;
        fontsize2 = 10;
        figure_bgcolor = [.65 .70 .80];
        frame_bgcolor = [0.9255 0.9137 0.8471];
        callbackfunc = @UIcallback;
        
        hFig = figure;
        set(hFig,'tag','mlmonitor','units','pixels','position',fig_pos,'numbertitle','off','name',sprintf('NIMH MonkeyLogic %s',MLConfig.MLVersion),'menubar','none','resize','off','color',figure_bgcolor,'windowstyle','modal');
        
        set(hFig,'closerequestfcn',@closeDlg);
        set_on_move();
        set(hFig,'sizechangedfcn',@on_resize);
        
        hTag.hReplica = uicontrol('style','frame','backgroundcolor',[0 0 0],'foregroundcolor',[0 0 0],'position',[5 184+mh replica_pos(3:4)]);
        
        x = 5; y = 45 + mh;
        uicontrol('parent',hFig,'style','frame','position',[x y 186 134],'backgroundcolor',frame_bgcolor);
        x = 10; y = 179 - 25 + mh; bgcolor = frame_bgcolor;
        uicontrol('parent',hFig,'style','text','position',[x y 52 20],'string','Trial','backgroundcolor',bgcolor,'fontsize',fontsize2,'fontweight','bold');
        uicontrol('parent',hFig,'style','text','position',[x+62 y 52 20],'string','Block','backgroundcolor',bgcolor,'fontsize',fontsize2,'fontweight','bold');
        uicontrol('parent',hFig,'style','text','position',[x+124 y 52 20],'string','Cond','backgroundcolor',bgcolor,'fontsize',fontsize2,'fontweight','bold');
        y = y - 19; bgcolor = [0 0 0]; fgcolor = [1 1 1];
        hTag.TrialNo = uicontrol('parent',hFig,'style','edit','position',[x y+3 52 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize2,'fontweight','bold');
        hTag.BlockNo = uicontrol('parent',hFig,'style','edit','position',[x+62 y+3 52 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize2,'fontweight','bold');
        hTag.CondNo = uicontrol('parent',hFig,'style','edit','position',[x+124 y+3 52 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize2,'fontweight','bold');
        y = y - 28; bgcolor = [0 0 0]; fgcolor = [1 1 1];
        hTag.TrialsInThisBlock = uicontrol('parent',hFig,'style','edit','position',[x y+2 40 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        bgcolor = frame_bgcolor;
        uicontrol('parent',hFig,'style','text','position',[x+44 y 136 20],'string','Trial # within this block','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        y = y - 28; bgcolor = [0 0 0]; fgcolor = [1 1 1];
        hTag.BlocksCompleted = uicontrol('parent',hFig,'style','edit','position',[x y+2 40 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        bgcolor = frame_bgcolor;
        uicontrol('parent',hFig,'style','text','position',[x+44 y 136 20],'string','# of blocks completed','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        y = y - 28; bgcolor = [0 0 0]; fgcolor = [1 1 1];
        hTag.TotalCorrectTrials = uicontrol('parent',hFig,'style','edit','position',[x y+2 40 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        bgcolor = frame_bgcolor;
        uicontrol('parent',hFig,'style','text','position',[x+44 y 136 20],'string','Total # of correct trials','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        
        x = 5; y = 24 + mh; bgcolor = figure_bgcolor;
        hTag.MaxLatencyLabel = uicontrol('parent',hFig,'style','text','position',[x y 90 18],'tag','MaxLatencyLabel','string','Frame Interval','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hTag.CycleRateLabel = uicontrol('parent',hFig,'style','text','position',[x+96 y 90 18],'tag','CycleRateLabel','string','Drawing Time','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        x = 5; y = 5 + mh; bgcolor = [0 0 0]; fgcolor = [1 1 1];
        hTag.MaxLatency = uicontrol('parent',hFig,'style','edit','position',[x y 90 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        hTag.CycleRate = uicontrol('parent',hFig,'style','edit','position',[x+96 y 90 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        
        x = 192; y = 179 - 19 + mh; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','position',[x y 310 18],'string','Trial errors','backgroundcolor',bgcolor,'fontsize',fontsize2,'fontweight','bold');
        y = y - 23;
        uicontrol('parent',hFig,'style','text','position',[x y 62 20],'string','All cond','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        bgcolor = [0 0 0]; fgcolor = [1 1 1];
        hTag.TrialErrorsInAllConds1 = uicontrol('parent',hFig,'style','edit','position',[x+64 y+3 231 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        hTag.TrialErrorsInAllConds2 = uicontrol('parent',hFig,'style','edit','position',[x+297 y+3 12 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        y = y - 23; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','position',[x y 62 20],'string','This cond','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        bgcolor = [0 0 0]; fgcolor = [1 1 1];
        hTag.TrialErrorsInThisCond1 = uicontrol('parent',hFig,'style','edit','position',[x+64 y+3 231 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        hTag.TrialErrorsInThisCond2 = uicontrol('parent',hFig,'style','edit','position',[x+297 y+3 12 20],'backgroundcolor',bgcolor,'foregroundcolor',fgcolor,'fontsize',fontsize,'fontweight','bold');
        
        x = 192; y = y - 19; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','position',[x y 310 18],'string','Performance','backgroundcolor',bgcolor,'fontsize',fontsize2,'fontweight','bold');
        y = y - 23; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','position',[x y 62 20],'string','Over all','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        hTag.PerformanceOverAll2 = uicontrol('parent',hFig,'style','text','position',[x+64 y+2 45 20],'backgroundcolor',bgcolor,'foregroundcolor',[1 1 1],'fontsize',10,'fontweight','bold');
        bgcolor = [0 0 0];
        hTag.PerformanceOverAll = uicontrol('parent',hFig,'style','edit','position',[x+109 y+3 200 20],'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        y = y - 23; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','position',[x y 62 20],'string','This block','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        hTag.PerformanceThisBlock2 = uicontrol('parent',hFig,'style','text','position',[x+64 y+2 45 20],'backgroundcolor',bgcolor,'foregroundcolor',[1 1 1],'fontsize',10,'fontweight','bold');
        bgcolor = [0 0 0];
        hTag.PerformanceThisBlock = uicontrol('parent',hFig,'style','edit','position',[x+109 y+3 200 20],'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        y = y - 23; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','position',[x y 62 20],'string','This cond','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        hTag.PerformanceThisCond2 = uicontrol('parent',hFig,'style','text','position',[x+64 y+2 45 20],'backgroundcolor',bgcolor,'foregroundcolor',[1 1 1],'fontsize',10,'fontweight','bold');
        bgcolor = [0 0 0];
        hTag.PerformanceThisCond = uicontrol('parent',hFig,'style','edit','position',[x+109 y+3 200 20],'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        
        colororder = [0 1 0; 0 1 1; 1 1 0; 0 0 1; 0.5 0.5 0.5; 1 0 1; 1 0 0; .3 .7 .5; .7 .2 .5; .5 .5 1; .75 .75 .5];
        hTag.PerformanceBar.PerformanceOverAll = zeros(2,10);
        hTag.PerformanceBar.PerformanceThisBlock = zeros(2,10);
        hTag.PerformanceBar.PerformanceThisCond = zeros(2,10);
        for m=1:10
            hTag.PerformanceBar.PerformanceOverAll(1,m) = uicontrol('parent',hFig,'style','frame','visible','off','backgroundcolor',colororder(m,:));
            hTag.PerformanceBar.PerformanceThisBlock(1,m) = uicontrol('parent',hFig,'style','frame','visible','off','backgroundcolor',colororder(m,:));
            hTag.PerformanceBar.PerformanceThisCond(1,m) = uicontrol('parent',hFig,'style','frame','visible','off','backgroundcolor',colororder(m,:));
            hTag.PerformanceBar.PerformanceOverAll(2,m) = uicontrol('parent',hFig,'style','text','visible','off','string',num2str(m-1),'backgroundcolor',colororder(m,:),'foregroundcolor',[1 1 1],'fontsize',fontsize,'fontweight','bold');
            hTag.PerformanceBar.PerformanceThisBlock(2,m) = uicontrol('parent',hFig,'style','text','visible','off','string',num2str(m-1),'backgroundcolor',colororder(m,:),'foregroundcolor',[1 1 1],'fontsize',fontsize,'fontweight','bold');
            hTag.PerformanceBar.PerformanceThisCond(2,m) = uicontrol('parent',hFig,'style','text','visible','off','string',num2str(m-1),'backgroundcolor',colororder(m,:),'foregroundcolor',[1 1 1],'fontsize',fontsize,'fontweight','bold');
        end
        
        x = x + 10; y = y - 23; bgcolor = figure_bgcolor;
        uicontrol('parent',hFig,'style','text','position',[x y 110 20],'string','Screen zoom (%) :','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.operatorview1 = uicontrol('parent',hFig,'style','edit','tag','operatorview1','position',[x+110 y+3 50 20],'fontsize',fontsize,'callback',callbackfunc);
        hTag.operatorview2 = uicontrol('parent',hFig,'style','slider','tag','operatorview2','min',ControlScreenZoomRange(1),'max',ControlScreenZoomRange(2),'sliderstep',[1 10]./(ControlScreenZoomRange(2)-ControlScreenZoomRange(1)),'value',ControlScreenZoomRange(1),'position',[x+170 y+3 129 19],'callback',callbackfunc);
        
        pos = [5 5 496 mh-5];
        hTag.Messagebox = uicontrol('style','list','position',pos,'string',MessageString,'backgroundcolor',[1 1 1],'fontsize',fontsize);
        
        hTag.hTimeline = axes('units','pixels','xlim',[0 1],'ylim',[0 1],'xtick',[],'ytick',[],'box','on');
        h = text(0.5,0.97,'Time Line');
        set(h,'color',[1 1 1],'horizontalalignment','center','fontweight','bold','fontsize',11);
        patch([0.25 0.28 0.28 0.25],[0.05 0.05 0.90 0.90],[1 1 1]);
        
        hTag.hUserplot = axes('units','pixels','fontsize',11,'xtick',[],'ytick',[],'box','off');
        
        on_resize;
        mglcreatecontrolscreen(Pos2Rect(replica_pos));
        update_UI();
        create_tracers(Screen,MLConfig);
        create_photodiode(Screen,MLConfig);
        show_screen(true,true);
        mglkeepsystemawake(true);
        kbdinit;
        
        TrialRecord.TaskInfo.BehavioralCodes = struct('CodeNumbers',[],'CodeNames',[]);
        if ~isempty(MLPath.BehavioralCodesFile)
            code_str = regexp(fileread(MLPath.BehavioralCodesFile),'([0-9]+)[ \t]+([^\n]+)','tokens');
            code_str = [code_str{:}]';
            TrialRecord.TaskInfo.BehavioralCodes.CodeNumbers = cellfun(@str2double, code_str(1:2:end));
            TrialRecord.TaskInfo.BehavioralCodes.CodeNames = strtrim(code_str(2:2:end));
        end
        TrialRecord.TaskInfo.TrialErrorCodes = {'Correct','No response','Late response','Break fixation','No fixation','Early response','Incorrect','Lever break','Ignored','Aborted'}';
    end
    function UIcallback(hObject,~)
        obj_tag = get(hObject,'tag');
        switch lower(obj_tag)
            case 'operatorview1'
                val = round(str2double(get(gcbo,'string')));
                if ControlScreenZoomRange(1)<=val && val<=ControlScreenZoomRange(2), MLConfig.ControlScreenZoom = val; end
            case 'operatorview2'
                val = round(get(gcbo,'value'));
                if ControlScreenZoomRange(1)<=val && val<=ControlScreenZoomRange(2), MLConfig.ControlScreenZoom = val; end
        end
        update_UI();
    end
    function update_UI()
        set(hTag.operatorview1,'string',num2str(MLConfig.ControlScreenZoom));
        set(hTag.operatorview2,'value',MLConfig.ControlScreenZoom);
        mglsetcontrolscreenzoom(MLConfig.ControlScreenZoom/100);
    end
    function closeDlg(varargin)
        looping = false;
        setpref('NIMH_MonkeyLogic','LastMLMonitorPosition',get(hFig,'position'));
        mglkeepsystemawake(false);
        mglsetcursorpos(-1);
        destroy(Screen);  % These objects are destroyed here to deal with accidental closing
        stop_cam(DAQ);
        destroy(DAQ);
        closereq;
    end
    function set_on_move(func)
        if ~exist('func','var'), func = @on_move; end
        if verLessThan('matlab','9.7')
            warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            jFrame = get(hFig,'JavaFrame'); %#ok<JAVFM>
            jAxis = jFrame.getAxisComponent;
            set(jAxis.getComponent(0),'AncestorMovedCallback',func);
        else
            delete(hListener); hListener = [];
            if ~isempty(func), hListener = addlistener(hFig,'LocationChanged',func); end
        end
    end
    function on_move(varargin)
        if mglcontrolscreenexists
            fig_pos = get(hFig,'position');
            mh = MaxMessage * 15 + 7; replica_pos = fig_pos + [4 183+mh -193 -(187+mh)];
            mglsetcontrolscreenrect(Pos2Rect(replica_pos));
        end
    end
    function on_resize(varargin)
        fig_pos = get(hFig,'position');
        mh = MaxMessage * 15 + 7; replica_pos = fig_pos + [4 183+mh -193 -(187+mh)];
        
        if all(0<replica_pos(3:4)), set(hTag.hReplica,'position',[5 184+mh replica_pos(3:4)]); end
        if 0<replica_pos(4), set(hTag.hTimeline,'position',[replica_pos(3)+10 184+mh 180 replica_pos(4)],'color',[0.3 0.3 0.5]); end
        
        outer_pos = [502 0 fig_pos(3)-502 184+mh]; inner_pos = outer_pos + [75 50 -100 -80];
        if all(0<inner_pos(3:4)), set(hTag.hUserplot,'position',inner_pos); end
        
        if mglcontrolscreenexists
            mglsetcontrolscreenrect(Pos2Rect(replica_pos));
            reposition_icons(Screen,DAQ);
            reposition_menuitem();
        end
        drawnow;
    end
    function show_screen(cs_show,ss_front)
        ss_info = mglgetscreeninfo(1);
        cs_rect = mglgetscreeninfo(2,'Rect');
        intersect = IntersectRect(ss_info.Rect,cs_rect);
        overlapped = 0<intersect(3)*intersect(4);
        ss_show = cs_show || ~overlapped;
        mdqmex(1,205,ss_front,ss_show,cs_show);
        if ss_show && ~ss_info.Show, mglpresent(1); mglpresent(1); end
    end

    function dest = copyfield(dest,src,field)
        if isempty(src), src = struct; end
        if isempty(dest), dest = struct; end
        if ~exist('field','var'), field = intersect(fieldnames(dest),fieldnames(src)); end
        for m=1:length(field), dest.(field{m}) = src.(field{m}); end
    end
    function op = fi(tf,op1,op2)
        if tf, op = op1; else, op = op2; end
    end
end
