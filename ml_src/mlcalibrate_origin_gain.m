function tform = mlcalibrate_origin_gain(EyeOrJoy,MLConfig,devnum)

daq_created = false;
if ~exist('EyeOrJoy','var'), EyeOrJoy = 1; end
if ~exist('MLConfig','var')
    MLConfig = mlconfig;
    MLConfig.IOList = mliolist();
    MLConfig.EyeCalibration = 2;
    MLConfig.JoystickCalibration = [2 2];
    switch EyeOrJoy
        case 1, entry = {'Eye X','nidaq','Dev1','AnalogInput',0,[]; 'Eye Y','nidaq','Dev1','AnalogInput',1,[]};
        case 2, entry = {'Joystick X','nidaq','Dev1','AnalogInput',0,[]; 'Joystick Y','nidaq','Dev1','AnalogInput',1,[]; ...
                'Joystick2 X','nidaq','Dev1','AnalogInput',2,[]; 'Joystick2 Y','nidaq','Dev1','AnalogInput',3,[];};
    end
    entry = [entry; {'Reward','nidaq','Dev1','DigitalIO',0,{0,'out'}}];
    MLConfig.IO = cell2struct(entry,{'SignalType','Adaptor','DevID','Subsystem','Channel','DIOInfo'},2);
    MLConfig.MLPath.BaseDirectory = which('monkeylogic.m');
    create(MLConfig.DAQ,MLConfig);
    daq_created = true;
end

% initialize devices
alert = false;
if ~exist('devnum','var')
    alertfunc = get_function_handle(MLConfig.MLPath.AlertFunction);
    alert = ~isempty(alertfunc) && MLConfig.RemoteAlert;
    if alert, TrialRecord = mltrialrecord; alertfunc('init',MLConfig,TrialRecord); end
end

% remember the current settings
switch EyeOrJoy
    case 1
        if ~exist('devnum','var'), devnum = MLConfig.EyeNumber; end
        orig_tform = MLConfig.EyeTransform{devnum,MLConfig.EyeCalibration(devnum)};
    case 2
        if ~exist('devnum','var'), devnum = MLConfig.JoystickNumber; end
        orig_tform = MLConfig.JoystickTransform{devnum,MLConfig.JoystickCalibration(devnum)};
end
CalFun = mlcalibrate(EyeOrJoy,MLConfig,devnum);
tform = copyfield(init_tform(),CalFun.get_transform_matrix());
screen_created = false(1,2);
controlscreeninfo = mglgetscreeninfo(2);  % empty when control screen does not exist already
[object_id,~,object_status] = mglgetallobjects();

DAQ = MLConfig.DAQ;
Screen = MLConfig.Screen;
if ~mglsubjectscreenexists, create(Screen,MLConfig); screen_created(1) = true; end

% value ranges
operator_view_range = [5 300];
switch class(get_device(DAQ,EyeOrJoy))
    case 'analoginput'
        info = daqhwinfo(get_device(DAQ,EyeOrJoy));
        [~,i]=max(info.InputRanges(:,2),[],1);
        origin_range = info.InputRanges(i,:);
    otherwise, origin_range = [-10 10];
end
gain_range = [-20 20];
fixinterval_range = [0.5 100];

% validate input
tform.origin = min([max([tform.origin; repmat(origin_range(1),1,2)],[],1); repmat(origin_range(2),1,2)],[],1);
tform.gain = min([max([tform.gain; repmat(gain_range(1),1,2)],[],1); repmat(gain_range(2),1,2)],[],1);
if ~isfield(tform.RewardFuncArgs,'JuiceLine'), tform.RewardFuncArgs.JuiceLine = 1; end
old_tform = tform;

% variables
hFig = [];
hControl = [];
hTag = struct;
ui_lock = true;
exit_code = 0;
fixpoint_id = [];
fixpoint_pos = [];
picked_target = [];
picked_target_id = [];
islinetracer = false;
ControlScreenRect = zeros(1,4);
tracer = [];
show_fixationpoint = false;
mouse = [];
mouse_created = false;
daq_started = false;
prev_eye_position = [];
reward_duration_id = [];
trial_count = 0;
reward_count = 0;
trial_count_id = NaN(1,2);
reward_count_id = NaN(1,2);

% open the dialog
try
    init();
    run_scene();
    if ishandle(hFig), close(hFig); end
catch err
    if ishandle(hFig), tform = orig_tform; exit_code = 1; close(hFig); end
    rethrow(err);
end
% end of the dialog

    % methods
    function tform = init_tform()
        tform.operator_view = 120;
        tform.origin = [0 0];
        tform.gain = [1 1];
        tform.rotation = 0;
        tform.rotation_t = eye(2);
        tform.rotation_rev_t = eye(2);
        tform.fiximage = '';
        tform.fixshape = 2;
        tform.fixcolor = [1 1 0];
        tform.fixsize = 0.6;
        tform.fixinterval = 5;
        tform.windowsize = 3;
        tform.waittime = fi(1==EyeOrJoy,2000,30000);
        tform.holdtime = 500;
        tform.jittertolerance = 20;
		r = MLConfig.RewardFuncArgs;
        tform.RewardFuncArgs = struct('JuiceLine',1,'Duration',100,'NumReward',1,'PauseTime',40,'TriggerVal',r.TriggerVal,'Custom',r.Custom);
    end

    function run_scene()
        kbdinit;
        frame_counter = 0;
        update_interval = round(Screen.RefreshRate/10);
        while 0==exit_code
            [xy,buttons] = getsample(mouse); buttons = buttons(1:2);  % remove keycodes
            if xy(1)<ControlScreenRect(1) || xy(2)<ControlScreenRect(2) || ControlScreenRect(3)<xy(1) || ControlScreenRect(4)<xy(2), buttons(:) = false; end  % ignore fix points outside the screen
            switch EyeOrJoy
                case 1
                    if isempty(picked_target_id)
                        if any(buttons), picked_target = find(isinside(CalFun.control2pix(xy)),1); end
                        if ~isempty(picked_target), show_fixationpoint = true; end
                    else
                        show_fixationpoint = false;
                    end
                case 2
                    if any(buttons)
                        picked = find(isinside(CalFun.control2pix(xy)),1);
                        if ~isempty(picked)
                            picked_target = picked;
                            show_fixationpoint = true;
                        end
                    end
            end
            if show_fixationpoint
                mgldestroygraphic(picked_target_id);
                picked_target_id = [load_cursor(tform.fiximage,tform.fixshape,tform.fixcolor,tform.fixsize*MLConfig.PixelsPerDegree(1),1) ...
                    mgladdcircle([0 1 0],tform.windowsize*MLConfig.PixelsPerDegree(1)*2,10)];
                mglsetorigin(picked_target_id,fixpoint_pos(picked_target,:));
                waittimer = tic;
                waiting = true;
                frame_counter = 0;
                show_fixationpoint = false;
                trial_count = trial_count + 1;
                mglsetproperty(trial_count_id(2),'text',sprintf(': %d',trial_count));
            end                
            
            peekfront(DAQ);
            switch EyeOrJoy
                case 1
                    switch devnum
                        case 1, data = DAQ.Eye;
                        case 2, data = DAQ.Eye2;
                    end
                case 2
                    switch devnum
                        case 1, data = DAQ.Joystick;
                        case 2, data = DAQ.Joystick2;
                    end
            end
            if ~isempty(data)
                if ~isempty(picked_target)
                    good = all(sum((CalFun.sig2pix(data,[0 0])-repmat(fixpoint_pos(picked_target,:),size(data,1),1)).^2,2) < (tform.windowsize*MLConfig.PixelsPerDegree(1))^2);
                    done = false;
                    success = false;

                    if ~good &&  waiting, done = tform.waittime < toc(waittimer)*1000; end
                    if  good &&  waiting, waiting = false; holdtimer = tic; end
                    if ~good && ~waiting
                        switch EyeOrJoy
                            case 1, done = tform.jittertolerance < toc(holdtimer)*1000;
                            case 2, waiting = tform.jittertolerance < toc(holdtimer)*1000;
                        end
                    end
                    if  good && ~waiting, done = tform.holdtime < toc(holdtimer)*1000; success = done; end

                    if done
                        if success
                            r = tform.RewardFuncArgs;
                            DAQ.goodmonkey(r.Duration,'numreward',r.NumReward,'juiceline',r.JuiceLine);
                            reward_count = reward_count + 1;
                            mglsetproperty(reward_count_id(2),'text',sprintf(': %d',reward_count));
                        end
                        mgldestroygraphic(picked_target_id);
                        picked_target_id = [];
                        picked_target = [];
                    end
                end
                
                if islinetracer, mglsetproperty(tracer,'addpoint',CalFun.sig2pix(data,[0 0])); else, mglsetorigin(tracer,CalFun.sig2pix(data(end,:),[0 0])); end
            end

            kb = kbdgetkey;
            if ~isempty(kb)
                switch kb
                    case 1,  exit_code = -1;  % esc
                    case 57, setorigin(); update_UI();  % space
                end
                if DAQ.reward_present
                    switch kb
                        case 12  % -
                            tform.RewardFuncArgs.Duration = max(0,tform.RewardFuncArgs.Duration-10);
                            mglsetproperty(reward_duration_id,'text',sprintf('R key: Manual reward (%.0f ml)',tform.RewardFuncArgs.Duration));
                            update_savebutton();
                        case 13  % =
                            tform.RewardFuncArgs.Duration = tform.RewardFuncArgs.Duration + 10;
                            mglsetproperty(reward_duration_id,'text',sprintf('R key: Manual reward (%.0f ml)',tform.RewardFuncArgs.Duration));
                            update_savebutton();
                        case 19  % r
                            r = tform.RewardFuncArgs;
                            DAQ.goodmonkey(r.Duration,'numreward',r.NumReward,'juiceline',r.JuiceLine);
                    end
                end
                if 1==EyeOrJoy
                    switch kb
                        case 22  % u
                            if ~isempty(prev_eye_position)
                                tform = copyfield(tform,CalFun.translate(-prev_eye_position(end,:)),{'origin'});
                                tform.origin = max(origin_range(1),min(origin_range(2),round(tform.origin*100)/100));
                                prev_eye_position(end,:) = [];
                                CalFun.set_transform_matrix(tform);
                                update_UI();
                            end
                        case 46  % c
                            if  ~isempty(data)
                                prev_eye_position(end+1,:) = CalFun.sig2deg(data(end,:),[0 0]); %#ok<AGROW>
                                tform = copyfield(tform,CalFun.translate(prev_eye_position(end,:)),{'origin'});
                                tform.origin = max(origin_range(1),min(origin_range(2),round(tform.origin*100)/100));
                                CalFun.set_transform_matrix(tform);
                                update_UI();
                            end
                    end
                end
            end
                
            mglrendergraphic(frame_counter);
            mglpresent;
            frame_counter = frame_counter + 1; 
            if 0==mod(frame_counter,update_interval), drawnow; end
        end
    end

    function init()
        fig_pos = [0 0 850 600];
        if ispref('NIMH_MonkeyLogic','LastCalToolPosition'), last_pos = getpref('NIMH_MonkeyLogic','LastCalToolPosition'); fig_pos(3:4) = max([fig_pos(3:4); last_pos(3:4)]); end
        
        h = findobj('tag','mlmonitor');
        if isempty(h), h = findobj('tag','mlmainmenu'); end
        if isempty(h), screen_pos = GetMonitorPosition(mglgetcommandwindowrect); pos = screen_pos; else, pos = get(h,'position'); screen_pos = GetMonitorPosition(Pos2Rect(pos)); end
        if screen_pos(3) < fig_pos(3), fig_pos(3) = screen_pos(3); end
        if screen_pos(4)-110 < fig_pos(4), fig_pos(4) = screen_pos(4)-110; end  % taskbar (40*2) + titlebar (30)

        fig_pos(1) = min(max(pos(1) + 0.5 * (pos(3) - fig_pos(3)), screen_pos(1)), sum(screen_pos([1 3])) - fig_pos(3));
        fig_pos(2) = min(max(pos(2) + 0.5 * (pos(4) - fig_pos(4) - 30), screen_pos(2) + 40), sum(screen_pos([2 4])) - fig_pos(4) - 30);
        replica_pos = fig_pos - [0 0 250 0];

        fontsize = 9;
        bgcolor = [0.9255 0.9137 0.8471];
        callbackfunc = @UIcallback;

        hFig = figure;
        set(hFig,'tag','mlcalibrate','units','pixels','position',fig_pos,'numbertitle','off','name',[sprintf(fi(1==EyeOrJoy,'Eye #%d','Joystick #%d'),devnum) ' calibration: Origin & Gain'],'menubar','none','resize','on','color',bgcolor,'windowstyle','modal');
        
        set(hFig,'closerequestfcn',@closeDlg);
        if verLessThan('matlab','9.7')
            warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            jFrame = get(hFig,'JavaFrame'); %#ok<JAVFM>
            jAxis = jFrame.getAxisComponent;
            set(jAxis.getComponent(0),'AncestorMovedCallback',@on_move);
        else
            addlistener(hFig,'LocationChanged',@on_move);
        end
        set(hFig,'sizechangedfcn',@on_resize);
        
        hTag.replica = uicontrol('parent',hFig,'style','frame','backgroundcolor',MLConfig.SubjectScreenBackground,'foregroundcolor',MLConfig.SubjectScreenBackground);
        hTag.lock = uicontrol('parent',hFig,'style','pushbutton','tag','lock','string',fi(ui_lock,'Unlock','Lock'),'fontsize',fontsize,'callback',callbackfunc);

        hControl(1) = uicontrol('parent',hFig,'style','text','string','Zoom (%) :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.operatorview1 = uicontrol('parent',hFig,'style','edit','tag','operatorview1','fontsize',fontsize,'callback',callbackfunc);
        hTag.operatorview2 = uicontrol('parent',hFig,'style','slider','tag','operatorview2','min',operator_view_range(1),'max',operator_view_range(2),'sliderstep',[1 10]./(operator_view_range(2)-operator_view_range(1)),'value',operator_view_range(1),'fontsize',fontsize,'callback',callbackfunc);
        hControl(2) = hTag.operatorview1; hControl(3) = hTag.operatorview2;
        
        hControl(4) = uicontrol('parent',hFig,'style','text','string','Origin X :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.originx1 = uicontrol('parent',hFig,'style','edit','tag','originx1','fontsize',fontsize,'callback',callbackfunc);
        hTag.originx2 = uicontrol('parent',hFig,'style','slider','tag','originx2','min',origin_range(1),'max',origin_range(2),'sliderstep',[0.01 0.1]./(origin_range(2)-origin_range(1)),'value',origin_range(1),'fontsize',fontsize,'callback',callbackfunc);
        hControl(5) = hTag.originx1; hControl(6) = hTag.originx2;

        hControl(7) = uicontrol('parent',hFig,'style','text','string','Origin Y :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.originy1 = uicontrol('parent',hFig,'style','edit','tag','originy1','fontsize',fontsize,'callback',callbackfunc);
        hTag.originy2 = uicontrol('parent',hFig,'style','slider','tag','originy2','min',origin_range(1),'max',origin_range(2),'sliderstep',[0.01 0.1]./(origin_range(2)-origin_range(1)),'value',origin_range(1),'fontsize',fontsize,'callback',callbackfunc);
        hControl(8) = hTag.originy1; hControl(9) = hTag.originy2;

        hControl(10) = uicontrol('parent',hFig,'style','text','string','Gain X :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.gainx1 = uicontrol('parent',hFig,'style','edit','tag','gainx1','fontsize',fontsize,'callback',callbackfunc);
        hTag.gainx2 = uicontrol('parent',hFig,'style','slider','tag','gainx2','min',gain_range(1),'max',gain_range(2),'sliderstep',[0.01 0.1]./(gain_range(2)-gain_range(1)),'value',gain_range(1),'fontsize',fontsize,'callback',callbackfunc);
        hControl(11) = hTag.gainx1; hControl(12) = hTag.gainx2;

        hControl(13) = uicontrol('parent',hFig,'style','text','string','Gain Y :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.gainy1 = uicontrol('parent',hFig,'style','edit','tag','gainy1','fontsize',fontsize,'callback',callbackfunc);
        hTag.gainy2 = uicontrol('parent',hFig,'style','slider','tag','gainy2','min',gain_range(1),'max',gain_range(2),'sliderstep',[0.01 0.1]./(gain_range(2)-gain_range(1)),'value',gain_range(1),'fontsize',fontsize,'callback',callbackfunc);
        hControl(14) = hTag.gainy1; hControl(15) = hTag.gainy2;

        hControl(16) = uicontrol('parent',hFig,'style','text','string','Rotation :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.rotation1 = uicontrol('parent',hFig,'style','edit','tag','rotation1','fontsize',fontsize,'callback',callbackfunc);
        hTag.rotation2 = uicontrol('parent',hFig,'style','slider','tag','rotation2','min',-180,'max',180,'sliderstep',[1 10]./360,'value',0,'fontsize',fontsize,'callback',callbackfunc);
        hControl(17) = hTag.rotation1; hControl(18) = hTag.rotation2;

        hTag.showorigin = uicontrol('parent',hFig,'style','pushbutton','tag','showorigin','string','Show Center','fontsize',fontsize,'callback',callbackfunc);
        hTag.setorigin = uicontrol('parent',hFig,'style','pushbutton','tag','setorigin','string','Set Origin (SPACE)','fontsize',fontsize,'callback',callbackfunc);
        hControl(19) = hTag.showorigin; hControl(20) = hTag.setorigin;

        hControl(21) = uicontrol('parent',hFig,'style','text','string','Fixation point :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.fiximage = uicontrol('parent',hFig,'style','pushbutton','tag','fiximage','fontsize',fontsize,'callback',callbackfunc);
        hControl(22) = hTag.fiximage;
        
        hTag.fixshape = uicontrol('parent',hFig,'style','popupmenu','tag','fixshape','string',{'Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.fixcolor = uicontrol('parent',hFig,'style','pushbutton','tag','fixcolor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        hTag.fixsize = uicontrol('parent',hFig,'style','edit','tag','fixsize','fontsize',fontsize,'callback',callbackfunc);
        hControl(23) = uicontrol('parent',hFig,'style','text','string','deg','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hControl(24) = hTag.fixshape; hControl(25) = hTag.fixcolor; hControl(26) = hTag.fixsize;

        hControl(27) = uicontrol('parent',hFig,'style','text','string','at','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hTag.fixinterval = uicontrol('parent',hFig,'style','edit','tag','fixinterval','fontsize',fontsize,'callback',callbackfunc);
        hControl(28) = uicontrol('parent',hFig,'style','text','string','deg intervals','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hControl(29) = hTag.fixinterval;

        hControl(30) = uicontrol('parent',hFig,'style','text','string','Fixation window radius :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.windowsize = uicontrol('parent',hFig,'style','edit','tag','windowsize','fontsize',fontsize,'callback',callbackfunc);
        hControl(31) = uicontrol('parent',hFig,'style','text','string','degrees','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hControl(32) = hTag.windowsize;
        
        hControl(33) = uicontrol('parent',hFig,'style','text','string','Fixation wait time :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.waittime = uicontrol('parent',hFig,'style','edit','tag','waittime','fontsize',fontsize,'callback',callbackfunc);
        hControl(34) = uicontrol('parent',hFig,'style','text','string','msec','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hControl(35) = hTag.waittime;
        
        hControl(36) = uicontrol('parent',hFig,'style','text','string','Fixation hold time :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.holdtime = uicontrol('parent',hFig,'style','edit','tag','holdtime','fontsize',fontsize,'callback',callbackfunc);
        hControl(37) = uicontrol('parent',hFig,'style','text','string','msec','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hControl(38) = hTag.holdtime;

        hTag.rewardoptions = uicontrol('parent',hFig,'style','pushbutton','tag','rewardoptions','fontsize',fontsize,'callback',callbackfunc);
        hControl(39) = hTag.rewardoptions;

        hTag.savebutton = uicontrol('parent',hFig,'style','pushbutton','tag','savebutton','string','Save','fontsize',fontsize,'callback',callbackfunc);
        hTag.revertbutton = uicontrol('parent',hFig,'style','pushbutton','tag','revertbutton','string','Revert','fontsize',fontsize,'callback',callbackfunc);
        hTag.closebutton = uicontrol('parent',hFig,'style','pushbutton','tag','cancelbutton','string','Close (ESC)','fontsize',fontsize,'callback',callbackfunc);

        if mglcontrolscreenexists()
            mglactivategraphic(object_id,false);
            mglsetcontrolscreenrect(Pos2Rect(replica_pos));
            mglsetcontrolscreenshow(true);
        else
            screen_created(2) = true;
            mglcreatecontrolscreen(Pos2Rect(replica_pos));
        end
        mglsetcontrolscreenzoom(tform.operator_view/100);
        update_controlscreen_geometry();
        update_calib_func();        
        update_fixpoint();
        
        switch EyeOrJoy
            case 1
                switch lower(MLConfig.EyeTracerShape{devnum})
                    case 'line', islinetracer = true; tracer = mgladdline(MLConfig.EyeTracerColor(devnum,:),50,1,10);
                    otherwise, tracer = load_cursor('',MLConfig.EyeTracerShape{devnum},MLConfig.EyeTracerColor(devnum,:),MLConfig.EyeTracerSize(devnum),10);
                end
            case 2, tracer = load_cursor(MLConfig.JoystickCursorImage{devnum},MLConfig.JoystickCursorShape{devnum},MLConfig.JoystickCursorColor(devnum,:),MLConfig.JoystickCursorSize(devnum),11);
        end

        r = tform.RewardFuncArgs;
        DAQ.goodmonkey(0,'eval',sprintf('PauseTime=%d;TriggerVal=%d;%s',r.PauseTime,r.TriggerVal,r.Custom));
        mglsetproperty(mgladdtext('C key: Set current eye pos as origin',12),'origin',[10 10]*Screen.DPI_ratio,'fontsize',12);
        mglsetproperty(mgladdtext('U key: Undo the C key',12),'origin',[10 30]*Screen.DPI_ratio,'fontsize',12);
        if DAQ.reward_present
            reward_duration_id = mgladdtext(sprintf('R key: Manual reward (%.0f ml)',tform.RewardFuncArgs.Duration),12);
            mglsetproperty(reward_duration_id,'origin',[10 50]*Screen.DPI_ratio,'fontsize',12);
            mglsetproperty(mgladdtext('+/-: Increase/decrease reward by 10 ms',12),'origin',[10 70]*Screen.DPI_ratio,'fontsize',12);
        end
        load('mlimagedata.mat','reward_image');
        trial_count_id(2) = mgladdtext(sprintf(': %d',trial_count),12);
        reward_count_id(1) = mgladdbitmap(mglimresize(reward_image,0.7),12);
        reward_count_id(2) = mgladdtext(sprintf(': %d',reward_count),12);
        mglsetproperty([trial_count_id(2) reward_count_id(2)],'fontsize',12);

        update_UI();
        on_resize;

        mouse = DAQ.get_device('mouse');
        if isempty(mouse), mouse_created = true; mouse = pointingdevice; end
        if ~isrunning(DAQ), daq_started = true; start(DAQ); end
        ml_timer = tic; while 0==DAQ.MinSamplesAvailable, if 5<toc(ml_timer), error('Data acquisition stopped.'); end, end
        frontmarker(DAQ);

        mglenabletouchclick(true);
    end
    function on_move(varargin)
        if mglcontrolscreenexists
            fig_pos = get(hFig,'position');
            replica_pos = fig_pos - [0 0 250 0];
            mglsetcontrolscreenrect(Pos2Rect(replica_pos));
            update_controlscreen_geometry();
            drawnow;
        end
    end
    function on_resize(varargin)
        fig_pos = get(hFig,'position');
        replica_pos = fig_pos - [0 0 250 0];
        if all(0<replica_pos(3:4)), set(hTag.replica,'position',[1 1 replica_pos(3:4)]); end
        
        x0 = fig_pos(3)-245; y0 = fig_pos(4)-30;
        set(hTag.lock,'position',[x0+160 y0+2 80 24]);
        
        y0 = y0 - 35;
        set(hControl(1),'position',[x0 y0 65 22]);
        set(hTag.operatorview1,'position',[x0+70 y0+2 45 21]);
        set(hTag.operatorview2,'position',[x0+120 y0+4 120 17]);

        y0 = y0 - 35;
        set(hControl(4),'position',[x0 y0 65 22]);
        set(hTag.originx1,'position',[x0+70 y0+2 45 21]);
        set(hTag.originx2,'position',[x0+120 y0+4 120 17]);

        y0 = y0 - 30;
        set(hControl(7),'position',[x0 y0 65 22]);
        set(hTag.originy1,'position',[x0+70 y0+2 45 21]);
        set(hTag.originy2,'position',[x0+120 y0+4 120 17]);

        y0 = y0 - 30;
        set(hControl(10),'position',[x0 y0 65 22]);
        set(hTag.gainx1,'position',[x0+70 y0+2 45 21]);
        set(hTag.gainx2,'position',[x0+120 y0+4 120 17]);

        y0 = y0 - 30;
        set(hControl(13),'position',[x0 y0 65 22]);
        set(hTag.gainy1,'position',[x0+70 y0+2 45 21]);
        set(hTag.gainy2,'position',[x0+120 y0+4 120 17]);

        y0 = y0 - 30;
        set(hControl(16),'position',[x0 y0 65 22]);
        set(hTag.rotation1,'position',[x0+70 y0+2 45 21]);
        set(hTag.rotation2,'position',[x0+120 y0+4 120 17]);

        y0 = y0 - 30;
        set(hTag.showorigin,'position',[x0+10 y0+2 95 24]);
        set(hTag.setorigin,'position',[x0+110 y0+2 130 24]);

        y0 = y0 - 45;
        set(hControl(21),'position',[x0 y0 85 22]);
        set(hTag.fiximage,'position',[x0+90 y0+2 150 24]);

        y0 = y0 - 30;
        set(hTag.fixshape,'position',[x0+28 y0 70 24]);
        set(hTag.fixcolor,'position',[x0+105 y0+2 64 24]);
        set(hTag.fixsize,'position',[x0+175 y0+4 37 21]);
        set(hControl(23),'position',[x0+215 y0 110 22]);

        y0 = y0 - 30;
        set(hControl(27),'position',[x0+28 y0 110 22]);
        set(hTag.fixinterval,'position',[x0+50 y0+3 37 21]);
        set(hControl(28),'position',[x0+95 y0 100 22]);

        y0 = y0 - 45;
        set(hControl(30),'position',[x0 y0 140 22]);
        set(hTag.windowsize,'position',[x0+145 y0+3 45 21]);
        set(hControl(31),'position',[x0+195 y0 110 22]);
        
        y0 = y0 - 30;
        set(hControl(33),'position',[x0 y0 140 22]);
        set(hTag.waittime,'position',[x0+145 y0+3 45 21]);
        set(hControl(34),'position',[x0+195 y0 110 22]);
        
        y0 = y0 - 30;
        set(hControl(36),'position',[x0 y0 140 22]);
        set(hTag.holdtime,'position',[x0+145 y0+3 45 21]);
        set(hControl(37),'position',[x0+195 y0 110 22]);

        y0 = y0 - 45;
        set(hTag.rewardoptions,'position',[x0+10 y0+2 220 24]);

        y0 = 10;
        set(hTag.savebutton,'position',[x0+10 y0+2 65 24]);
        set(hTag.revertbutton,'position',[x0+80 y0+2 65 24]);
        set(hTag.closebutton,'position',[x0+150 y0+2 90 24]);
        
        if mglcontrolscreenexists
            mglsetcontrolscreenrect(Pos2Rect(replica_pos));
            update_controlscreen_geometry();
            mglsetorigin([trial_count_id reward_count_id],[replica_pos(3)-64 22; replica_pos(3)-50 10; replica_pos(3)-65 40; replica_pos(3)-50 30]*Screen.DPI_ratio);
        end
        drawnow;
    end

    function UIcallback(hObject,~)
        obj_tag = get(hObject,'tag');
        switch lower(obj_tag)
            case 'lock', ui_lock = ~ui_lock; set(gcbo,'string',fi(ui_lock,'Unlock','Lock')); uicontrol(hControl(1));

            case 'operatorview1'
                val = round(str2double(get(gcbo,'string')));
                if operator_view_range(1)<=val && val<=operator_view_range(2), tform.operator_view = val; end
                mglsetcontrolscreenzoom(tform.operator_view/100);
                update_controlscreen_geometry();

            case 'operatorview2'
                val = round(get(gcbo,'value'));
                if operator_view_range(1)<=val && val<=operator_view_range(2), tform.operator_view = val; end
                mglsetcontrolscreenzoom(tform.operator_view/100);
                update_controlscreen_geometry();

            case {'originx1','originy1'}
                val = [str2double(get(hTag.originx1,'string')) str2double(get(hTag.originy1,'string'))];
                val = round(val*100)/100;
                if all(origin_range(1)<=val) && all(val<=origin_range(2)), tform.origin = val; end
                update_calib_func();

            case {'originx2','originy2'}
                val = [get(hTag.originx2,'value') get(hTag.originy2,'value')];
                val = round(val*100)/100;
                if all(origin_range(1)<=val) && all(val<=origin_range(2)), tform.origin = val; end
                update_calib_func();

            case {'gainx1','gainy1'}
                val = [str2double(get(hTag.gainx1,'string')) str2double(get(hTag.gainy1,'string'))];
                val = round(val*100)/100;
                if all(0~=val) && all(gain_range(1)<=val) && all(val<=gain_range(2)), tform.gain = val; end
                update_calib_func();

            case {'gainx2','gainy2'}
                val = [get(hTag.gainx2,'value') get(hTag.gainy2,'value')];
                val = round(val*100)/100;
                if all(0~=val) && all(gain_range(1)<=val) && all(val<=gain_range(2)), tform.gain = val; end
                update_calib_func();
                
            case 'rotation1'
                val = round(str2double(get(gcbo,'string'))*10)/10;
                if -180<=val && val<=180, tform.rotation = val; end
                update_calib_func();
                
            case 'rotation2'
                val = round(get(gcbo,'value')*10)/10;
                if -180<=val && val<=180, tform.rotation = val; end
                update_calib_func();
                
            case 'showorigin'
                picked_target = round(size(fixpoint_pos,1) / 2);
                show_fixationpoint = true;
                
            case 'setorigin'
                setorigin();
                
            case 'fiximage'
                mglsetcontrolscreenshow(false);
                drawnow; pause(0.3);
                [cursorfile,cursorpath] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.gif;*.mp4;*.avi;*.mpg;*.mpeg','Image/Movie Files'; '*.*','All Files'},'Choose fixation point file');
                drawnow; pause(0.3);
                if (isscalar(cursorfile) && 0==cursorfile) || 2~=exist([cursorpath cursorfile],'file')
                    tform.fiximage = '';
                else
                    tform.fiximage = [cursorpath cursorfile];
                end
                mglsetcontrolscreenshow(true);
                update_fixpoint();
                
            case 'fixshape'
                tform.fixshape = get(gcbo,'value');
                update_fixpoint();
                
            case 'fixcolor'
                mglsetcontrolscreenshow(false);
                drawnow; pause(0.3);
                tform.fixcolor = uisetcolor(tform.fixcolor,'Pick up a color');
                drawnow; pause(0.3);
                mglsetcontrolscreenshow(true);
                update_fixpoint();
                
            case 'fixsize'
                val = str2double(get(gcbo,'string'));
                if 0<val, tform.fixsize = val; end
                update_fixpoint();
                
            case 'fixinterval'
                val = str2double(get(gcbo,'string'));
                if fixinterval_range(1)<=val && val<=fixinterval_range(2), tform.fixinterval = val; end
                update_fixpoint();
                
            case 'windowsize'
                val = round(str2double(get(gcbo,'string'))*100)/100;
                if 0<val, tform.windowsize = val; end
                
            case {'waittime','holdtime'}
                val = round(str2double(get(gcbo,'string')));
                if 0<val, tform.(obj_tag) = val; end
                
            case 'rewardoptions', DlgRewardOptions();
            case 'savebutton', orig_tform = tform; old_tform = tform;
            case 'revertbutton', tform = old_tform; update_fixpoint();
            case 'cancelbutton', exit_code = -1; return;
        end
        kbdflush;
        update_UI();
    end

    function DlgRewardOptions()
        mglsetcontrolscreenshow(false);
        w = 250 ; h = 235;
        pos = get(gcf,'position') + get(findobj('tag','rewardoptions'),'position'); xymouse = pos(1:2);
        x = xymouse(1) - w;
        y = xymouse(2);
        
        hDlg = figure;
        try
            fontsize = 9;
            bgcolor = [0.9255 0.9137 0.8471];
            set(hDlg,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','Reward variables','color',bgcolor,'windowstyle','modal');

            uicontrol('parent',hDlg,'style','pushbutton','position',[w-160 10 70 25],'tag','done','string','Done','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','pushbutton','position',[w-80 10 70 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',@dlg_proc);
            uicontrol('parent',hDlg,'style','text','position',[10 195 120 25],'string','JuiceLine','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hDlg,'style','text','position',[10 165 120 25],'string','Duration (ms)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hDlg,'style','text','position',[10 135 120 25],'string','Number of Pulses','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hDlg,'style','text','position',[10 105 140 25],'string','Time b/w Pulses (ms)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hDlg,'style','text','position',[10 75 120 25],'string','Trigger Voltage','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            uicontrol('parent',hDlg,'style','text','position',[10 45 120 25],'string','Custom Variables','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            tag(1) = uicontrol('parent',hDlg,'style','edit','position',[140 198 100 25],'tag','RewardJuiceLine','string',num2str(tform.RewardFuncArgs.JuiceLine),'fontsize',fontsize);
            tag(2) = uicontrol('parent',hDlg,'style','edit','position',[140 168 100 25],'tag','RewardDuration','string',num2str(tform.RewardFuncArgs.Duration),'fontsize',fontsize);
            tag(3) = uicontrol('parent',hDlg,'style','edit','position',[140 138 100 25],'tag','RewardNumReward','string',num2str(tform.RewardFuncArgs.NumReward),'fontsize',fontsize);
            tag(4) = uicontrol('parent',hDlg,'style','edit','position',[140 108 100 25],'tag','RewardPauseTime','string',num2str(tform.RewardFuncArgs.PauseTime),'fontsize',fontsize);
            tag(5) = uicontrol('parent',hDlg,'style','edit','position',[140 78 100 25],'tag','RewardTriggerVal','string',num2str(tform.RewardFuncArgs.TriggerVal),'fontsize',fontsize);
            tag(6) = uicontrol('parent',hDlg,'style','edit','position',[120 48 120 25],'tag','RewardCustom','string',tform.RewardFuncArgs.Custom,'fontsize',fontsize);

            exit_code2 = 0; dlg_wait();
            if 1==exit_code2
                str = get(tag(1),'string'); val = str2double(str); tform.RewardFuncArgs.JuiceLine = fi(isnan(val),str,val);
                tform.RewardFuncArgs.Duration = str2double(get(tag(2),'string'));
                tform.RewardFuncArgs.NumReward = str2double(get(tag(3),'string'));
                tform.RewardFuncArgs.PauseTime = str2double(get(tag(4),'string'));
                tform.RewardFuncArgs.TriggerVal = str2double(get(tag(5),'string'));
                tform.RewardFuncArgs.Custom = get(tag(6),'string');
                r = tform.RewardFuncArgs;
                DAQ.goodmonkey(0,'eval',sprintf('PauseTime=%d;TriggerVal=%d;%s',r.PauseTime,r.TriggerVal,r.Custom));
            end
        catch
            % do nothing
        end
        if ishandle(hDlg), close(hDlg); end
        mglsetcontrolscreenshow(true);
        kbdflush;

        function dlg_wait()
            kbdflush;
            while 0==exit_code2
                if ~ishandle(hDlg), exit_code2 = -1; break, end
                kb = kbdgetkey(); if ~isempty(kb) && 1==kb, exit_code2 = -1; end
                pause(0.05);
            end
        end
        function dlg_proc(hObject,~)
            switch get(hObject,'tag')
                case 'done', exit_code2 = 1;
                case 'cancel', exit_code2 = -1;
            end
        end
    end        

    function update_UI()
        set(hTag.operatorview1,'string',num2str(tform.operator_view));
        set(hTag.operatorview2,'value',tform.operator_view);
        set(hTag.originx1,'string',num2str(tform.origin(1)));
        set(hTag.originx2,'value',tform.origin(1));
        set(hTag.originy1,'string',num2str(tform.origin(2)))
        set(hTag.originy2,'value',tform.origin(2));
        set(hTag.gainx1,'string',num2str(tform.gain(1)));
        set(hTag.gainx2,'value',tform.gain(1));
        set(hTag.gainy1,'string',num2str(tform.gain(2)))
        set(hTag.gainy2,'value',tform.gain(2));
        set(hTag.rotation1,'string',num2str(tform.rotation));
        set(hTag.rotation2,'value',tform.rotation);
        if isempty(tform.fiximage)
            set(hTag.fiximage,'string','Select image/movie');
            enable = 'on';
        else
            [~,file,ext] = fileparts(tform.fiximage);
            set(hTag.fiximage,'string',[file ext]);
            enable = 'off';
        end
        set(hTag.fixshape,'enable',enable,'value',tform.fixshape);
        set(hTag.fixcolor,'enable',enable,'backgroundcolor',tform.fixcolor,'foregroundcolor',hsv2rgb(rem(rgb2hsv(tform.fixcolor)+0.5,1)));
        set(hTag.fixsize,'enable',enable,'string',num2str(tform.fixsize));
        set(hTag.fixinterval,'string',num2str(tform.fixinterval));
        set(hTag.windowsize,'string',num2str(tform.windowsize));
        set(hTag.waittime,'string',num2str(tform.waittime));
        set(hTag.holdtime,'string',num2str(tform.holdtime));
        set(hControl,'enable',fi(ui_lock,'off','on'));
        set(hTag.rewardoptions,'string',fi(DAQ.reward_present,'Change Reward Options','Reward I/O Not Assigned!'),'enable',fi(~ui_lock&&DAQ.reward_present,'on','off'));

        update_savebutton();
    end
    function update_savebutton()
        enable = fi(haschanged(tform,old_tform),'on','off');
        set(hTag.savebutton,'enable',enable);
        set(hTag.revertbutton,'enable',enable);
    end

    function setorigin()
        peekdata(DAQ,min(100,DAQ.MinSamplesAvailable));
        switch EyeOrJoy
            case 1
                switch devnum
                    case 1, data = mean(DAQ.Eye,1);
                    case 2, data = mean(DAQ.Eye2,1);
                end
            case 2
                switch devnum
                    case 1, data = mean(DAQ.Joystick,1);
                    case 2, data = mean(DAQ.Joystick2,1);
                end
        end
        tform.origin = max(origin_range(1),min(origin_range(2),round(data*100)/100));
        update_calib_func();
    end

    function closeDlg(varargin)
        if alert, try alertfunc('fini',MLConfig,TrialRecord); catch e, warning(e.message); end, end

        mglenabletouchclick(false);
        setpref('NIMH_MonkeyLogic','LastCalToolPosition',get(hFig,'position'));
        set(hFig,'windowstyle','normal');
        if 1~=exit_code
            button = 'No';
            if haschanged(tform,old_tform)
                mglsetcontrolscreenshow(false);
                options.Interpreter = 'tex';
                options.Default = 'No';
                qstring = ['\fontsize{10}There are some unsaved changes in calibration.' char(10) 'Do you want to save them?']; %#ok<*CHARTEN>
                button = questdlg(qstring,'Calibration has changed','Yes','No',options);
            end
            if strcmp(button,'No'), tform = orig_tform; end
        end
        exit_code = -1;
        try
            if daq_started, stop(DAQ); end
            if daq_created, destroy(DAQ); end
            if mouse_created, delete(mouse); end
            mgldestroygraphic(mlsetdiff(mglgetallobjects,object_id));
            if screen_created(2)
                mgldestroycontrolscreen();
            else
                mglactivategraphic(object_id,object_status);
                mglsetcontrolscreenrect(controlscreeninfo.Rect);
                mglsetscreencolor(2,controlscreeninfo.Color);
                mglsetcontrolscreenzoom(controlscreeninfo.Zoom);
                mglsetcontrolscreenshow(controlscreeninfo.Show);
            end
            if screen_created(1), destroy(Screen); end
            mglclearscreen;
            mglpresent;
        catch
            % do nothing
        end
        fprintf('<<< MonkeyLogic >>> Origin & Gain: FP presented %d time(s), Fixation acquired %d time(s)\n',trial_count,reward_count);
        closereq;
    end

    function update_controlscreen_geometry()
        ControlScreenRect = CalFun.update_controlscreen_geometry();
    end
    function update_calib_func()
        tform.rotation_t = [cosd(tform.rotation) -sind(tform.rotation); sind(tform.rotation) cosd(tform.rotation)]';
        tform.rotation_rev_t = [cosd(-tform.rotation) -sind(-tform.rotation); sind(-tform.rotation) cosd(-tform.rotation)]';
        CalFun.set_transform_matrix(tform);
    end
    function update_fixpoint()
        deg = floor(Screen.SubjectScreenHalfSize / MLConfig.PixelsPerDegree(1) / tform.fixinterval) * tform.fixinterval;
        xdeg = -deg(1):tform.fixinterval:deg(1);
        ydeg = deg(2):-tform.fixinterval:-deg(2);
        xpos = xdeg * MLConfig.PixelsPerDegree(1) + Screen.SubjectScreenHalfSize(1);
        ypos = ydeg * MLConfig.PixelsPerDegree(2) + Screen.SubjectScreenHalfSize(2);
        nx = length(xpos);
        ny = length(ypos);
        nz = nx * ny;
        mgldestroygraphic(fixpoint_id); fixpoint_id = NaN(1,nz);
        fixpoint_pos = zeros(nz,2);
        
        idx = 0;
        imdata = load_cursor(tform.fiximage,tform.fixshape,tform.fixcolor,tform.fixsize*MLConfig.PixelsPerDegree(1));
        for m=1:ny
            for n=1:nx
                idx = idx + 1;
                fixpoint_id(idx) = mgladdbitmap(imdata,2);
                fixpoint_pos(idx,:) = [xpos(n) ypos(m)];
                mglsetorigin(fixpoint_id(idx),fixpoint_pos(idx,:));
            end
        end
        
        imdata = load_cursor(tform.fiximage,tform.fixshape,tform.fixcolor,fi(1==tform.fixshape,6,12));
        if ~isempty(tform.fiximage), imdata = mglimresize(imdata,16/max(size(imdata))); end
        if isnan(trial_count_id(1)), trial_count_id(1) = mgladdbitmap(imdata,12); end
        mglsetproperty(trial_count_id(1),'bitmap',imdata);
    end

    function tf = haschanged(obj,val,field)
        if ~strcmp(class(obj),class(val)), tf = false; return, end
        if ~exist('field','var'), field = fieldnames(obj); end
        tf = false; for m=1:length(field), if ~isequaln(obj.(field{m}),val.(field{m})), tf = true; break, end, end
    end
    function idx = isinside(xy)
        halfsize = mglgetproperty(fixpoint_id(1),'size') / 2;
        idx = fixpoint_pos(:,1)-halfsize(1) <= xy(1) & xy(1) < fixpoint_pos(:,1)+halfsize(1) ...
            & fixpoint_pos(:,2)-halfsize(2) <= xy(2) & xy(2) < fixpoint_pos(:,2)+halfsize(2);
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
