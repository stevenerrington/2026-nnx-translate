function tform = mlcalibrate_spatial_transform(EyeOrJoy,MLConfig,devnum)
% transform from moving points to fixed points

daq_created = false;
if ~exist('EyeOrJoy','var'), EyeOrJoy = 1; end
if ~exist('MLConfig','var')
    MLConfig = mlconfig;
    MLConfig.IOList = mliolist();
    MLConfig.EyeCalibration = 3;
    MLConfig.JoystickCalibration = [3 3];
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

% tform initialization is done in mlcalibrate; we just receive it from there
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
fixinterval_range = [0.5 100];

% validate input
tform.overwritten = false(size(tform.fixed_point,1),1);
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
fixpoint_deg = [];
calibtarget_id = [];
calibtarget_pos = [];
picked_target = [];
picked_target_id = [];
last_picked_target = [];
islinetracer = false;
ControlScreenRect = zeros(1,4);
tracer = [];
current_keystop = 0;
keystop_changed = false;
mouse = [];
mouse_created = false;
daq_started = false;
prev_eye_position = [];
reward_duration_id = [];
eg = fi(verLessThan('matlab','9.8'),'>=','≥');
tform_type = {'projective',['projective (' eg '4 FPs)'];'polynomial3',['polynomial3 (' eg '10 FPs)'];'polynomial4',['polynomial4 (' eg '15 FPs)']};
message_id = [];  % any error message regarding transform calculation

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
        tform.fiximage = '';
        tform.fixshape = 2;
        tform.fixcolor = [1 1 0];
        tform.fixsize = 0.6;
        tform.fixinterval = 5;
        tform.color4uncalibrated = [1 0 0];
        tform.color4calibrated = [0 1 1];
        tform.windowsize = 3;
        tform.waittime = fi(1==EyeOrJoy,2000,30000);
        tform.holdtime = 500;
        tform.reward = 3;
        tform.jittertolerance = 20;
        r = MLConfig.RewardFuncArgs;
        tform.RewardFuncArgs = struct('JuiceLine',1,'Duration',100,'NumReward',1,'PauseTime',40,'TriggerVal',r.TriggerVal,'Custom',r.Custom);
        tform.fixed_point = [5 5; 5 0; 5 -5; 0 5; 0 0; 0 -5; -5 5; -5 0; -5 -5];
        tform.moving_point = tform.fixed_point;
        tform.type = [];
        tform.T = [];
    end

    function run_scene()
        kbdinit;
        frame_counter = 0;
        button_released = true;
        update_interval = round(Screen.RefreshRate/10);
        blink_timer = tic;
        while 0==exit_code
            [xy,buttons] = getsample(mouse); buttons = buttons(1:2);  % remove keycodes
            if xy(1)<ControlScreenRect(1) || xy(2)<ControlScreenRect(2) || ControlScreenRect(3)<xy(1) || ControlScreenRect(4)<xy(2), buttons(:) = false; end  % ignore fix points outside the screen
            switch EyeOrJoy
                case 1
                    if isempty(picked_target) || keystop_changed
                        if keystop_changed
                            keystop_deg = tform.fixed_point(current_keystop,:);
                            picked_target = find(keystop_deg(1)==fixpoint_deg(:,1) & keystop_deg(2)==fixpoint_deg(:,2),1);
                            keystop_changed = false;
                        else
                            if buttons(1)
                                picked_target = find(isinside(CalFun.control2pix(xy)),1);
                                if ~isempty(picked_target)
                                    picked_deg = fixpoint_deg(picked_target,:);
                                    keystop = find(picked_deg(1)==tform.fixed_point(:,1) & picked_deg(2)==tform.fixed_point(:,2),1);
                                    if isempty(keystop), picked_target = []; else, current_keystop = keystop; end
                                end
                            end
                        end
                        if ~isempty(picked_target)
                            mgldestroygraphic(picked_target_id);
                            picked_target_id = [load_cursor(tform.fiximage,tform.fixshape,tform.fixcolor,tform.fixsize*MLConfig.PixelsPerDegree(1),1) ...
                                mglsetproperty(mgladdcircle(fi(4==tform.reward,[0 1 0],tform.color4uncalibrated),tform.windowsize*MLConfig.PixelsPerDegree(1)*2,10),'zorder',1)];
                            mglsetorigin(picked_target_id,fixpoint_pos(picked_target,:));
                            waittimer = tic;
                            waiting = true;
                            frame_counter = 0;
                            last_picked_target = picked_target;
                        end
                    end
                case 2
                    if buttons(1) || keystop_changed
                        if keystop_changed
                            keystop_deg = tform.fixed_point(current_keystop,:);
                            picked = find(keystop_deg(1)==fixpoint_deg(:,1) & keystop_deg(2)==fixpoint_deg(:,2),1);
                            keystop_changed = false;
                        else
                            picked = find(isinside(CalFun.control2pix(xy)),1);
                            if ~isempty(picked)
                                picked_deg = fixpoint_deg(picked,:);
                                keystop = find(picked_deg(1)==tform.fixed_point(:,1) & picked_deg(2)==tform.fixed_point(:,2),1);
                                if isempty(keystop), picked_target = []; else, current_keystop = keystop; end
                            end
                        end
                        if ~isempty(picked)
                            picked_target = picked;
                            mgldestroygraphic(picked_target_id);
                            picked_target_id = [load_cursor(tform.fiximage,tform.fixshape,tform.fixcolor,tform.fixsize*MLConfig.PixelsPerDegree(1),1) ...
                                mglsetproperty(mgladdcircle(fi(4==tform.reward,[0 1 0],tform.color4uncalibrated),tform.windowsize*MLConfig.PixelsPerDegree(1)*2,10),'zorder',1)];
                            mglsetorigin(picked_target_id,fixpoint_pos(picked_target,:));
                            waittimer = tic;
                            waiting = true;
                            frame_counter = 0;
                            last_picked_target = picked_target;
                        end
                    end
            end
            
            if buttons(2)
                if button_released
                    button_released = false;
                    clicked = find(isinside(CalFun.control2pix(xy)),1);
                    selected = find(sum((calibtarget_pos-repmat(CalFun.control2pix(xy),size(calibtarget_pos,1),1)).^2,2) < (tform.fixsize*MLConfig.PixelsPerDegree(1))^2,1);
                    
                    if isempty(selected)
                        if ~isempty(clicked)
                            tform.fixed_point(end+1,:) = fixpoint_deg(clicked,:);
                            tform.moving_point(end+1,:) = NaN;
                            tform.overwritten(end+1,:) = false;
                            update_calib_func();
                            update_savebutton();
                        end
                    else
                        tform.fixed_point(selected,:) = [];
                        tform.moving_point(selected,:) = [];
                        tform.overwritten(selected,:) = [];
                        update_calib_func();
                        update_savebutton();
                    end
                end
            else
                button_released = true;
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
                        if 4==tform.reward
                            if success
                                r = tform.RewardFuncArgs;
                                DAQ.goodmonkey(r.Duration,'numreward',r.NumReward,'juiceline',r.JuiceLine);
                            end
                            mgldestroygraphic(picked_target_id); picked_target_id = [];
                        end
                        picked_target = [];
                    end
                end
                
                mglactivategraphic(tracer,3<sum(~isnan(tform.moving_point(:,1))));
                if islinetracer, mglsetproperty(tracer,'addpoint',CalFun.sig2pix(data,[0 0])); else, mglsetorigin(tracer,CalFun.sig2pix(data(end,:),[0 0])); end
            end

            kb = kbdgetkey();
            if ~isempty(kb)
                switch kb
                    case 1, exit_code = -1;  % esc
                    case 25  % p
                        np = size(tform.fixed_point,1);
                        current_keystop = current_keystop - 1;
                        if current_keystop < 1; current_keystop = np; end
                        keystop_changed = true;
                    case 48  % b
                        mgldestroygraphic(picked_target_id); picked_target_id = [];
                        last_picked_target = [];
                        picked_target = [];
                    case 49  % n
                        np = size(tform.fixed_point,1);
                        current_keystop = current_keystop + 1;
                        if np < current_keystop, current_keystop = 1; end 
                        keystop_changed = true;
                    case 57  % space
                        if ~isempty(last_picked_target)
                            peekdata(DAQ,min(100,DAQ.MinSamplesAvailable));
                            switch EyeOrJoy
                                case 1
                                    switch devnum
                                        case 1, new_moving_point = mean(DAQ.Eye,1);
                                        case 2, new_moving_point = mean(DAQ.Eye2,1);
                                    end
                                case 2
                                    switch devnum
                                        case 1, new_moving_point = mean(DAQ.Joystick,1);
                                        case 2, new_moving_point = mean(DAQ.Joystick2,1);
                                    end
                            end
                            new_fixed_point = fixpoint_deg(last_picked_target,:);
                            idx = find(new_fixed_point(1)==tform.fixed_point(:,1) & new_fixed_point(2)==tform.fixed_point(:,2),1);
                            if isempty(idx), idx = size(tform.fixed_point,1)+1; end
                            tform.fixed_point(idx,:) = new_fixed_point;
                            tform.moving_point(idx,:) = new_moving_point;
                            tform.overwritten(idx,:) = true;
                            update_calib_func();
                            update_savebutton();
                            if 2==tform.reward || 3==tform.reward
                                r = tform.RewardFuncArgs;
                                DAQ.goodmonkey(r.Duration,'numreward',r.NumReward,'juiceline',r.JuiceLine);
                                mgldestroygraphic(picked_target_id); picked_target_id = [];
                                last_picked_target = [];
                                if 3==tform.reward
                                    np = size(tform.fixed_point,1);
                                    current_keystop = current_keystop + 1;
                                    if np < current_keystop, current_keystop = 1; end
                                    keystop_changed = true;
                                end
                            end
                        end
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
                                tform = copyfield(tform,CalFun.translate(-prev_eye_position(end,:)),{'moving_point','T'});
                                prev_eye_position(end,:) = [];
                                update_projection_figure();
                                update_savebutton();
                            end
                        case 46  % c
                            if  ~isempty(data)
                                prev_eye_position(end+1,:) = CalFun.sig2deg(data(end,:),[0 0]); %#ok<AGROW>
                                tform = copyfield(tform,CalFun.translate(prev_eye_position(end,:)),{'moving_point','T'});
                                update_projection_figure();
                                update_savebutton();
                            end
                    end
                end
            end
            if toc(blink_timer)<1.5, mglactivategraphic(message_id,true); elseif toc(blink_timer)<2, mglactivategraphic(message_id,false); else, blink_timer = tic; end
                
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
        reward_type = {'on Manual trigger (R key)','on SPACE key','on SPACE + Move to next','on Fixation'};

        hFig = figure;
        set(hFig,'tag','mlcalibrate','units','pixels','position',fig_pos,'numbertitle','off','name',[sprintf(fi(1==EyeOrJoy,'Eye #%d','Joystick #%d'),devnum) ' calibration: 2-D Spatial Transformation'],'menubar','none','resize','on','color',bgcolor,'windowstyle','modal');
        
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
        hTag.matrix = axes('parent',hFig,'units','pixels','color',MLConfig.SubjectScreenBackground,'xtick',[],'ytick',[]);
        hTag.lock = uicontrol('parent',hFig,'style','pushbutton','tag','lock','string',fi(ui_lock,'Unlock','Lock'),'fontsize',fontsize,'callback',callbackfunc);
        
        hControl(1) = uicontrol('parent',hFig,'style','text','string','Zoom (%) :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.operatorview1 = uicontrol('parent',hFig,'style','edit','tag','operatorview1','fontsize',fontsize,'callback',callbackfunc);
        hTag.operatorview2 = uicontrol('parent',hFig,'style','slider','tag','operatorview2','min',operator_view_range(1),'max',operator_view_range(2),'sliderstep',[1 10]./(operator_view_range(2)-operator_view_range(1)),'value',operator_view_range(1),'fontsize',fontsize,'callback',callbackfunc);
        hControl(2) = hTag.operatorview1; hControl(3) = hTag.operatorview2;

        hControl(4) = uicontrol('parent',hFig,'style','text','string','Fixation point :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.fiximage = uicontrol('parent',hFig,'style','pushbutton','tag','fiximage','fontsize',fontsize,'callback',callbackfunc);
        hControl(5) = hTag.fiximage;

        hTag.fixshape = uicontrol('parent',hFig,'style','popupmenu','tag','fixshape','string',{'Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.fixcolor = uicontrol('parent',hFig,'style','pushbutton','tag','fixcolor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        hTag.fixsize = uicontrol('parent',hFig,'style','edit','tag','fixsize','fontsize',fontsize,'callback',callbackfunc);
        hControl(6) = uicontrol('parent',hFig,'style','text','string','deg','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hControl(7) = hTag.fixshape; hControl(8) = hTag.fixcolor; hControl(9) = hTag.fixsize;
        
        hControl(10) = uicontrol('parent',hFig,'style','text','string','at','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hTag.fixinterval = uicontrol('parent',hFig,'style','edit','tag','fixinterval','fontsize',fontsize,'callback',callbackfunc);
        hControl(11) = uicontrol('parent',hFig,'style','text','string','deg intervals','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hControl(12) = hTag.fixinterval;

        hTag.color4uncalibrated = uicontrol('parent',hFig,'style','pushbutton','tag','color4uncalibrated','string','Uncalibrated','fontsize',fontsize,'callback',callbackfunc);
        hTag.color4calibrated = uicontrol('parent',hFig,'style','pushbutton','tag','color4calibrated','string','Calibrated','fontsize',fontsize,'callback',callbackfunc);
        hControl(13) = hTag.color4uncalibrated; hControl(14) = hTag.color4calibrated;

        hControl(15) = uicontrol('parent',hFig,'style','text','string','Reward :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.reward = uicontrol('parent',hFig,'style','popupmenu','tag','reward','string',reward_type,'fontsize',fontsize,'callback',callbackfunc);
        hControl(16) = hTag.reward;

        hControl(17) = uicontrol('parent',hFig,'style','text','string','Fixation window radius :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.windowsize = uicontrol('parent',hFig,'style','edit','tag','windowsize','fontsize',fontsize,'callback',callbackfunc);
        hControl(18) = uicontrol('parent',hFig,'style','text','string','degrees','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hControl(19) = hTag.windowsize;
        
        hControl(20) = uicontrol('parent',hFig,'style','text','string','Fixation wait time :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.waittime = uicontrol('parent',hFig,'style','edit','tag','waittime','fontsize',fontsize,'callback',callbackfunc);
        hControl(21) = uicontrol('parent',hFig,'style','text','string','msec','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hControl(22) = hTag.waittime;

        hControl(23) = uicontrol('parent',hFig,'style','text','string','Fixation hold time :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.holdtime = uicontrol('parent',hFig,'style','edit','tag','holdtime','fontsize',fontsize,'callback',callbackfunc);
        hControl(24) = uicontrol('parent',hFig,'style','text','string','msec','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hControl(25) = hTag.holdtime;

        hTag.rewardoptions = uicontrol('parent',hFig,'style','pushbutton','tag','rewardoptions','fontsize',fontsize,'callback',callbackfunc);
        hControl(26) = hTag.rewardoptions;

        hControl(27) = uicontrol('parent',hFig,'style','text','string','Transform :','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.tformtype = uicontrol('parent',hFig,'style','popupmenu','tag','tformtype','string',tform_type(:,2)','fontsize',fontsize,'callback',callbackfunc);
        hControl(28) = hTag.tformtype;

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
        if DAQ.reward_present
            reward_duration_id = mgladdtext(sprintf('R key: Manual reward (%.0f ml)',tform.RewardFuncArgs.Duration),12);
            mglsetproperty(reward_duration_id,'origin',[10 90]*Screen.DPI_ratio,'fontsize',12);
            mglsetproperty(mgladdtext('+/-: Increase/decrease reward by 10 ms',12),'origin',[250 90]*Screen.DPI_ratio,'fontsize',12);
        end
        mglsetproperty(mgladdtext('LEFT click: Present fix point',12),'origin',[10 10]*Screen.DPI_ratio,'fontsize',12);
        mglsetproperty(mgladdtext('P key: Prev fix point',12),'origin',[10 30]*Screen.DPI_ratio,'fontsize',12);
        mglsetproperty(mgladdtext('N key: Next fix point',12),'origin',[10 50]*Screen.DPI_ratio,'fontsize',12);
        mglsetproperty(mgladdtext('B key: Turn off fix point',12),'origin',[10 70]*Screen.DPI_ratio,'fontsize',12);
        mglsetproperty(mgladdtext('RIGHT click: Add/Remove fix point',12),'origin',[250 10]*Screen.DPI_ratio,'fontsize',12);
        mglsetproperty(mgladdtext('SPACE key: Sample current eye input',12),'origin',[250 30]*Screen.DPI_ratio,'fontsize',12);
        mglsetproperty(mgladdtext('C key: Set current eye pos as origin',12),'origin',[250 50]*Screen.DPI_ratio,'fontsize',12);
        mglsetproperty(mgladdtext('U key: Undo the C key',12),'origin',[250 70]*Screen.DPI_ratio,'fontsize',12);

        message_id = mgladdtext('',12); mglsetproperty(message_id,'bottom','fontsize',12,'color',[0 1 1]);

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

        if verLessThan('matlab','8.6'), y0 = fig_pos(4) / Screen.DPI_ratio; else, y0 = fig_pos(4); end
        mglsetproperty(message_id,'origin',[5 y0]*Screen.DPI_ratio);

        x0 = fig_pos(3)-245; y0 = fig_pos(4)-30;
        set(hTag.lock,'position',[x0+160 y0+2 80 24]);

        y0 = y0 - 28;
        set(hControl(1),'position',[x0 y0 65 22]);
        set(hTag.operatorview1,'position',[x0+70 y0+2 45 21]);
        set(hTag.operatorview2,'position',[x0+120 y0+4 120 17]);

        y0 = y0 - 33;
        set(hControl(4),'position',[x0 y0 85 22]);
        set(hTag.fiximage,'position',[x0+90 y0+2 150 24]);

        y0 = y0 - 28;
        set(hTag.fixshape,'position',[x0+28 y0 70 24]);
        set(hTag.fixcolor,'position',[x0+105 y0+2 64 24]);
        set(hTag.fixsize,'position',[x0+175 y0+4 37 21]);
        set(hControl(6),'position',[x0+215 y0 110 22]);

        y0 = y0 - 28;
        set(hControl(10),'position',[x0+28 y0 110 22]);
        set(hTag.fixinterval,'position',[x0+50 y0+3 37 21]);
        set(hControl(11),'position',[x0+95 y0 100 22]);

        y0 = y0 - 28;
        set(hTag.color4uncalibrated,'position',[x0+28 y0+2 100 24]);
        set(hTag.color4calibrated,'position',[x0+133 y0+2 100 24]);

        y0 = y0 - 33;
        set(hControl(15),'position',[x0 y0 58 22]);
        set(hTag.reward,'position',[x0+63 y0+3 170 22]);

        y0 = y0 - 28;
        set(hControl(17),'position',[x0 y0 140 22]);
        set(hTag.windowsize,'position',[x0+145 y0+3 45 21]);
        set(hControl(18),'position',[x0+195 y0 110 22]);

        y0 = y0 - 28;
        set(hControl(20),'position',[x0 y0 140 22]);
        set(hTag.waittime,'position',[x0+145 y0+3 45 21]);
        set(hControl(21),'position',[x0+195 y0 110 22]);

        y0 = y0 - 28;
        set(hControl(23),'position',[x0 y0 140 22]);
        set(hTag.holdtime,'position',[x0+145 y0+3 45 21]);
        set(hControl(24),'position',[x0+195 y0 110 22]);

        y0 = y0 - 28;
        set(hTag.rewardoptions,'position',[x0+10 y0+2 220 24]);

        y0 = y0 - 33;
        set(hControl(27),'position',[x0 y0 68 22]);
        set(hTag.tformtype,'position',[x0+73 y0+3 167 22]);

        y0 = y0 - 205;
        set(hTag.matrix,'position',[x0+4 y0 235 200]);

        y0 = 8;
        set(hTag.savebutton,'position',[x0+10 y0+2 65 24]);
        set(hTag.revertbutton,'position',[x0+80 y0+2 65 24]);
        set(hTag.closebutton,'position',[x0+150 y0+2 90 24]);

        if mglcontrolscreenexists
            mglsetcontrolscreenrect(Pos2Rect(replica_pos));
            update_controlscreen_geometry();
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
                tform.(obj_tag) = uisetcolor(tform.(obj_tag),'Pick up a color');
                drawnow; pause(0.3);
                mglsetcontrolscreenshow(true);
                update_fixpoint();
            case 'fixsize'
                val = str2double(get(gcbo,'string'));
                if 0<val, tform.fixsize = val; end
                update_calib_func();
                update_fixpoint();
            case 'fixinterval'
                val = str2double(get(gcbo,'string'));
                if fixinterval_range(1)<=val && val<=fixinterval_range(2), tform.fixinterval = val; end
                update_fixpoint();
            case {'color4uncalibrated','color4calibrated'}
                mglsetcontrolscreenshow(false);
                drawnow; pause(0.3);
                tform.(obj_tag) = uisetcolor(tform.(obj_tag),'Pick up a color');
                drawnow; pause(0.3);
                mglsetcontrolscreenshow(true);
                update_calib_func();
            case 'windowsize'
                val = round(str2double(get(gcbo,'string'))*100)/100;
                if 0<val, tform.windowsize = val; end
            case {'waittime','holdtime'}
                val = round(str2double(get(gcbo,'string')));
                if 0<val, tform.(obj_tag) = val; end
            case 'reward', tform.(obj_tag) = get(gcbo,'value');
            case 'rewardoptions', DlgRewardOptions();
            case 'tformtype', tform.type = tform_type{get(gcbo,'value'),1}; update_calib_func();
            case 'savebutton', orig_tform = tform; old_tform = tform;
            case 'revertbutton', tform = old_tform; update_calib_func(); update_fixpoint();
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
        set(hTag.fixsize','enable',enable,'string',num2str(tform.fixsize));
        set(hTag.fixinterval,'string',num2str(tform.fixinterval));
        set(hTag.color4uncalibrated,'backgroundcolor',tform.color4uncalibrated,'foregroundcolor',hsv2rgb(rem(rgb2hsv(tform.color4uncalibrated)+0.5,1)));
        set(hTag.color4calibrated,'backgroundcolor',tform.color4calibrated,'foregroundcolor',hsv2rgb(rem(rgb2hsv(tform.color4calibrated)+0.5,1)));
        set(hTag.reward,'value',tform.reward);
        enable = fi(4~=tform.reward,'off','on');
        set(hTag.windowsize,'string',num2str(tform.windowsize),'enable',enable);
        set(hTag.waittime,'string',num2str(tform.waittime),'enable',enable);
        set(hTag.holdtime,'string',num2str(tform.holdtime),'enable',enable);
        set(hControl,'enable',fi(ui_lock,'off','on'));
        set(hTag.rewardoptions,'string',fi(DAQ.reward_present,'Change Reward Options','Reward I/O Not Assigned!'),'enable',fi(~ui_lock&&DAQ.reward_present,'on','off'));
        set(hTag.tformtype,'value',find(strcmp(tform_type(:,1),tform.type),1));

        update_savebutton();
    end
    function update_savebutton()
        enable = fi(haschanged(tform,old_tform),'on','off');
        set(hTag.savebutton,'enable',enable);
        set(hTag.revertbutton,'enable',enable);
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
            
        % to keep the compatibility of MLConfig with older versions
        if isfield(tform,'T') && isfield(tform.T,'projective') && isstruct(tform.T.projective), for m=fieldnames(tform.T.projective)', tform.(m{1}) = tform.T.projective.(m{1}); end, end

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
        closereq;
    end

    function update_controlscreen_geometry()
        ControlScreenRect = CalFun.update_controlscreen_geometry();
    end
    function update_calib_func()
        try
            tform.T.(tform.type) = geometric_transform('calc',tform.type,tform.moving_point,tform.fixed_point);
            CalFun.set_transform_matrix(tform);  % in case a calculation error occurs, this line is skipped so that CalFun may not be updated.
            mglsetproperty(message_id,'text','');
        catch err
            mglsetproperty(message_id,'text',err.message);
            fprintf(2,'%s\n',err.message);
        end
        
        np = size(tform.fixed_point,1);
        mgldestroygraphic(calibtarget_id); calibtarget_id = NaN(1,np);
        calibtarget_pos = CalFun.deg2pix(tform.fixed_point);
        for m=1:np
            color = fi(isnan(tform.moving_point(m,1)),tform.color4uncalibrated,tform.color4calibrated);
            calibtarget_id(m) = mgladdtext(num2str(m),10);
            mglsetproperty(calibtarget_id(m),'origin',calibtarget_pos(m,:),'color',color);
        end
        mglsetproperty(calibtarget_id,'font','Arial',max(30,min(150,tform.fixsize*MLConfig.PixelsPerDegree(1)*2/Screen.DPI_ratio)),'center','middle');
        
        update_projection_figure();
    end
    function update_projection_figure()
        row = ~isnan(tform.moving_point(:,1));
        xy = tform.moving_point(row,:);
        uv = CalFun.sig2deg(xy,[0 0]);
        axes(hTag.matrix); cla; hold on;
        if ~isempty(xy)
            idx = tform.overwritten(row,1);
            plot(xy(idx,1),xy(idx,2),'o','markerfacecolor',tform.color4uncalibrated);
            plot(uv(idx,1),uv(idx,2),'o','markerfacecolor',tform.color4calibrated);
            plot(xy(:,1),xy(:,2),'o','markeredgecolor',tform.color4uncalibrated);
            plot(uv(:,1),uv(:,2),'o','markeredgecolor',tform.color4calibrated);
            quiver(xy(:,1),xy(:,2),uv(:,1)-xy(:,1),uv(:,2)-xy(:,2),0,'color',hsv2rgb(rem(rgb2hsv(MLConfig.SubjectScreenBackground)+0.5,1)));
        end
        plot(tform.fixed_point(:,1),tform.fixed_point(:,2),'+','markeredgecolor',tform.fixcolor);
        set(gca,'color',MLConfig.SubjectScreenBackground,'xtick',[],'ytick',[]);
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
        mgldestroygraphic(fixpoint_id); fixpoint_id = NaN(1,nz); fixpoint_pos = zeros(nz,2); fixpoint_deg = zeros(nz,2);
        
        idx = 0;
        imdata = load_cursor(tform.fiximage,tform.fixshape,tform.fixcolor,tform.fixsize*MLConfig.PixelsPerDegree(1));
        for m=1:ny
            for n=1:nx
                idx = idx + 1;
                fixpoint_id(idx) = mgladdbitmap(imdata,2);
                fixpoint_pos(idx,:) = [xpos(n) ypos(m)];
                fixpoint_deg(idx,:) = [xdeg(n) ydeg(m)];
                mglsetorigin(fixpoint_id(idx),fixpoint_pos(idx,:));
            end
        end
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
