function varargout = mliotest(MLConfig)

daq_created = false;
if ~exist('MLConfig','var')
    MLConfig = mlconfig;
    MLConfig.HighFrequencyDAQ = struct('Adaptor','nidaq','DevID','Dev3','SampleRate',10000);
    entry = {'Eye X','nidaq','Dev2','AnalogInput',0,[]; 'Eye Y','nidaq','Dev2','AnalogInput',1,[]; ...
        'Eye2 X','nidaq','Dev2','AnalogInput',2,[]; 'Eye2 Y','nidaq','Dev2','AnalogInput',3,[]; ...
        'Joystick X','nidaq','Dev2','AnalogInput',4,[]; 'Joystick Y','nidaq','Dev2','AnalogInput',5,[]; ...
        'Joystick2 X','nidaq','Dev2','AnalogInput',6,[]; 'Joystick2 Y','nidaq','Dev2','AnalogInput',7,[]; ...
        'Reward','nidaq','Dev4','DigitalIO',0,{0,'out'}; ...
        'Button 1','nidaq','Dev4','DigitalIO',0,{1,'in'}; 'Button 2','nidaq','Dev4','DigitalIO',0,{2,'in'}; ...
        'Button 3','nidaq','Dev4','DigitalIO',0,{3,'in'}; 'Button 4','nidaq','Dev4','DigitalIO',0,{4,'in'}; ...
        'Button 5','nidaq','Dev4','DigitalIO',0,{5,'in'}; 'Button 6','nidaq','Dev4','DigitalIO',0,{6,'in'}; ...
        'Button 7','nidaq','Dev4','DigitalIO',0,{7,'in'}; 'Button 8','nidaq','Dev4','DigitalIO',1,{0,'in'}; ...
        'Button 9','nidaq','Dev4','DigitalIO',1,{1,'in'}; 'Button 10','nidaq','Dev4','DigitalIO',1,{2,'in'}; ...
        'General Input 1','nidaq','Dev2','AnalogInput',8,[]; 'General Input 2','nidaq','Dev2','AnalogInput',9,[]; ...
        'General Input 3','nidaq','Dev2','AnalogInput',10,[]; 'General Input 4','nidaq','Dev2','AnalogInput',11,[]; ...
        'General Input 5','nidaq','Dev2','AnalogInput',12,[]; 'General Input 6','nidaq','Dev2','AnalogInput',13,[]; ...
        'General Input 7','nidaq','Dev2','AnalogInput',14,[]; 'General Input 8','nidaq','Dev2','AnalogInput',15,[]; ...
        'General Input 9','nidaq','Dev2','AnalogInput',16,[]; 'General Input 10','nidaq','Dev2','AnalogInput',17,[]; ...
        'Stimulation 1','nidaq','Dev1','AnalogOutput',0,[]; 'Stimulation 2','nidaq','Dev1','AnalogOutput',1,[]; ...
        'Stimulation 3','nidaq','Dev1','AnalogOutput',2,[]; 'Stimulation 4','nidaq','Dev1','AnalogOutput',3,[]; ...
        'TTL 1','nidaq','Dev1','DigitalIO',0,{0,'out'}; 'TTL 2','nidaq','Dev1','DigitalIO',0,{1,'out'}; ...
        'TTL 3','nidaq','Dev1','DigitalIO',0,{2,'out'}; 'TTL 4','nidaq','Dev1','DigitalIO',0,{3,'out'}; ...
        'TTL 5','nidaq','Dev1','DigitalIO',0,{4,'out'}; 'TTL 6','nidaq','Dev1','DigitalIO',0,{5,'out'}; ...
        'TTL 7','nidaq','Dev1','DigitalIO',0,{6,'out'}; 'TTL 8','nidaq','Dev1','DigitalIO',0,{7,'out'}; ...
        'TTL 9','nidaq','Dev1','DigitalIO',0,{8,'out'}; 'TTL 10','nidaq','Dev1','DigitalIO',0,{9,'out'}; ...
        'High Frequency 1','nidaq','Dev3','AnalogInput',0,[]; 'High Frequency 3','nidaq','Dev3','AnalogInput',1,[]; ...
        'High Frequency 5','nidaq','Dev3','AnalogInput',2,[]; 'High Frequency 7','nidaq','Dev3','AnalogInput',3,[]; ...
        };
    MLConfig.IO = cell2struct(entry,{'SignalType','Adaptor','DevID','Subsystem','Channel','DIOInfo'},2);
    MLConfig.IOList = mliolist;
    MLConfig.Touchscreen = struct('On',true,'NumTouch',10);
    MLConfig.TouchCursorImage = 'hand_touch.png';
    MLConfig.VoiceRecording = struct('ID','0','SampleRate',48000,'Stereo','Stereo');
    daq_created = true;
    create(MLConfig.DAQ,MLConfig);
end

try
    general_selected = MLConfig.IOTestParam.general_selected;
    general_range = MLConfig.IOTestParam.general_range;
    highfreq_selected = MLConfig.IOTestParam.highfreq_selected;
    highfreq_range = MLConfig.IOTestParam.highfreq_range;
    voice_range = MLConfig.IOTestParam.voice_range;
    update_interval = MLConfig.IOTestParam.update_interval;
catch
    general_selected = [];
    general_range = [];
    highfreq_selected = [];
    highfreq_range = [];
    voice_range = [];
    update_interval = [];
end

daq_started = false;
screen_created = false(1,2);
controlscreeninfo = mglgetscreeninfo(2);  % empty when control screen does not exist already
[object_id,~,object_status] = mglgetallobjects();

DAQ = MLConfig.DAQ;
Screen = MLConfig.Screen;
if ~mglsubjectscreenexists, create(Screen,MLConfig); screen_created(1) = true; end
CalFun = mlcalibrate(1,MLConfig);

hFig = [];
fig_pos = [];
mouse = [];
mouse_created = false;
looping = true;

err = [];
try
    init();
    run_scene();
catch err
    % do nothing
end
varargout{1} = struct('general_selected',general_selected,'general_range',general_range,'highfreq_selected',highfreq_selected, ...
    'highfreq_range',highfreq_range,'voice_range',voice_range,'update_interval',update_interval);

if ishandle(hFig), close(hFig); end
if ~isempty(err) && ~strcmp(err.identifier,'MATLAB:unassignedOutputs'), throw(err); end

    function run_scene()
        fontsize = 12;
        DPI_ratio = Screen.DPI_ratio;
        gap = 10 * DPI_ratio;

        eye_pos = [50 50 200 200] * DPI_ratio;
        eye_half = eye_pos(3:4) / 2;
        eye_center = eye_pos(1:2) + eye_half;
        eye_dim_color = MLConfig.EyeTracerColor(1,:);
        mglsetorigin(mgladdbox(eye_dim_color,eye_pos(3:4),12),eye_center);
        eye_title = '';
        eyex = [-10 10];
        eyey = [-10 10];
        if DAQ.eye_present
            eye_title = 'Eye 1';
            eye_device = DAQ.get_device('eye');
            if isa(eye_device,'analoginput')
                input_range = eye_device.EyeX.InputRange; eyex = [min(eyex(1),input_range(1)) max(eyex(2),input_range(2))];
                input_range = eye_device.EyeY.InputRange; eyey = [min(eyey(1),input_range(1)) max(eyey(2),input_range(2))];
            end
            EyeLineTracer = strcmp(MLConfig.EyeTracerShape{1},'Line');
            if EyeLineTracer
                eye_tracer = mgladdline(MLConfig.EyeTracerColor(1,:),10,1,12);
            else
                eye_tracer = load_cursor('',MLConfig.EyeTracerShape{1},MLConfig.EyeTracerColor(1,:),MLConfig.EyeTracerSize(1),12);
            end
        end
        if DAQ.eye2_present
            if isempty(eye_title), eye_title = 'Eye 2'; else, eye_title = 'Eye 1 & 2'; end
            eye_device = DAQ.get_device('eye2');
            if isa(eye_device,'analoginput')
                input_range = eye_device.Eye2X.InputRange; eyex = [min(eyex(1),input_range(1)) max(eyex(2),input_range(2))];
                input_range = eye_device.Eye2Y.InputRange; eyey = [min(eyey(1),input_range(1)) max(eyey(2),input_range(2))];
            end
            Eye2LineTracer = strcmp(MLConfig.EyeTracerShape{2},'Line');
            if Eye2LineTracer
                eye2_tracer = mgladdline(MLConfig.EyeTracerColor(2,:),10,1,12);
            else
                eye2_tracer = load_cursor('',MLConfig.EyeTracerShape{2},MLConfig.EyeTracerColor(2,:),MLConfig.EyeTracerSize(2),12);
            end
        end
        if DAQ.eye_present || DAQ.eye2_present
            eye_range = [eyex(2) -eyey(2)];
            mglsetproperty(mgladdtext(sprintf('%d',eyex(1)),12),'origin',[eye_pos(1) sum(eye_pos([2 4]))+gap],'center','top','fontsize',fontsize,'color',eye_dim_color);
            mglsetproperty(mgladdtext(sprintf('%d',eyex(2)),12),'origin',[sum(eye_pos([1 3])) sum(eye_pos([2 4]))+gap],'center','top','fontsize',fontsize,'color',eye_dim_color);
            mglsetproperty(mgladdtext(sprintf('%d',eyey(2)),12),'origin',[eye_pos(1)-gap eye_pos(2)],'right','middle','fontsize',fontsize,'color',eye_dim_color);
            mglsetproperty(mgladdtext(sprintf('%d',eyey(1)),12),'origin',[eye_pos(1)-gap sum(eye_pos([2 4]))],'right','middle','fontsize',fontsize,'color',eye_dim_color);
        else
            mglsetproperty(mgladdtext('No eye assigned',12),'origin',eye_center,'center','middle','fontsize',fontsize,'color',MLConfig.EyeTracerColor(1,:));
        end
        if isempty(eye_title), eye_title = 'Eye XY'; end
        mglsetproperty(mgladdtext(eye_title,12),'origin',[eye_pos(1)+eye_pos(3)/2 eye_pos(2)-gap],'center','bottom','fontsize',fontsize,'color',eye_dim_color);

        joy_pos = [300 50 200 200] * DPI_ratio;
        joy_half = joy_pos(3:4) / 2;
        joy_center = joy_pos(1:2) + joy_half;
        joy_dim_color = MLConfig.JoystickCursorColor(1,:);
        mglsetorigin(mgladdbox(joy_dim_color,joy_pos(3:4),12),joy_center);
        joy_title = '';
        joyx = [-10 10];
        joyy = [-10 10];
        if DAQ.joystick_present
            joy_title = 'Joystick 1';
            joy_device = DAQ.get_device('joystick');
            if isa(joy_device,'analoginput')
                input_range = joy_device.JoystickX.InputRange; joyx = [min(joyx(1),input_range(1)) max(joyx(2),input_range(2))];
                input_range = joy_device.JoystickY.InputRange; joyy = [min(joyy(1),input_range(1)) max(joyy(2),input_range(2))];
            end
            joy_cursor = load_cursor(MLConfig.JoystickCursorImage{1},MLConfig.JoystickCursorShape{1},MLConfig.JoystickCursorColor(1,:),MLConfig.JoystickCursorSize(1),12);
        end
        if DAQ.joystick2_present
            if isempty(joy_title), joy_title = 'Joystick 2'; else, joy_title = 'Joystick 1 & 2'; end
            joy_device = DAQ.get_device('joystick2');
            if isa(joy_device,'analoginput')
                input_range = joy_device.Joystick2X.InputRange; joyx = [min(joyx(1),input_range(1)) max(joyx(2),input_range(2))];
                input_range = joy_device.Joystick2Y.InputRange; joyy = [min(joyy(1),input_range(1)) max(joyy(2),input_range(2))];
            end
            joy2_cursor = load_cursor(MLConfig.JoystickCursorImage{2},MLConfig.JoystickCursorShape{2},MLConfig.JoystickCursorColor(2,:),MLConfig.JoystickCursorSize(2),12);
        end
        if DAQ.joystick_present || DAQ.joystick2_present
            joy_range = [joyx(2) -joyy(2)];
            mglsetproperty(mgladdtext(sprintf('%d',joyx(1)),12),'origin',[joy_pos(1) sum(joy_pos([2 4]))+gap],'center','top','fontsize',fontsize,'color',joy_dim_color);
            mglsetproperty(mgladdtext(sprintf('%d',joyx(2)),12),'origin',[sum(joy_pos([1 3])) sum(joy_pos([2 4]))+gap],'center','top','fontsize',fontsize,'color',joy_dim_color);
            mglsetproperty(mgladdtext(sprintf('%d',joyy(2)),12),'origin',[joy_pos(1)-gap joy_pos(2)],'right','middle','fontsize',fontsize,'color',joy_dim_color);
            mglsetproperty(mgladdtext(sprintf('%d',joyy(1)),12),'origin',[joy_pos(1)-gap sum(joy_pos([2 4]))],'right','middle','fontsize',fontsize,'color',joy_dim_color);
        else
            mglsetproperty(mgladdtext('No joystick assigned',12),'origin',joy_center,'center','middle','fontsize',fontsize,'color',MLConfig.JoystickCursorColor(1,:));
        end
        if isempty(joy_title), joy_title = 'Joystick XY'; end
        mglsetproperty(mgladdtext(joy_title,12),'origin',[joy_pos(1)+joy_pos(3)/2 joy_pos(2)-gap],'center','bottom','fontsize',fontsize,'color',joy_dim_color);

        if DAQ.touch_present
            touch_cursor = NaN(MLConfig.Touchscreen.NumTouch,2);
            for m=1:size(touch_cursor,1)
                touch_cursor(m,2) = load_cursor(MLConfig.TouchCursorImage,MLConfig.TouchCursorShape,MLConfig.TouchCursorColor,MLConfig.TouchCursorSize,10);
            end
        end

        general = DAQ.general_available;
        ngeneral = length(general);
        general_color = MLConfig.TouchCursorColor;
        general_dim_color = general_color;
        general_tracer = NaN(1,ngeneral);
        mglsetproperty(mgladdtext('General Input',12),'origin',[650 50-gap] * DPI_ratio,'center','bottom','fontsize',fontsize,'color',general_dim_color);
        if 0 < ngeneral
            general_h = min(round(600/ngeneral),100);
            general_pos = zeros(ngeneral,4);
            for m=1:ngeneral
                general_pos(m,:) = [550 50+(m-1)*general_h 200 general_h] * DPI_ratio;
                mglsetorigin(mgladdbox(general_dim_color,general_pos(m,3:4),12),general_pos(m,1:2) + general_pos(m,3:4)/2);
                mglsetproperty(mgladdtext(sprintf('#%d',general(m)),12),'origin',general_pos(m,1:2) + [-gap general_pos(m,4)/2],'right','middle','fontsize',fontsize,'color',general_dim_color);
            end
            for m=1:ngeneral, general_tracer(m) = mgladdline(general_color,general_pos(m,3),1,12); end

            if isempty(general_selected), general_selected = [1 0]; end
            if isempty(general_range) || ngeneral~=size(general_range,1), general_range = repmat([-10 10],ngeneral,1); end
            n = general_selected(1);
            general_ytick = [mgladdtext(sprintf('%d',general_range(n,1)),12) mgladdtext(sprintf('%d',general_range(n,2)),12)];
            mglsetproperty(general_ytick(1),'origin',[general_pos(n,1)+general_pos(n,3)+gap general_pos(n,2)+general_pos(n,4)],'middle','fontsize',fontsize,'color',general_dim_color);
            mglsetproperty(general_ytick(2),'origin',[general_pos(n,1)+general_pos(n,3)+gap general_pos(n,2)],'middle','fontsize',fontsize,'color',general_dim_color);
        else
            mglsetproperty(mgladdtext('No general input assigned',12),'origin',[650 150] * DPI_ratio,'center','middle','fontsize',fontsize,'color',general_color);
        end
        
        highfreq = DAQ.highfrequency_available;
        nhighfreq = length(highfreq);
        highfreq_color = [0.6000 0.8510 0.9176];
        highfreq_dim_color = highfreq_color;
        highfreq_tracer = NaN(1,nhighfreq);
        mglsetproperty(mgladdtext('High Frequency',12),'origin',[900 50-gap] * DPI_ratio,'center','bottom','fontsize',fontsize,'color',highfreq_dim_color);
        if 0 < nhighfreq
            highfreq_h = min(round(600/nhighfreq),100);
            highfreq_pos = zeros(nhighfreq,4);
            for m=1:nhighfreq
                highfreq_pos(m,:) = [800 50+(m-1)*highfreq_h 200 highfreq_h] * DPI_ratio;
                mglsetorigin(mgladdbox(highfreq_dim_color,highfreq_pos(m,3:4),12),highfreq_pos(m,1:2) + highfreq_pos(m,3:4)/2);
                mglsetproperty(mgladdtext(sprintf('#%d',highfreq(m)),12),'origin',highfreq_pos(m,1:2) + [-gap highfreq_pos(m,4)/2],'right','middle','fontsize',fontsize,'color',highfreq_dim_color);
            end
            for m=1:nhighfreq, highfreq_tracer(m) = mgladdline(highfreq_color,highfreq_pos(m,3),1,12); end

            if isempty(highfreq_selected), highfreq_selected = [1 0]; end
            if isempty(highfreq_range) || nhighfreq~=size(highfreq_range,1), highfreq_range = repmat([-10 10],nhighfreq,1); end
            n = highfreq_selected(1);
            highfreq_ytick = [mgladdtext(sprintf('%d',highfreq_range(n,1)),12) mgladdtext(sprintf('%d',highfreq_range(n,2)),12)];
            mglsetproperty(highfreq_ytick(1),'origin',[highfreq_pos(n,1)+highfreq_pos(n,3)+gap highfreq_pos(n,2)+highfreq_pos(n,4)],'middle','fontsize',fontsize,'color',highfreq_dim_color);
            mglsetproperty(highfreq_ytick(2),'origin',[highfreq_pos(n,1)+highfreq_pos(n,3)+gap highfreq_pos(n,2)],'middle','fontsize',fontsize,'color',highfreq_dim_color);
        else
            mglsetproperty(mgladdtext('No high frequency assigned',12),'origin',[900 150] * DPI_ratio,'center','middle','fontsize',fontsize,'color',highfreq_color);
        end
        
        voice_pos = [100 300 400 80] * DPI_ratio;
        voice_half = voice_pos(3:4) / 2;
        voice_center = voice_pos(1:2) + voice_half;
        voice_color = [1 1 1];
        voice_dim_color = voice_color;
        voice_tracer = NaN(1,2);
        mglsetproperty(mgladdtext('Voice',12),'origin',[40*DPI_ratio voice_center(2)],'middle','fontsize',fontsize,'color',voice_dim_color);
        if DAQ.voice_present
            mglsetorigin(mgladdbox(voice_dim_color,voice_pos(3:4),12),voice_center);
            voice_tracer = [mgladdline(voice_color,200,1,12) mgladdline(0.5*voice_color,200,1,12)];
            if isempty(voice_range), voice_range = [-0.3 0.3]; end
            voice_ytick = [mgladdtext(sprintf('%.2g',voice_range(1)),12) mgladdtext(sprintf('%.2g',voice_range(2)),12)];
            mglsetproperty(voice_ytick(1),'origin',[voice_pos(1)-gap voice_pos(2)+voice_pos(4)],'right','middle','fontsize',fontsize,'color',voice_dim_color);
            mglsetproperty(voice_ytick(2),'origin',[voice_pos(1)-gap voice_pos(2)],'right','middle','fontsize',fontsize,'color',voice_dim_color);
        else
            mglsetproperty(mgladdtext('No voice recording device assigned',12),'origin',[120*DPI_ratio voice_center(2)],'middle','fontsize',fontsize,'color',voice_color);
        end
        
        y0 = 430;
        load('mlimagedata.mat','green_pressed','green_released','stimulation_triggered','stimulation_dimmed','ttl_triggered','ttl_dimmed');
        STMAvailable = DAQ.stimulation_available;
        nstimulation = length(STMAvailable);
        STM_color = [1 1 1];
        STM_dim_color = STM_color;
        mglsetproperty(mgladdtext('STM',12),'origin',[40 y0] * DPI_ratio,'middle','fontsize',fontsize,'color',STM_dim_color);
        if 0 < nstimulation
            STM = NaN(2,nstimulation);
            STM_pos = zeros(nstimulation,4);
            for m=1:nstimulation
                STM(1,m) = mgladdtext(sprintf('%d',STMAvailable(m)),12);
                STM(2,m) = mgladdbitmap(mglimresize(stimulation_dimmed,DPI_ratio),12);
                STM(3,m) = mgladdbitmap(mglimresize(stimulation_triggered,DPI_ratio),12);

                x0 = 120 + (m-1)*40;
                mglsetproperty(STM(1,m),'center','fontsize',fontsize);
                mglsetorigin(STM(:,m), [x0 y0-30; x0 y0; x0 y0] * DPI_ratio);
                STM_pos(m,:) = [x0-15 y0-15 x0+15 y0+15] * DPI_ratio;
            end
        else
            mglsetproperty(mgladdtext('No stimulation assigned',12),'origin',[120 y0] * DPI_ratio,'middle','fontsize',fontsize,'color',STM_color);
        end

        y0 = y0 + 50;
        TTLAvailable = DAQ.ttl_available;
        nttl = length(TTLAvailable);
        TTL_color = [1 1 1];
        TTL_dim_color = STM_color;
        mglsetproperty(mgladdtext('TTL',12),'origin',[40 y0] * DPI_ratio,'middle','fontsize',fontsize,'color',TTL_dim_color);
        if 0 < nttl
            TTL = NaN(2,nttl);
            TTL_pos = zeros(nttl,4);
            for m=1:nttl
                no = TTLAvailable(m);
                TTL(1,m) = mgladdtext(sprintf('%d',no),12);
                if DAQ.TTLInvert(no)
                    TTL(2,m) = mgladdbitmap(mglimresize(ttl_dimmed(end:-1:1,:,:,:),DPI_ratio),12);
                    TTL(3,m) = mgladdbitmap(mglimresize(ttl_triggered(end:-1:1,:,:,:),DPI_ratio),12);
                else
                    TTL(2,m) = mgladdbitmap(mglimresize(ttl_dimmed,DPI_ratio),12);
                    TTL(3,m) = mgladdbitmap(mglimresize(ttl_triggered,DPI_ratio),12);
                end

                x0 = 120 + (m-1)*40;
                mglsetproperty(TTL(1,m),'center','fontsize',fontsize);
                mglsetorigin(TTL(:,m), [x0 y0-30; x0 y0; x0 y0] * DPI_ratio);
                TTL_pos(m,:) = [x0-15 y0-15 x0+15 y0+15] * DPI_ratio;
            end
        else
            mglsetproperty(mgladdtext('No TTL assigned',12),'origin',[120 y0] * DPI_ratio,'middle','fontsize',fontsize,'color',TTL_color);
        end

        y0 = y0 + 50;
        ButtonsAvailable = DAQ.buttons_available;
        nbutton = length(ButtonsAvailable);
        cnbutton = cumsum(DAQ.nButton);
        button_color = [1 1 1];
        button_dim_color = button_color;
        mglsetproperty(mgladdtext('Button',12),'origin',[40 y0] * DPI_ratio,'middle','fontsize',fontsize,'color',button_dim_color);
        if DAQ.button_present
            ButtonLabel = NaN(1,nbutton);
            ButtonPressed = NaN(1,nbutton);
            ButtonReleased = NaN(1,nbutton);
            b0 = 0; b1 = 0; b2 = 0;
            for m=1:nbutton
                DAQ.button_threshold(ButtonsAvailable(m),[]);
                ButtonLabel(m) = mgladdtext(sprintf('%d',ButtonsAvailable(m)),12);
                mglsetproperty(ButtonLabel(m),'center','fontsize',fontsize,'color',button_dim_color);

                if cnbutton(2) < ButtonsAvailable(m)
                    x1 = 120 + b2*40; y1 = y0+100; b2 = b2+1;
                elseif cnbutton(1) < ButtonsAvailable(m)
                    x1 = 120 + b1*40; y1 = y0+50; b1 = b1+1;
                else
                    x1 = 120 + b0*40; y1 = y0; b0 = b0+1;
                end
                ButtonPressed(m) = mgladdbitmap(mglimresize(green_pressed,DPI_ratio),12);
                ButtonReleased(m) = mgladdbitmap(mglimresize(green_released,DPI_ratio),12);
                mglsetorigin([ButtonLabel(m) ButtonPressed(m) ButtonReleased(m)],[x1 y1-30; x1 y1; x1 y1] * DPI_ratio);
            end
        else
            mglsetproperty(mgladdtext('No button assigned',12),'origin',[120 y0] * DPI_ratio,'middle','fontsize',fontsize,'color',button_color);
        end

        if verLessThan('matlab','8.6'), y0 = fig_pos(4) / DPI_ratio - 10; else, y0 = fig_pos(4) - 10; end
        esc_id = mgladdtext('To test STMs and TTLs, click on the icons. To quit, press ESC.',12);
        mglsetproperty(esc_id,'origin',[10 y0] * DPI_ratio,'bottom','fontsize',fontsize);
        esc_pos = mglgetproperty(esc_id,'rect');

        mglsetproperty(mgladdtext(['AI Configuration: ' MLConfig.AIConfiguration],12),'color',[1 1 1],'origin',[500 y0] * DPI_ratio,'bottom','fontsize',fontsize);

        if isempty(update_interval), update_interval = 0.02; end
        interval_id = mgladdtext(sprintf('Update interval: %d ms',round(update_interval*1000)),12);
        mglsetproperty(interval_id,'color',[1 1 1],'origin',[850 y0] * DPI_ratio,'bottom','fontsize',fontsize);

        count = 0;
        last_selected_STM = [];
        last_selected_TTL = [];
        selected_group = 0;
        kbdinit;
        while looping
            if daq_started, flushdata(DAQ); end
            getsample(DAQ);

            if DAQ.eye_present
                eye = DAQ.Eye ./ eye_range .* eye_half + eye_center;
                if EyeLineTracer
                    mglsetproperty(eye_tracer,'addpoint',eye);
                else
                    mglsetorigin(eye_tracer,eye);
                end
            end
            if DAQ.eye2_present
                eye = DAQ.Eye2 ./ eye_range .* eye_half + eye_center;
                if Eye2LineTracer
                    mglsetproperty(eye2_tracer,'addpoint',eye);
                else
                    mglsetorigin(eye2_tracer,eye);
                end
            end
            if DAQ.joystick_present
                mglsetorigin(joy_cursor,DAQ.Joystick ./ joy_range .* joy_half + joy_center);
            end
            if DAQ.joystick2_present
                mglsetorigin(joy2_cursor,DAQ.Joystick2 ./ joy_range .* joy_half + joy_center);
            end
            if DAQ.touch_present
                if ~isempty(DAQ.Touch)
                    touch = CalFun.subject2pix(reshape(DAQ.Touch,2,[])');
                    mglactivategraphic(touch_cursor(:,2),~isnan(touch(:,1)));
                    mglsetorigin(touch_cursor(:,2),touch);
                end
            end
            for m=1:ngeneral
                r = general_range(m,:);
                v = min(r(2),max(r(1),DAQ.General(general(m))));
                v = (v-r(1)) / (r(2)-r(1));
                mglsetproperty(general_tracer(m),'addpoint',general_pos(m,1:2) + [count*DPI_ratio (1-v)*general_pos(m,4)]);
            end
            for m=1:nhighfreq
                r = highfreq_range(m,:);
                v = min(r(2),max(r(1),DAQ.HighFrequency(highfreq(m))));
                v = (v-r(1)) / (r(2)-r(1));
                mglsetproperty(highfreq_tracer(m),'addpoint',highfreq_pos(m,1:2) + [count*DPI_ratio (1-v)*highfreq_pos(m,4)]);
            end
            if DAQ.button_present
                mglactivategraphic(ButtonPressed,DAQ.Button(ButtonsAvailable));
                mglactivategraphic(ButtonReleased,~DAQ.Button(ButtonsAvailable));
            end
            if DAQ.voice_present
                if ~isempty(DAQ.Voice)
                    r = voice_range;
                    v = DAQ.Voice;
                    v(v<r(1)) = r(1); v(r(2)<v) = r(2);
                    v = (v-r(1)) ./ (r(2)-r(1));
                    mglsetproperty(voice_tracer(1),'addpoint',voice_pos(1:2) + [2*count*DPI_ratio (1-v(1))*voice_pos(4)]);
                    if 1<length(v), mglsetproperty(voice_tracer(2),'addpoint',voice_pos(1:2) + [2*count*DPI_ratio (1.1-v(2))*voice_pos(4)]); end
                end
            end
            
            [xy,buttons] = getsample(mouse); buttons = buttons(1:2);  % remove keycodes
            cs = mglgetscreeninfo(2,'Rect');
            xy = xy - cs(1:2);
            
            if 0 < nstimulation
                selected = find(STM_pos(:,1)<xy(1) & xy(1)<STM_pos(:,3) & STM_pos(:,2)<xy(2) & xy(2)<STM_pos(:,4),1);
                if ~isempty(selected) && isempty(last_selected_STM) && isempty(last_selected_TTL)
                    mglsetproperty(STM(1,selected),'color',[1 1 1]);
                    if any(buttons)
                        ao = DAQ.Stimulation{STMAvailable(selected)};
                        ao.TriggerType = 'Immediate';
                        ao.SampleRate = 40;
                        ch = ao.(sprintf('Stimulation%d',STMAvailable(selected))).Index;
                        data = zeros(11,length(ao.Channel));
                        data(:,ch) = [repmat([5 -5],1,5) 0]';
                        putdata(ao,data);
                        start(ao);
                        mglactivategraphic(STM(2,selected),false);
                        last_selected_STM = selected;
                    end
                elseif ~any(buttons) && isempty(last_selected_STM)
                    mglsetproperty(STM(1,:),'color',[0.5 0.5 0.5]);
                end
                if ~isempty(last_selected_STM) && ~any(buttons) && ~isrunning(DAQ.Stimulation{STMAvailable(last_selected_STM)})
                    stop(DAQ.Stimulation{STMAvailable(last_selected_STM)});
                    mglsetproperty(STM(1,last_selected_STM),'color',[0.5 0.5 0.5]);
                    mglactivategraphic(STM(2,last_selected_STM),true);
                    last_selected_STM = [];
                end
            end
            if 0 < nttl
                selected = find(TTL_pos(:,1)<xy(1) & xy(1)<TTL_pos(:,3) & TTL_pos(:,2)<xy(2) & xy(2)<TTL_pos(:,4),1);
                if ~isempty(selected) && isempty(last_selected_STM) && isempty(last_selected_TTL)
                    mglsetproperty(TTL(1,selected),'color',[1 1 1]);
                    if any(buttons)
                        no = TTLAvailable(selected);
                        putvalue(DAQ.TTL{no},~DAQ.TTLInvert(no));
                        mglactivategraphic(TTL(2,selected),false);
                        last_selected_TTL = selected;
                    end
                elseif ~any(buttons)
                    mglsetproperty(TTL(1,:),'color',[0.5 0.5 0.5]);
                end
                if ~isempty(last_selected_TTL) && ~any(buttons)
                    no = TTLAvailable(last_selected_TTL);
                    putvalue(DAQ.TTL{no},DAQ.TTLInvert(no));
                    mglsetproperty(TTL(1,last_selected_TTL),'color',[0.5 0.5 0.5]);
                    mglactivategraphic(TTL(2,last_selected_TTL),true);
                    last_selected_TTL = [];
                end
            end
            
            mglrendergraphic(0,2);
            mglpresent(2,true,false);
            pause(update_interval);
            
            count = count + 1; if 200<=count, count = 0; mglsetproperty([general_tracer highfreq_tracer voice_tracer],'clear'); end
            if 0 < ngeneral
                for m=1:ngeneral
                    pos = [general_pos(m,1:2) general_pos(m,1:2)+general_pos(m,3:4)];
                    if any(buttons) && (pos(1)<xy(1) && xy(1)<pos(3) && pos(2)<xy(2) && xy(2)<pos(4)), general_selected = [m 0]; selected_group = 1; break, end
                end
                m = general_selected(1);
                pos = [general_pos(m,1:2) general_pos(m,1:2)+general_pos(m,3:4)];
                mglsetproperty(general_ytick(1),'text',sprintf('%d',general_range(m,1)),'origin',[pos(3)+gap pos(4)]);
                mglsetproperty(general_ytick(2),'text',sprintf('%d',general_range(m,2)),'origin',[pos(3)+gap pos(2)]);
                
                pos = mglgetproperty(general_ytick(1),'rect');
                if any(buttons) && (pos(1)<xy(1) && xy(1)<pos(3) && pos(2)<xy(2) && xy(2)<pos(4)), general_selected(2) = 1; selected_group = 1; end
                pos = mglgetproperty(general_ytick(2),'rect');
                if any(buttons) && (pos(1)<xy(1) && xy(1)<pos(3) && pos(2)<xy(2) && xy(2)<pos(4)), general_selected(2) = 2; selected_group = 1; end
            end
            if 0 < nhighfreq
                for m=1:nhighfreq
                    pos = [highfreq_pos(m,1:2) highfreq_pos(m,1:2)+highfreq_pos(m,3:4)];
                    if any(buttons) && (pos(1)<xy(1) && xy(1)<pos(3) && pos(2)<xy(2) && xy(2)<pos(4)), highfreq_selected = [m 0]; selected_group = 2; break, end
                end
                m = highfreq_selected(1);
                pos = [highfreq_pos(m,1:2) highfreq_pos(m,1:2)+highfreq_pos(m,3:4)];
                mglsetproperty(highfreq_ytick(1),'text',sprintf('%d',highfreq_range(m,1)),'origin',[pos(3)+gap pos(4)]);
                mglsetproperty(highfreq_ytick(2),'text',sprintf('%d',highfreq_range(m,2)),'origin',[pos(3)+gap pos(2)]);
                
                pos = mglgetproperty(highfreq_ytick(1),'rect');
                if any(buttons) && (pos(1)<xy(1) && xy(1)<pos(3) && pos(2)<xy(2) && xy(2)<pos(4)), highfreq_selected(2) = 1; selected_group = 2; end
                pos = mglgetproperty(highfreq_ytick(2),'rect');
                if any(buttons) && (pos(1)<xy(1) && xy(1)<pos(3) && pos(2)<xy(2) && xy(2)<pos(4)), highfreq_selected(2) = 2; selected_group = 2; end
            end
            if DAQ.voice_present
                mglsetproperty(voice_ytick(1),'text',sprintf('%.2g',voice_range(1)));
                mglsetproperty(voice_ytick(2),'text',sprintf('%.2g',voice_range(2)));
                
                pos = [voice_pos(1:2) voice_pos(1:2)+voice_pos(3:4)];
                if any(buttons) && (pos(1)<xy(1) && xy(1)<pos(3) && pos(2)<xy(2) && xy(2)<pos(4)), selected_group = 3; end
            end
            
            kb = kbdgetkey;
            if ~isempty(kb)
                switch kb
                    case 1, looping = false;  % esc
                    case 203, update_interval = max(update_interval-0.005,0.005);  % left
                    case 205, update_interval = min(update_interval+0.005,0.05);   % right
                    case 19  % r
                        r = MLConfig.RewardFuncArgs;
                        DAQ.goodmonkey(r.Duration,'numreward',r.NumReward,'juiceline',r.JuiceLine,'nonblocking',1);
                end
                mglsetproperty(interval_id,'text',sprintf('Update interval: %d ms',round(update_interval*1000)));
                
                if 1==selected_group && 0 < ngeneral && 0 < general_selected(2)
                    m = general_selected(1);
                    n = general_selected(2);
                    temp = general_range(m,n);
                    switch kb
                        case 200, general_range(m,n) = general_range(m,n) + 1;  % up
                        case 208, general_range(m,n) = general_range(m,n) - 1;  % down
                    end
                    if general_range(m,1)<-10 || 10<general_range(m,2) || general_range(m,2)<=general_range(m,1), general_range(m,n) = temp; end
                end
                if 2==selected_group && 0 < nhighfreq && 0 < highfreq_selected(2)
                    m = highfreq_selected(1);
                    n = highfreq_selected(2);
                    temp = highfreq_range(m,n);
                    switch kb
                        case 200, highfreq_range(m,n) = highfreq_range(m,n) + 1;  % up
                        case 208, highfreq_range(m,n) = highfreq_range(m,n) - 1;  % down
                    end
                    if highfreq_range(m,1)<-10 || 10<highfreq_range(m,2) || highfreq_range(m,2)<=highfreq_range(m,1), highfreq_range(m,n) = temp; end
                end
                if 3==selected_group
                    switch kb
                        case 200, if voice_range(2)<0.095, voice_range = voice_range + [-0.01 0.01]; else, voice_range = voice_range + [-0.1 0.1]; end  % up
                        case 208, if voice_range(2)<0.105, voice_range = voice_range + [0.01 -0.01]; else, voice_range = voice_range + [0.1 -0.1]; end  % down
                    end
                    if voice_range(2)<0.01, voice_range = [-0.01 0.01]; elseif 1<voice_range(2), voice_range = [-1 1]; end
                end
            end
            
            if esc_pos(1)<xy(1) && xy(1)<esc_pos(3) && esc_pos(2)<xy(2) && xy(2)<esc_pos(4)
                mglsetproperty(esc_id,'color',[1 1 0]);
                if any(buttons), looping = false; end
            else
                mglsetproperty(esc_id,'color',[1 1 1]);
            end
        end
    end

    function init()
        fig_pos = [0 0 1050 700]; if verLessThan('matlab','8.6'), fig_pos = fig_pos * Screen.DPI_ratio; end
        h = findobj('tag','mlmonitor');
        if isempty(h), h = findobj('tag','mlmainmenu'); end
        if isempty(h), screen_pos = GetMonitorPosition(mglgetcommandwindowrect); pos = screen_pos; else, pos = get(h,'position'); screen_pos = GetMonitorPosition(Pos2Rect(pos)); end
        fig_pos(1) = min(max(pos(1) + 0.5 * (pos(3) - fig_pos(3)), screen_pos(1)), sum(screen_pos([1 3])) - fig_pos(3));
        fig_pos(2) = min(max(pos(2) + 0.5 * (pos(4) - fig_pos(4) - 30), screen_pos(2) + 40), sum(screen_pos([2 4])) - fig_pos(4) - 30);
        replica_pos = fig_pos + [1 1 -2 -1];

        hFig = figure;
        set(hFig,'tag','mliotest','units','pixels','position',fig_pos,'numbertitle','off','name','NIMH MonkeyLogic I/O test','menubar','none','resize','off','windowstyle','modal');

        set(hFig,'closerequestfcn',@closeDlg);
        if verLessThan('matlab','9.7')
            warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            jFrame = get(hFig,'JavaFrame'); %#ok<JAVFM>
            jAxis = jFrame.getAxisComponent;
            set(jAxis.getComponent(0),'AncestorMovedCallback',@on_move);
        else
            addlistener(hFig,'LocationChanged',@on_move);
        end

        if mglcontrolscreenexists
            mglactivategraphic(object_id,false);
            mglsetcontrolscreenrect(Pos2Rect(replica_pos));
            mglsetcontrolscreenshow(true);
        else
            screen_created(2) = true;
            mglcreatecontrolscreen(Pos2Rect(replica_pos));
        end
        mglsetcontrolscreenzoom(1);
        mgladdbox([0 0 0; 0 0 0],Screen.SubjectScreenFullSize,2);
        mglsetscreencolor(2,fi(MLConfig.Touchscreen.On,[0.25 0.25 0.25],[0 0 0]));

        mouse = DAQ.get_device('mouse');
        if isempty(mouse), mouse_created = true; mouse = pointingdevice; end
        if ~isrunning(DAQ), daq_started = true; start(DAQ); end
        ml_timer = tic; while 0==DAQ.MinSamplesAvailable, if 5<toc(ml_timer), error('Data acquisition stopped.'); end, end

        mglenabletouchclick(true);
    end

    function on_move(varargin)
        if mglcontrolscreenexists
            fig_pos = get(hFig,'position');
            replica_pos = fig_pos + [1 1 -2 -1];
            mglsetcontrolscreenrect(Pos2Rect(replica_pos));
        end
    end
    function closeDlg(varargin)
        mglenabletouchclick(false);
        looping = false;
        for m=DAQ.stimulation_available, ao = DAQ.Stimulation{m}; stop(ao); ao.TriggerType = 'Manual'; end
        for m=DAQ.ttl_available, putvalue(DAQ.TTL{m},DAQ.TTLInvert(m)); end
        
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
        mglclearscreen(2);
        mglpresent(2);
        closereq;
    end
    function op = fi(tf,op1,op2)
        if tf, op = op1; else, op = op2; end
    end
end
