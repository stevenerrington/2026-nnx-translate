function varargout = trialholder(MLConfig,TrialRecord,TaskObject,TrialData) %#ok<FNDEF>

% initialization
global ML_global_timer ML_global_timer_offset ML_prev_eye_position ML_prev_eye2_position ML_trialtime_offset ML_Clock
if isempty(ML_global_timer), ML_global_timer = tic; ML_trialtime_offset = toc(ML_global_timer); end
varargout{1} = [];

DAQ = MLConfig.DAQ;
Screen = MLConfig.Screen;
SIMULATION_MODE = TrialRecord.SimulationMode;
if SIMULATION_MODE, DAQ.add_mouse(); DAQ.init_simulated_devices(); end

% write the Info field from the conditions file if it exists in TrialRecord
Info = TrialRecord.CurrentConditionInfo; %#ok<NASGU>
StimulusInfo = TrialRecord.CurrentConditionStimulusInfo;

% calibration function providers
EyeCal = mlcalibrate('eye',MLConfig,1);
Eye2Cal = mlcalibrate('eye',MLConfig,2);
JoyCal = mlcalibrate('joy',MLConfig,1);
Joy2Cal = mlcalibrate('joy',MLConfig,2);

% TaskObject variables
ML_nObject = length(TaskObject);

% RunScene parameters
param_ = RunSceneParam(MLConfig);
param_.Screen = Screen;
param_.DAQ = DAQ;
param_.TaskObject = TaskObject;
if DAQ.mouse_present, param_.Mouse = DAQ.get_device('mouse'); else, param_.Mouse = pointingdevice; end
param_.SimulationMode = SIMULATION_MODE;
param_.Cursor.ShowJoy = [false SIMULATION_MODE|DAQ.joystick_present];
param_.Cursor.ShowJoy2 = [false SIMULATION_MODE|DAQ.joystick2_present];
param_.Cursor.ShowTouch = [false SIMULATION_MODE|DAQ.touch_present];
param_.trialtime = @trialtime;
param_.goodmonkey = @goodmonkey;
param_.dashboard = @dashboard;

% prepare indicators
if 1 < MLConfig.PhotoDiodeTrigger, mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[param_.PhotoDiodeStatus ~param_.PhotoDiodeStatus]); end
mglsetproperty([Screen.EyeTracer Screen.Eye2Tracer],'clear');
mglactivategraphic(Screen.Dashboard,true);
mglactivategraphic([Screen.Reward Screen.RewardCount Screen.RewardDuration Screen.TTL(:)' Screen.Stimulation(:)'],false);

ML_Tracker = TrackerAggregate();
if SIMULATION_MODE || DAQ.eye_present, eye_ = EyeTracker(MLConfig,TaskObject,EyeCal,SIMULATION_MODE); ML_Tracker.add(eye_); end
if SIMULATION_MODE || DAQ.eye2_present, eye2_ = Eye2Tracker(MLConfig,TaskObject,Eye2Cal,SIMULATION_MODE); ML_Tracker.add(eye2_); end
if SIMULATION_MODE || DAQ.joystick_present, joy_ = JoyTracker(MLConfig,TaskObject,JoyCal,SIMULATION_MODE,param_); ML_Tracker.add(joy_); end
if SIMULATION_MODE || DAQ.joystick2_present, joy2_ = Joy2Tracker(MLConfig,TaskObject,Joy2Cal,SIMULATION_MODE,param_); ML_Tracker.add(joy2_); end
if SIMULATION_MODE || DAQ.touch_present, touch_ = TouchTracker(MLConfig,TaskObject,EyeCal,SIMULATION_MODE,param_); ML_Tracker.add(touch_); end
if SIMULATION_MODE || DAQ.button_present, button_ = ButtonTracker(MLConfig,TaskObject,EyeCal,SIMULATION_MODE); ML_Tracker.add(button_); end
if SIMULATION_MODE || DAQ.mouse_present, mouse_ = MouseTracker(MLConfig,TaskObject,EyeCal,SIMULATION_MODE,param_); ML_Tracker.add(mouse_); end
null_ = NullTracker(MLConfig,TaskObject,EyeCal,SIMULATION_MODE);


    %% function trialtime
    function ml_t = trialtime(), ml_t = (toc(ML_global_timer) - ML_trialtime_offset) * 1000; end  % in milliseconds

    %% function create_scene
    function ml_scene = create_scene(adapter,stimuli)
        if ~exist('stimuli','var'), stimuli = []; end
        ml_scene = SceneArgs;
        adapter.info(ml_scene);
        ml_scene.Adapter = adapter;
        for ml_=stimuli(:)'
            switch TaskObject.Modality(ml_)
                case 1, ml_scene.Visual(end+1) = ml_;
                case 2, ml_scene.Visual(end+1) = ml_; ml_scene.Movie(end+1) = ml_;
                case 3, ml_scene.Sound(end+1) = ml_;
                case 4, ml_scene.STM(end+1) = ml_;
                case 5, ml_scene.TTL(end+1) = ml_;
            end
        end
    end

    %% function run_scene
    ML_GraphicsUsedInThisTrial = false(1,ML_nObject);
    ML_SkippedFrameTimeInfo = [];
    ML_TotalSkippedFrames = 0;
    ML_SceneCount = 0;
    ML_ObjectStatusRecord.SceneParam(1) = copy(SceneArgs);
    ML_MaxFrameInterval = 0;
    ML_MaxDrawingTime = 0;
    ML_IO_Channel = zeros(1,ML_nObject); ML_ = 4==TaskObject.Modality|5==TaskObject.Modality; ML_IO_Channel(ML_) = TaskObject.MoreInfo(ML_).Channel;
    function ml_fliptime = run_scene(scene,event)
        if ~exist('event','var'), event = []; end
        
        mglactivategraphic(TaskObject.ID(scene.Visual),true); TaskObject.Status(scene.Visual) = true;  % status update for forced_eye_drift_correction
        mglactivatesound(TaskObject.ID(scene.Sound),true);
        if ~isempty(scene.STM), ml_stm = ML_IO_Channel(scene.STM); register([DAQ.Stimulation{ml_stm}]); mglactivategraphic(Screen.Stimulation(:,ml_stm),true); end
        if ~isempty(scene.TTL), ml_ttl = ML_IO_Channel(scene.TTL); register([DAQ.TTL{ml_ttl}],'TTL',DAQ.TTLInvert(ml_ttl)); mglactivategraphic(Screen.TTL(:,ml_ttl),true); end
        if 1 < MLConfig.PhotoDiodeTrigger, param_.PhotoDiodeStatus = ~param_.PhotoDiodeStatus; mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[param_.PhotoDiodeStatus ~param_.PhotoDiodeStatus]); end
        ML_GraphicsUsedInThisTrial(scene.Visual) = true;
        scene.Position = TaskObject.Position;
        scene.Scale = TaskObject.Scale;
        scene.Angle = TaskObject.Angle;
        scene.Zorder = TaskObject.Zorder;
        scene.BackgroundColor = Screen.BackgroundColor;
        [scene.MovieCurrentPosition,scene.MovieLooping] = mdqmex(11,13,TaskObject.ID(scene.Movie));
        scene.Cursor = param_.Cursor;
        
        param_.reset();
        ML_Tracker.init(param_);
        scene.Adapter.init(param_);
        if 0==ML_SceneCount, mglwait4vblank(true); mglwait4vblank(false); end  % to start the first scene in sync with the refresh cycle
        
        DAQ.peekfront();
        ml_drawingstart = trialtime();
        if TrialRecord.DiscardSkippedFrames, param_.FrameNum = round(ml_drawingstart/Screen.FrameLength); else, param_.FrameNum = param_.FrameNum + 1; end
        param_.SceneStartFrame = param_.FrameNum;
        param_.SceneStartTime = ml_drawingstart;
        ML_Tracker.acquire(param_);
        continue_ = scene.Adapter.analyze(param_);
        scene.Adapter.draw(param_);
        mglrendergraphic(param_.FrameNum);
        ML_MaxDrawingTime = max(ML_MaxDrawingTime,param_.scene_time());
        ml_fliptime = mdqmex(9,4,true,[event param_.EventMarker],true); clearmarker(param_);
        mglpresent(2,MLConfig.Touchscreen.On,SIMULATION_MODE);
        param_.FirstFlipTime = ml_fliptime;
        param_.LastFlipTime = ml_fliptime;
        while continue_
            DAQ.peekfront();
            ml_drawingstart = trialtime();
            if TrialRecord.DiscardSkippedFrames, param_.FrameNum = round(ml_drawingstart/Screen.FrameLength); else, param_.FrameNum = param_.FrameNum + 1; end
            ML_Tracker.acquire(param_);
            continue_ = scene.Adapter.analyze(param_);
            scene.Adapter.draw(param_);
            mglrendergraphic(param_.FrameNum);
            ml_drawingtime = trialtime() - ml_drawingstart;
            ML_MaxDrawingTime = max(ML_MaxDrawingTime,ml_drawingtime);
            ml_currentflip = mdqmex(9,4,true,param_.EventMarker,false); clearmarker(param_);
            mglpresent(2,MLConfig.Touchscreen.On,SIMULATION_MODE);
            ml_frame_interval = ml_currentflip - param_.LastFlipTime;
            param_.SkippedFrame = round(ml_frame_interval/Screen.FrameLength) - 1;
            if 0 < param_.SkippedFrame
                if TrialRecord.MarkSkippedFrames, eventmarker(13); end
                ML_TotalSkippedFrames = ML_TotalSkippedFrames + param_.SkippedFrame;
                ml_skippedframetime = param_.LastFlipTime + Screen.FrameLength;
                ML_SkippedFrameTimeInfo(end+1,1:5) = [ml_skippedframetime ml_currentflip param_.SkippedFrame Screen.FrameLength ml_drawingtime]; %#ok<AGROW>
            end
            ML_MaxFrameInterval = max(ML_MaxFrameInterval,ml_frame_interval);
            param_.KeyStroke = kbdgetkey; if ~isempty(param_.KeyStroke), hotkey(param_.KeyStroke); end
            param_.LastFlipTime = ml_currentflip;
        end
        scene.Adapter.fini(param_);
        ML_Tracker.fini(param_);
        
        mglactivategraphic(TaskObject.ID(scene.Visual),false); TaskObject.Status(scene.Visual) = false;
        
        scene.Time = ml_fliptime;
        ML_SceneCount = ML_SceneCount + 1;
        ML_ObjectStatusRecord.SceneParam(ML_SceneCount) = copy(scene);
    end

    %% function eventmarker
    function eventmarker(code), DAQ.eventmarker(code); end

    %% function goodmonkey
    ML_RewardCount = 0;
    function goodmonkey(duration, varargin)
        ML_RewardCount = ML_RewardCount + DAQ.goodmonkey(duration, varargin{:});
        if (SIMULATION_MODE || DAQ.reward_present) && 0 < duration
            mglactivategraphic([Screen.Reward Screen.RewardCount],true);
            mglsetproperty(Screen.RewardCount,'text',sprintf('%d',ML_RewardCount));
        end
    end

    %% function trialerror
    TrialData.TrialError = 9;
    function trialerror(varargin)
        if 1<nargin
            if 1 < TrialRecord.CurrentTrialNumber, return, end
            ml_code = [varargin{1:2:end}]';
            ml_codename = varargin(2:2:end)';
            ml_ = ml_code<10;
            TrialRecord.TaskInfo.TrialErrorCodes(ml_code(ml_)+1) = ml_codename(ml_);
            return
        else
            ml_e = varargin{1};
        end
        
        if islogical(ml_e), ml_e = double(ml_e); end
        if isnumeric(ml_e)
            if ml_e < 0 || 9 < ml_e, error('TrialErrors can range from 0 to 9'); end
            TrialData.TrialError = ml_e;
        elseif ischar(ml_e)
            ml_f = find(strncmpi(TrialRecord.TaskInfo.TrialErrorCodes,ml_e,length(ml_e)));
            if isempty(ml_f)
                error('Unrecognized string passed to TrialError');
            elseif 1 < length(ml_f)
                error('Ambiguous argument passed to TrialError');
            end
            TrialData.TrialError = ml_f - 1;
        else
            error('Unexpected argument type passed to TrialError (must be either numeric or string)');
        end
    end

    %% function mouse_position
    function [ml_mouse, ml_button, ml_key] = mouse_position(varargin)
        if DAQ.touch_present, mglcallmessageloop(SIMULATION_MODE); end
        [ml_xy, ml_button] = getsample(param_.Mouse);
        if 0==nargin
            if SIMULATION_MODE
                ml_mouse = EyeCal.control2deg(ml_xy);
            else
                ml_mouse = EyeCal.subject2deg(ml_xy);
            end
        else
            ml_mouse = ml_xy;
        end
        ml_key = ml_button(3:end);
        ml_button = ml_button(1:2);
    end

    %% function eye_position
    function varargout = eye_position()
        if SIMULATION_MODE
            ml_eye = mouse_position();
        elseif DAQ.eye_present
            getsample(DAQ);
            ml_eye = EyeCal.sig2deg(DAQ.Eye,param_.EyeOffset);
        else
            ml_eye = NaN(1,2);
        end
        switch nargout
            case 1, varargout{1} = ml_eye;
            case 2, varargout{1} = ml_eye(1); varargout{2} = ml_eye(2);
        end
    end

    %% function eye2_position
    function varargout = eye2_position()
        if SIMULATION_MODE
            ml_eye2 = DAQ.SimulatedEye2;
        elseif DAQ.eye2_present
            getsample(DAQ);
            ml_eye2 = Eye2Cal.sig2deg(DAQ.Eye2,param_.Eye2Offset);
        else
            ml_eye2 = NaN(1,2);
        end
        switch nargout
            case 1, varargout{1} = ml_eye2;
            case 2, varargout{1} = ml_eye2(1); varargout{2} = ml_eye2(2);
        end
    end

    %% function joystick_position
    function varargout = joystick_position()
        if SIMULATION_MODE
            ml_joy = DAQ.SimulatedJoystick;
        elseif DAQ.joystick_present
            getsample(DAQ);
            ml_joy = JoyCal.sig2deg(DAQ.Joystick,param_.JoyOffset);
        else
            ml_joy = NaN(1,2);
        end
        switch nargout
            case 1, varargout{1} = ml_joy;
            case 2, varargout{1} = ml_joy(1); varargout{2} = ml_joy(2);
        end
    end

    %% function joystick2_position
    function varargout = joystick2_position()
        if SIMULATION_MODE
            ml_joy2 = DAQ.SimulatedJoystick2;
        elseif DAQ.joystick2_present
            getsample(DAQ);
            ml_joy2 = Joy2Cal.sig2deg(DAQ.Joystick2,param_.Joy2Offset);
        else
            ml_joy2 = NaN(1,2);
        end
        switch nargout
            case 1, varargout{1} = ml_joy2;
            case 2, varargout{1} = ml_joy2(1); varargout{2} = ml_joy2(2);
        end
	end

    %% function touch_position
    function ml_touch = touch_position()
        ml_touch = [];
        if DAQ.touch_present, mglcallmessageloop(SIMULATION_MODE); end
        if SIMULATION_MODE
            [ml_xy, ml_button] = getsample(param_.Mouse);
            ml_touch = repmat(EyeCal.control2deg(ml_xy),1,2); ml_touch(~ml_button(1),1:2) = NaN; ml_touch(~ml_button(2),3:4) = NaN;
        elseif DAQ.touch_present
            getsample(DAQ);
            ml_touch = EyeCal.subject2deg(DAQ.Touch);
        end
    end

    %% function istouching
    function ml_touched = istouching()
        ml_touched = any(~isnan(touch_position()));
    end

    %% function get_analog_data
    function [ml_data,ml_freq] = get_analog_data(sig,varargin)
        sig = lower(sig);
        if isempty(varargin), ml_numsamples = 1; else, ml_numsamples = varargin{1}; end
        
        if strcmp(sig,'voice')
            ml_freq = DAQ.VoiceInfo.SampleRate;
            ml_voice = get_device(DAQ,'voice');
            if SIMULATION_MODE && isempty(ml_voice)
                ml_data = repmat(sin(((-ml_numsamples:-1)/ml_freq + toc(ML_global_timer))*2*pi/5)',1,2) + 0.1*rand(ml_numsamples,2);
            else
                ml_data = peekdata(ml_voice,ml_numsamples);
            end
            return
        end
        if strncmp(sig,'hig',3)
            ml_freq = MLConfig.HighFrequencyDAQ.SampleRate;
            ml_ = str2double(regexp(sig,'\d+','match'));
            if SIMULATION_MODE && isempty(DAQ.highfrequency_available)
                ml_ch = fi(isempty(ml_),DAQ.DAQ.nHighFrequency,1);
                ml_data = repmat(10 * sin(((-ml_numsamples:-1)/ml_freq + toc(ML_global_timer))*2*pi/5)',1,ml_ch) + rand(ml_numsamples,ml_ch);
            else
                [ml_high,ml_chan] = get_device(DAQ,'highfrequency');
                ml_samples = peekdata(ml_high,ml_numsamples);
                if isempty(ml_)
                    ml_data = cell(1,DAQ.nHighFrequency);
                    for ml_=DAQ.highfrequency_available, ml_data{ml_} = ml_samples(:,ml_chan(ml_)); end
                else
                    ml_data = ml_samples(:,ml_chan(ml_));
                end
            end
            return
        end
        if strncmp(sig,'lsl',3)
            ml_ = str2double(regexp(sig,'\d+','match')); if isempty(ml_), error('%s: signal number is needed',sig); end
            ml_freq = DAQ.LSLinfo(ml_,1);
            if SIMULATION_MODE && isempty(DAQ.LSL{ml_})
                ml_fr = fi(isnan(ml_freq),1000,ml_freq);
                ml_ch = DAQ.LSLinfo(ml_,2); ml_ch = fi(isnan(ml_ch),1,ml_ch);
                ml_data = repmat(10 * sin(((-ml_numsamples:-1)/ml_fr + toc(ML_global_timer))*2*pi/5)',1,ml_ch) + rand(ml_numsamples,ml_ch);
            else
                lsl_pull_chunk(DAQ);
                ml_count = 0;
                for m=size(DAQ.LSLchunk,1):-1:1
                    ml_count = ml_count + size(DAQ.LSLchunk{m,ml_},1);
                    if ml_numsamples<=ml_count, break, end
                end
                ml_data = vertcat(DAQ.LSLchunk{m:end,ml_});
                if ml_numsamples<ml_count, ml_data = ml_data(ml_count-ml_numsamples+1:end,:); end
            end
            return
        end
        
        ml_freq = 1000;
        peekdata(DAQ,ml_numsamples);
        if SIMULATION_MODE
            switch sig
                case 'eye', ml_data = EyeCal.control2deg(DAQ.Mouse);
                case 'eye2', ml_data = repmat(DAQ.SimulatedEye2,ml_numsamples,1);
                case 'eyeextra', ml_data = repmat(sin(((-ml_numsamples:-1)/ml_freq + toc(ML_global_timer))*2*pi/5)',1,4);
                case {'joy','joystick'}, ml_data = repmat(DAQ.SimulatedJoystick,ml_numsamples,1);
                case {'joy2','joystick2'}, ml_data = repmat(DAQ.SimulatedJoystick2,ml_numsamples,1);
                case 'touch', ml_data = repmat(EyeCal.control2deg(DAQ.Mouse),1,2); ml_data(~DAQ.MouseButton(:,1),1:2) = NaN; ml_data(~DAQ.MouseButton(:,2),3:4) = NaN;
                case 'mouse', ml_data = EyeCal.control2deg(DAQ.Mouse);
                case 'mousebutton', ml_data = DAQ.MouseButton;
                case 'key', ml_data = DAQ.KeyInput;
                otherwise
                    ml_ = str2double(regexp(sig,'\d+','match'));
                    switch sig(1:3)
                        case 'gen'
                            if isempty(DAQ.general_available)
                                ml_data = 10 * sin(((-ml_numsamples:-1)/ml_freq + toc(ML_global_timer))*2*pi/5)' + rand(ml_numsamples,1);
                                if isempty(ml_), ml_data = repmat({ml_data},1,DAQ.nGeneral); end
                            else
                                if isempty(ml_), ml_data = DAQ.General; else, ml_data = DAQ.General{ml_}; end
                            end
                        case {'but','btn'}
                            if isempty(DAQ.buttons_available)
                                ml_data = 0.5<sin(((-ml_numsamples:-1)/ml_freq + toc(ML_global_timer))*2*pi/3)';
                                if isempty(ml_), ml_data = repmat({ml_data},1,sum(DAQ.nButton)); end
                            else
                                if isempty(ml_), ml_data = DAQ.Button; else, ml_data = DAQ.Button{ml_}; end
                            end
                        otherwise, error('%s: unknown signal type!!!',sig);
                    end
            end
        else
            switch sig
                case 'eye', ml_data = EyeCal.sig2deg(DAQ.Eye,param_.EyeOffset);
                case 'eye2', ml_data = Eye2Cal.sig2deg(DAQ.Eye2,param_.Eye2Offset);
                case 'eyeextra', ml_data = DAQ.EyeExtra;
                case {'joy','joystick'}, ml_data = JoyCal.sig2deg(DAQ.Joystick,param_.JoyOffset);
                case {'joy2','joystick2'}, ml_data = Joy2Cal.sig2deg(DAQ.Joystick2,param_.Joy2Offset);
                case 'touch', ml_data = EyeCal.subject2deg(DAQ.Touch);
                case 'mouse', ml_data = EyeCal.subject2deg(DAQ.Mouse);
                case 'mousebutton', ml_data = DAQ.MouseButton;
                case 'key', ml_data = DAQ.KeyInput;
                otherwise
                    ml_ = str2double(regexp(sig,'\d+','match'));
                    switch sig(1:3)
                        case 'gen', if isempty(ml_), ml_data = DAQ.General; else, ml_data = DAQ.General{ml_}; end
                        case {'but','btn'}, if isempty(ml_), ml_data = DAQ.Button; else, ml_data = DAQ.Button{ml_}; end
                        otherwise, error('%s: unknown signal type!!!',sig);
                    end
            end
        end
    end

    %% function getkeypress
    function [ml_scancode,ml_rt,ml_trialtime] = getkeypress(maxtime)
        ml_t1 = trialtime(); ml_t2 = 0;
        kbdflush;
        ml_scancode = [];
        ml_rt = NaN;
        ml_trialtime = ml_t1;
        while ml_t2 < maxtime
            ml_scancode = kbdgetkey;
            ml_trialtime = trialtime();
            ml_t2 = ml_trialtime - ml_t1;
            if ~isempty(ml_scancode), ml_rt = ml_t2; break, end
        end
    end

    %% function hotkey
    ML_SCAN_LETTERS = '`1234567890-=qwertyuiop[]\asdfghjkl;''zxcvbnm,./';
    ML_SCAN_CODES = [41 2:13 16:27 43 30:40 44:53];
    ML_KeyNumbers = [];
    ML_KeyCallbacks = {};
    function hotkey(keyval, varargin)
        if isnumeric(keyval)
            if TrialRecord.HotkeyLocked && 88~=keyval, return, end
            ml_ = find(ML_KeyNumbers == keyval,1);
            if ~isempty(ml_), eval(ML_KeyCallbacks{ml_}); end
            return
        end

        if 1 < length(keyval)
            switch lower(keyval)
                case 'esc', ml_keynum = 1;
                case 'rarr', ml_keynum = 205;
                case 'larr', ml_keynum = 203;
                case 'uarr', ml_keynum = 200;
                case 'darr', ml_keynum = 208;
                case 'numrarr', ml_keynum = 77;
                case 'numlarr', ml_keynum = 75;
                case 'numuarr', ml_keynum = 72;
                case 'numdarr', ml_keynum = 80;
                case 'space', ml_keynum = 57;
                case 'bksp', ml_keynum = 14;
                case {'f1','f2','f3','f4','f5','f6','f7','f8','f9','f10'}, ml_keynum = 58 + str2double(keyval(2:end));
                case 'f11', ml_keynum = 87;
                case 'f12', ml_keynum = 88;
                otherwise, error('Must specify only one letter, number, or symbol on each call to "hotkey" unless specifying a function key such as "F3"');
            end
        else
            ml_keynum = ML_SCAN_CODES(ML_SCAN_LETTERS == lower(keyval));
        end
        if isempty(varargin) || isempty(varargin{1}), fprintf('Warning: No function declared for HotKey "%s"\n', keyval); return, end

        ml_ = find(ML_KeyNumbers == ml_keynum,1);
        if isempty(ml_)
            ML_KeyNumbers(end+1) = ml_keynum;
            ML_KeyCallbacks{end+1} = varargin{1};
        else
            ML_KeyCallbacks{ml_} = varargin{1};
        end
    end

    %% function reposition_object
    function ml_success = reposition_object(stimnum, xydeg, ydeg)
        if 2<nargin, xydeg = [xydeg(:) ydeg(:)]; end
        TaskObject.Position(stimnum,:) = xydeg;
        ml_success = true;
    end

    %% function rescale_object
    function rescale_object(stimnum, scale)
        if numel(stimnum)==numel(scale), scale = repmat(scale(:),1,2); end
        TaskObject.Scale(stimnum) = scale;
    end

    %% function rotate_object
    function rotate_object(stimnum, angle), TaskObject.Angle(stimnum) = angle; end

    %% function set_bgcolor(bgcolor)
    function set_bgcolor(bgcolor)
        if ~exist('bgcolor','var'), bgcolor = []; end
        Screen.BackgroundColor = fi(isempty(bgcolor),MLConfig.SubjectScreenBackground,bgcolor);
    end

    %% function idle
    ML_IdleTimeCounter = TimeCounter(null_);
    ML_IdleScene = create_scene(ML_IdleTimeCounter);
    ML_IdleDuration = find(strcmp(ML_IdleScene.AdapterArgs{2}(:,1),'Duration'));
    function idle(duration, bgcolor, event)
        switch nargin
            case 1, bgcolor = []; event = [];
            case 2, event = [];
            case 3, event = event(:)';
        end
        if ~isempty(bgcolor), ml_prev_color = Screen.BackgroundColor; Screen.BackgroundColor = bgcolor; end
        ML_IdleTimeCounter.Duration = duration;
        ML_IdleScene.AdapterArgs{2}{ML_IdleDuration,2} = duration;
        run_scene(ML_IdleScene,event);
        if ~isempty(bgcolor), Screen.BackgroundColor = ml_prev_color; end
    end

    %% function set_iti
    function set_iti(t), TrialRecord.InterTrialInterval = t; end

    %% functon showcursor
    function showcursor(cflag)
        if ischar(cflag), ml_state = strcmpi(cflag,'on'); else, ml_state = logical(cflag); end
        param_.Cursor.ShowJoy = [ml_state param_.Cursor.ShowJoy(1)|ml_state];
    end

    %% functon showcursor2
    function showcursor2(cflag)
        if ischar(cflag), ml_state = strcmpi(cflag,'on'); else, ml_state = logical(cflag); end
        param_.Cursor.ShowJoy2 = [ml_state param_.Cursor.ShowJoy2(1)|ml_state];
    end

    %% functon showtouch
    function showtouch(cflag)
        if ischar(cflag), ml_state = strcmpi(cflag,'on'); else, ml_state = logical(cflag); end
        param_.Cursor.ShowTouch = [ml_state param_.Cursor.ShowTouch(1)|ml_state];
    end

    %% function bhv_variable
    function bhv_variable(varargin)
        if 0==nargin || 0~=mod(nargin,2), error('bhv_variable requires all arguments to come in name/value pairs'); end
        ml_varname = varargin(1:2:end);
        ml_value = varargin(2:2:end)';
        for ml_=1:length(ml_varname), TrialData.UserVars.(ml_varname{ml_}) = ml_value{ml_}; end
    end

    %% function escape_screen
    mglactivategraphic(Screen.EscapeRequested,TrialRecord.Pause);
    function escape_screen()
        TrialRecord.Pause = true;
        mglactivategraphic(Screen.EscapeRequested,TrialRecord.Pause);
    end

    %% function user_text
    ML_MessageCount = 0;
    function user_text(varargin)
        varargin{1} = sprintf('Trial %d: %s',TrialRecord.CurrentTrialNumber,varargin{1});
        ML_MessageCount = ML_MessageCount + 1;
        TrialData.UserMessage{ML_MessageCount} = [varargin,'i'];
    end

    %% function user_warning
    function user_warning(varargin)
        varargin{1} = sprintf('Trial %d: %s',TrialRecord.CurrentTrialNumber,varargin{1});
        ML_MessageCount = ML_MessageCount + 1;
        TrialData.UserMessage{ML_MessageCount} = [varargin,'e'];
    end

    %% function dashboard
    function dashboard(n,text,varargin)
        n = min(length(Screen.Dashboard),max(1,n));
        mglsetproperty(Screen.Dashboard(n),'text',text);
        if nargin<3, return, end
        if ~ischar(varargin{1}), mglsetproperty(Screen.Dashboard(n),'color',varargin{:}); else, mglsetproperty(Screen.Dashboard(n),varargin{:}); end
    end

    %% function rewind_object
    function rewind_object(stimnum,time_in_msec)
        if ~exist('time_in_msec','var'), time_in_msec = 0; end
        mglsetproperty(TaskObject.ID(stimnum),'seek',time_in_msec/1000);
    end

    %% function get_object_duration
    ML_ObjectDuration = NaN(1,ML_nObject); for ML_=1:ML_nObject, if isfield(TaskObject.MoreInfo(ML_),'Duration'), ML_ObjectDuration(ML_) = TaskObject.MoreInfo(ML_).Duration; end, end
    function [duration_in_msec,duration_in_frames] = get_object_duration(stimnum)
        duration_in_msec = ML_ObjectDuration(stimnum) * 1000;
        duration_in_frames = ceil(ML_ObjectDuration(stimnum) * Screen.RefreshRate);
    end
    
    %% deprecated: function rewind_movie
    function rewind_movie(stimnum,time_in_msec)
        if ~exist('stimnum','var'), stimnum = find(2==TaskObject.Modality); end
        if ~exist('time_in_msec','var'), time_in_msec = 0; end
        rewind_object(stimnum,time_in_msec);
    end

    %% deprecated: function rewind_sound
    function rewind_sound(stimnum,time_in_msec)
        if ~exist('stimnum','var'), stimnum = find(3==TaskObject.Modality); end
        if ~exist('time_in_msec','var'), time_in_msec = 0; end
        rewind_object(stimnum,time_in_msec);
    end

    %% deprecated: function get_movie_duration
    function [duration_in_msec,duration_in_frames] = get_movie_duration(stimnum)
        if ~exist('stimnum','var'), stimnum = find(2==TaskObject.Modality); end
        [duration_in_msec,duration_in_frames] = get_object_duration(stimnum);
    end

    %% deprecated: function get_sound_duration
    function duration_in_msec = get_sound_duration(stimnum)
        if ~exist('stimnum','var'), stimnum = find(3==TaskObject.Modality); end
        duration_in_msec = get_object_duration(stimnum);
    end

    %% function pause
    function pause(sec), a = tic; while toc(a)<sec; end, end

    %% function fi
    function op = fi(tf,op1,op2), if tf, op = op1; else, op = op2; end, end

    %% function bhv_code
    function bhv_code(varargin)
        if 1 < TrialRecord.CurrentTrialNumber, return, end
        if 0==nargin || 0~=mod(nargin,2), error('bhv_code requires all arguments to come in code/name pairs'); end
        ml_code = [varargin{1:2:end}]';
        ml_codename = varargin(2:2:end)';
        [ml_a,ml_b] = ismember(ml_code,TrialRecord.TaskInfo.BehavioralCodes.CodeNumbers);
        if any(ml_a)
            ml_c = find(~strcmp(ml_codename(ml_a),TrialRecord.TaskInfo.BehavioralCodes.CodeNames(ml_b(ml_a))),1);
            if ~isempty(ml_c), ml_d = find(ml_a); error('Code #%d already exists.',ml_code(ml_d(ml_c))); end
        end
        TrialRecord.TaskInfo.BehavioralCodes.CodeNumbers = [TrialRecord.TaskInfo.BehavioralCodes.CodeNumbers; ml_code(~ml_a)];
        TrialRecord.TaskInfo.BehavioralCodes.CodeNames = [TrialRecord.TaskInfo.BehavioralCodes.CodeNames; ml_codename(~ml_a)];
    end

    %% function end_trial
    function end_trial()
        if TrialRecord.TestTrial, ml_code = []; else, ml_code = 18; end
        mglwait4vblank(true); mglwait4vblank(false); mdqmex(9,3,ml_code);
        TrialRecord.InterTrialIntervalTimer = tic;
        
        % turn off the photodiode trigger so that it becomes black when the next trial begins.
        if param_.PhotoDiodeStatus && 1 < MLConfig.PhotoDiodeTrigger
            if 0==param_.scene_frame(), mglrendergraphic(param_.FrameNum,1,true); end
            mglpresent(1);
            mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[false true]);
            mglrendergraphic(param_.FrameNum,1,false);
            mglpresent(1);
        end

        if TrialRecord.TestTrial, stop(DAQ); return, end
        
        TrialData.AnalogData.SampleInterval = param_.SampleInterval;
        TrialData.WebcamExportAs = MLConfig.WebcamExportAs;
        if MLConfig.NonStopRecording
            backmarker(DAQ);
            ML_trialtime_offset = toc(ML_global_timer);
            ML_Clock = clock;
            lsl_pull_chunk(DAQ);
            getback(DAQ);
            
            if SIMULATION_MODE
                if ~isempty(DAQ.Mouse)
                    TrialData.AnalogData.Eye = EyeCal.control2deg(DAQ.Mouse);
                    TrialData.AnalogData.Touch = repmat(TrialData.AnalogData.Eye,1,2);
                    TrialData.AnalogData.Touch(~DAQ.MouseButton(:,1),1:2) = NaN;
                    TrialData.AnalogData.Touch(~DAQ.MouseButton(:,2),3:4) = NaN;
                    TrialData.AnalogData.Mouse = [TrialData.AnalogData.Eye DAQ.MouseButton];
                    TrialData.AnalogData.KeyInput = DAQ.KeyInput;
                end
            else
                if ~isempty(DAQ.Eye), TrialData.AnalogData.Eye = EyeCal.sig2deg(DAQ.Eye,param_.EyeOffset); end
                if ~isempty(DAQ.Eye2), TrialData.AnalogData.Eye2 = Eye2Cal.sig2deg(DAQ.Eye2,param_.Eye2Offset); end
                if ~isempty(DAQ.EyeExtra), TrialData.AnalogData.EyeExtra = DAQ.EyeExtra; end
                if ~isempty(DAQ.Joystick), TrialData.AnalogData.Joystick = JoyCal.sig2deg(DAQ.Joystick,param_.JoyOffset); end
                if ~isempty(DAQ.Joystick2), TrialData.AnalogData.Joystick2 = Joy2Cal.sig2deg(DAQ.Joystick2,param_.Joy2Offset); end
                if ~isempty(DAQ.Touch), TrialData.AnalogData.Touch = EyeCal.subject2deg(DAQ.Touch); end
                if ~isempty(DAQ.Mouse), TrialData.AnalogData.Mouse = [EyeCal.subject2deg(DAQ.Mouse) DAQ.MouseButton]; end
                if ~isempty(DAQ.KeyInput), TrialData.AnalogData.KeyInput = DAQ.KeyInput; end
                if ~isempty(DAQ.PhotoDiode), TrialData.AnalogData.PhotoDiode = DAQ.PhotoDiode; end
                for ml_=DAQ.buttons_available
                    if button_.Invert(ml_)
                        TrialData.AnalogData.Button.(sprintf('Btn%d',ml_)) = ~DAQ.Button{ml_};
                    else
                        TrialData.AnalogData.Button.(sprintf('Btn%d',ml_)) = DAQ.Button{ml_};
                    end
                end
            end
            for ml_=DAQ.general_available, TrialData.AnalogData.General.(sprintf('Gen%d',ml_)) = DAQ.General{ml_}; end
        else
            ml_MinSamplesExpected = ceil(trialtime());
            ml_SamplePoint = 1:param_.SampleInterval:ml_MinSamplesExpected;
            while DAQ.MinSamplesAvailable <= ml_MinSamplesExpected, end
            lsl_pull_chunk(DAQ);
            stop(DAQ);
            getdata(DAQ);
            
            if SIMULATION_MODE
                if ~isempty(DAQ.Mouse)
                    TrialData.AnalogData.Eye = EyeCal.control2deg(DAQ.Mouse(ml_SamplePoint,:));
                    TrialData.AnalogData.Touch = repmat(TrialData.AnalogData.Eye,1,2);
                    TrialData.AnalogData.Touch(~DAQ.MouseButton(ml_SamplePoint,1),1:2) = NaN;
                    TrialData.AnalogData.Touch(~DAQ.MouseButton(ml_SamplePoint,2),3:4) = NaN;
                    TrialData.AnalogData.Mouse = [TrialData.AnalogData.Eye DAQ.MouseButton(ml_SamplePoint,:)];
                    if ~isempty(DAQ.KeyInput), TrialData.AnalogData.KeyInput = DAQ.KeyInput(ml_SamplePoint,:); end
                end
            else
                if ~isempty(DAQ.Eye), TrialData.AnalogData.Eye = EyeCal.sig2deg(DAQ.Eye(ml_SamplePoint,:),param_.EyeOffset); end
                if ~isempty(DAQ.Eye2), TrialData.AnalogData.Eye2 = Eye2Cal.sig2deg(DAQ.Eye2(ml_SamplePoint,:),param_.Eye2Offset); end
                if ~isempty(DAQ.EyeExtra), TrialData.AnalogData.EyeExtra = DAQ.EyeExtra(ml_SamplePoint,:); end
                if ~isempty(DAQ.Joystick), TrialData.AnalogData.Joystick = JoyCal.sig2deg(DAQ.Joystick(ml_SamplePoint,:),param_.JoyOffset); end
                if ~isempty(DAQ.Joystick2), TrialData.AnalogData.Joystick2 = Joy2Cal.sig2deg(DAQ.Joystick2(ml_SamplePoint,:),param_.Joy2Offset); end
                if ~isempty(DAQ.Touch), TrialData.AnalogData.Touch = EyeCal.subject2deg(DAQ.Touch(ml_SamplePoint,:)); end
                if ~isempty(DAQ.Mouse), TrialData.AnalogData.Mouse = [EyeCal.subject2deg(DAQ.Mouse(ml_SamplePoint,:)) DAQ.MouseButton(ml_SamplePoint,:)]; end
                if ~isempty(DAQ.KeyInput), TrialData.AnalogData.KeyInput = DAQ.KeyInput(ml_SamplePoint,:); end
                if ~isempty(DAQ.PhotoDiode), TrialData.AnalogData.PhotoDiode = DAQ.PhotoDiode(ml_SamplePoint,:); end
                for ml_=DAQ.buttons_available
                    if button_.Invert(ml_)
                        TrialData.AnalogData.Button.(sprintf('Btn%d',ml_)) = ~DAQ.Button{ml_}(ml_SamplePoint,:);
                    else
                        TrialData.AnalogData.Button.(sprintf('Btn%d',ml_)) = DAQ.Button{ml_}(ml_SamplePoint,:);
                    end
                end
            end
            for ml_=DAQ.general_available, TrialData.AnalogData.General.(sprintf('Gen%d',ml_)) = DAQ.General{ml_}(ml_SamplePoint,:); end
        end
        if ~isempty(DAQ.Voice), TrialData.Voice = interp1(DAQ.Voice,(1:DAQ.VoiceInfo.SampleRate/MLConfig.VoiceRecording.SampleRate:size(DAQ.Voice,1))'); end
        for ml_=DAQ.highfrequency_available, TrialData.HighFrequency.(sprintf('HighFrequency%d',ml_)) = DAQ.HighFrequency{ml_}; end
        for ml_=DAQ.nWebcam:-1:1
            if ~isempty(DAQ.Webcam{ml_})
                if isempty(TrialData.Webcam), TrialData.Webcam = struct('Format','','Size',[],'Time',[],'Frame',uint16([]),'VerticalFlip',[]); end
                TrialData.Webcam(ml_) = getdata(DAQ.Webcam{ml_});
                TrialData.Webcam(ml_).Time = (TrialData.Webcam(ml_).Time + DAQ.WebcamOffset(ml_)) * 1000 - TrialData.AbsoluteTrialStartTime;
            end
        end
        for ml_=1:DAQ.nLSL
            chunk = vertcat(DAQ.LSLchunk{:,ml_});
            if isempty(chunk), continue, end
            chunk(:,1) = chunk(:,1)*1000 - TrialData.AbsoluteTrialStartTime;
            TrialData.AnalogData.LSL.(sprintf('LSL%d',ml_)) = chunk;
        end
        lsl_clear_chunk(DAQ);
        
        % eye & joy traces
        if MLConfig.SummarySceneDuringITI
            [object_id,~,object_status] = mglgetallobjects();
            mglactivategraphic(TaskObject.ID,ML_GraphicsUsedInThisTrial);

            if ~isempty(TrialData.AnalogData.Eye)
                ml_eye = EyeCal.deg2pix(TrialData.AnalogData.Eye);
                ml_eye_trace = mgladdline(MLConfig.EyeTracerColor(1,:),size(ml_eye,1),1,10);
                mglsetproperty(ml_eye_trace,'addpoint',ml_eye);
            end
            if ~isempty(TrialData.AnalogData.Eye2)
                ml_eye2 = Eye2Cal.deg2pix(TrialData.AnalogData.Eye2);
                ml_eye2_trace = mgladdline(MLConfig.EyeTracerColor(2,:),size(ml_eye2,1),1,10);
                mglsetproperty(ml_eye2_trace,'addpoint',ml_eye2);
            end
            if ~isempty(TrialData.AnalogData.Joystick)
                ml_joy = JoyCal.deg2pix(TrialData.AnalogData.Joystick);
                ml_joy_trace = mgladdline(MLConfig.JoystickCursorColor(1,:),size(ml_joy,1),1,10);
                mglsetproperty(ml_joy_trace,'addpoint',ml_joy);
            end
            if ~isempty(TrialData.AnalogData.Joystick2)
                ml_joy2 = Joy2Cal.deg2pix(TrialData.AnalogData.Joystick2);
                ml_joy2_trace = mgladdline(MLConfig.JoystickCursorColor(2,:),size(ml_joy2,1),1,10);
                mglsetproperty(ml_joy2_trace,'addpoint',ml_joy2);
            end
            if ~isempty(TrialData.AnalogData.Touch)
                ml_touch = reshape(TrialData.AnalogData.Touch',2,[])';
                ml_touch = EyeCal.deg2pix(ml_touch(~any(isnan(ml_touch),2),:));
                ml_ntouch = min(size(ml_touch,1),500);
                ml_touch = ml_touch(round(linspace(1,size(ml_touch,1),ml_ntouch)),:);
                ml_touch_trace = NaN(1,ml_ntouch);
                ml_imdata = load_cursor(MLConfig.TouchCursorImage,MLConfig.TouchCursorShape,MLConfig.TouchCursorColor,MLConfig.TouchCursorSize);
                for ml_=1:ml_ntouch, ml_touch_trace(ml_) = mgladdbitmap(ml_imdata,10); end
                mglsetorigin(ml_touch_trace,ml_touch);
            end
        end
        
        % eye drift correction
        if 0<MLConfig.EyeAutoDriftCorrection
            if all(0==param_.EyeOffset) && 0 < param_.EyeTargetIndex && ~isempty(TrialData.AnalogData.Eye)
                try
                    ML_EyeTargetRecord = param_.EyeTargetRecord(1:param_.EyeTargetIndex,:);
                    ML_EyeTargetRecord(:,3) = ceil(ML_EyeTargetRecord(:,3) ./ param_.SampleInterval);
                    ML_EyeTargetRecord(:,4) = ML_EyeTargetRecord(:,3) + floor(ML_EyeTargetRecord(:,4) ./ param_.SampleInterval) - 1;
                    ml_npoint = size(ML_EyeTargetRecord,1);
                    ml_new_fix_point = zeros(ml_npoint,2);
                    for ml_ = 1:ml_npoint, ml_new_fix_point(ml_,:) = median(TrialData.AnalogData.Eye(ML_EyeTargetRecord(ml_,3):ML_EyeTargetRecord(ml_,4),:),1); end
                    param_.EyeOffset = mean(ml_new_fix_point - ML_EyeTargetRecord(:,1:2),1) * EyeCal.rotation_rev_t .* (MLConfig.EyeAutoDriftCorrection / 100);

                    if MLConfig.SummarySceneDuringITI
                        ML_EyeTargetRecord(:,1:2) = EyeCal.deg2pix(ML_EyeTargetRecord(:,1:2));
                        ml_new_fix_point = EyeCal.deg2pix(ml_new_fix_point);
                        ml_size = 0.3 * MLConfig.PixelsPerDegree(1);
                        for ml_ = 1:ml_npoint
                            ml_id = mgladdcircle(repmat(MLConfig.FixationPointColor,2,1),ml_size,10); mglsetorigin(ml_id,ML_EyeTargetRecord(ml_,1:2));
                            ml_id = mgladdcircle(repmat(MLConfig.EyeTracerColor(1,:),2,1),ml_size,10); mglsetorigin(ml_id,ml_new_fix_point(ml_,:));
                        end
                    end
                catch
                    warning('Eye #1 Auto drift correction failed!!!');
                end
            end
            if all(0==param_.Eye2Offset) && 0 < param_.Eye2TargetIndex && ~isempty(TrialData.AnalogData.Eye2)
                try
                    ML_Eye2TargetRecord = param_.Eye2TargetRecord(1:param_.Eye2TargetIndex,:);
                    ML_Eye2TargetRecord(:,3) = ceil(ML_Eye2TargetRecord(:,3) ./ param_.SampleInterval);
                    ML_Eye2TargetRecord(:,4) = ML_Eye2TargetRecord(:,3) + floor(ML_Eye2TargetRecord(:,4) ./ param_.SampleInterval) - 1;
                    ml_npoint = size(ML_Eye2TargetRecord,1);
                    ml_new_fix_point = zeros(ml_npoint,2);
                    for ml_ = 1:ml_npoint
                        ml_new_fix_point(ml_,:) = median(TrialData.AnalogData.Eye2(ML_Eye2TargetRecord(ml_,3):ML_Eye2TargetRecord(ml_,4),:),1);
                    end
                    param_.Eye2Offset = mean(ml_new_fix_point - ML_Eye2TargetRecord(:,1:2),1) * Eye2Cal.rotation_rev_t .* (MLConfig.EyeAutoDriftCorrection / 100);

                    if MLConfig.SummarySceneDuringITI
                        ML_Eye2TargetRecord(:,1:2) = Eye2Cal.deg2pix(ML_Eye2TargetRecord(:,1:2));
                        ml_new_fix_point = Eye2Cal.deg2pix(ml_new_fix_point);
                        ml_size = 0.3 * MLConfig.PixelsPerDegree(1);
                        for ml_ = 1:ml_npoint
                            ml_id = mgladdcircle(repmat(MLConfig.FixationPointColor,2,1),ml_size,10); mglsetorigin(ml_id,ML_Eye2TargetRecord(ml_,1:2));
                            ml_id = mgladdcircle(repmat(MLConfig.EyeTracerColor(2,:),2,1),ml_size,10); mglsetorigin(ml_id,ml_new_fix_point(ml_,:));
                        end
                    end
                catch
                    warning('Eye #2 Auto drift correction failed!!!');
                end
            end
        end
        mglpresent(2);  % keep the last frame in the backbuffer
        mglsetscreencolor(2,fi(MLConfig.NonStopRecording,[0.0667 0.1666 0.2745],[0.25 0.25 0.25]));
        mdqmex(1,108);  % ClearControlScreenEdge
        mglrendergraphic(param_.FrameNum,2,false);
        mglpresent(2);
        if MLConfig.SummarySceneDuringITI, mgldestroygraphic(mlsetdiff(mglgetallobjects,object_id)); mglactivategraphic(object_id,object_status); end
        
        % update EyeTransform
        if any(param_.EyeOffset), EyeCal.translate(param_.EyeOffset); end
        if any(param_.Eye2Offset), Eye2Cal.translate(param_.Eye2Offset); end
        
        [TrialData.BehavioralCodes.CodeTimes,TrialData.BehavioralCodes.CodeNumbers] = mdqmex(42,2);
        TrialData.ReactionTime = rt;
        TrialData.ObjectStatusRecord.SceneParam = ML_ObjectStatusRecord.SceneParam(1:ML_SceneCount);
        [TrialData.RewardRecord.StartTimes,TrialData.RewardRecord.EndTimes] = mdqmex(43,4);
        TrialData.CycleRate = [ML_MaxFrameInterval ML_MaxDrawingTime];
        TrialData.NewEyeTransform = EyeCal.get_transform_matrix();
        TrialData.NewEye2Transform = Eye2Cal.get_transform_matrix();
        TrialData.VariableChanges.EyeOffset = param_.EyeOffset;
        TrialData.VariableChanges.Eye2Offset = param_.Eye2Offset;
        TrialData.VariableChanges.reward_dur = reward_dur;
        TrialData.UserVars.SkippedFrameTimeInfo = ML_SkippedFrameTimeInfo;
        TrialData.TaskObject.CurrentConditionInfo = TrialRecord.CurrentConditionInfo;
        TrialData.Ver = 4;
        
        ml_ = unique([TrialData.ObjectStatusRecord.SceneParam.Visual TrialData.ObjectStatusRecord.SceneParam.Sound TrialData.ObjectStatusRecord.SceneParam.STM TrialData.ObjectStatusRecord.SceneParam.TTL]);
        ml_used = TaskObject.MoreInfo(ml_).Filename;
        TrialRecord.TaskInfo.Stimuli = unique([TrialRecord.TaskInfo.Stimuli ml_used param_.StimulusFile]);
        if 0<ML_TotalSkippedFrames, user_warning('%d skipped frame(s) occurred', ML_TotalSkippedFrames); end
    end

    %% function forced_eye_drift_correction
    function forced_eye_drift_correction(origin,devnum)
        if ~exist('devnum','var'), devnum = 1; end
        switch devnum
            case 1, ml_eye = eye_position();
            otherwise, ml_eye = eye2_position();
        end
        if isempty(origin)
            ml_pos = TaskObject.Position((1==TaskObject.Modality | 2==TaskObject.Modality) & TaskObject.Status,:);
            switch size(ml_pos,1)
                case 0, origin = [0 0];
                case 1, origin = ml_pos;
                otherwise, [~,ml_]= min(sum((ml_pos - repmat(ml_eye,size(ml_pos,1),1)).^2,2)); origin = ml_pos(ml_,:);
            end
        end
        switch devnum
            case 1
                ML_prev_eye_position(end+1,:) = (ml_eye - origin) * EyeCal.rotation_rev_t;
                param_.EyeOffset = param_.EyeOffset + ML_prev_eye_position(end,:);
            otherwise
                ML_prev_eye2_position(end+1,:) = (ml_eye - origin) * Eye2Cal.rotation_rev_t;
                param_.Eye2Offset = param_.Eye2Offset + ML_prev_eye2_position(end,:);
        end
    end


%% Task
hotkey('esc', 'escape_screen;');   % early escape
hotkey('r', 'goodmonkey(reward_dur,''juiceline'',MLConfig.RewardFuncArgs.JuiceLine,''eventmarker'',14,''nonblocking'',1);');  % reward
hotkey('-', 'reward_dur = max(0,reward_dur-10); mglactivategraphic(Screen.RewardDuration,true); mglsetproperty(Screen.RewardDuration,''text'',sprintf(''JuiceLine: %s, reward_dur: %.0f'',num2str(MLConfig.RewardFuncArgs.JuiceLine),reward_dur));');
hotkey('=', 'reward_dur = reward_dur + 10; mglactivategraphic(Screen.RewardDuration,true); mglsetproperty(Screen.RewardDuration,''text'',sprintf(''JuiceLine: %s, reward_dur: %.0f'',num2str(MLConfig.RewardFuncArgs.JuiceLine),reward_dur));');
if SIMULATION_MODE
    hotkey('l', 'DAQ.simulated_input(3,1,1);');  % eye2 right left up down
    hotkey('j', 'DAQ.simulated_input(3,1,-1);');
    hotkey('i', 'DAQ.simulated_input(3,2,1);');
    hotkey('k', 'DAQ.simulated_input(3,2,-1);');
    hotkey('rarr', 'DAQ.simulated_input(1,1,1);');  % joystick right left up down
    hotkey('larr', 'DAQ.simulated_input(1,1,-1);');
    hotkey('uarr', 'DAQ.simulated_input(1,2,1);');
    hotkey('darr', 'DAQ.simulated_input(1,2,-1);');
    hotkey('d', 'DAQ.simulated_input(2,1,1);');  % joystick2 right left up down
    hotkey('a', 'DAQ.simulated_input(2,1,-1);');
    hotkey('w', 'DAQ.simulated_input(2,2,1);');
    hotkey('s', 'DAQ.simulated_input(2,2,-1);');
else
    hotkey('c', 'forced_eye_drift_correction([0 0],1);');  % adjust eye offset
    hotkey('u', 'if ~isempty(ML_prev_eye_position), param_.EyeOffset = param_.EyeOffset - ML_prev_eye_position(end,:); ML_prev_eye_position(end,:) = []; end');
    hotkey('v', 'forced_eye_drift_correction([0 0],2);');  % adjust eye2 offset
    hotkey('i', 'if ~isempty(ML_prev_eye2_position), param_.Eye2Offset = param_.Eye2Offset - ML_prev_eye2_position(end,:); ML_prev_eye2_position(end,:) = []; end');
    hotkey('f12', 'TrialRecord.HotkeyLocked = ~TrialRecord.HotkeyLocked; mglactivategraphic(Screen.HotkeyLocked,TrialRecord.HotkeyLocked);');  % hotkey lock
end

kbdflush;
rt = NaN;

    function warming_up()
        ML_trialtime_offset = toc(ML_global_timer); DAQ.init_timer(ML_global_timer,ML_trialtime_offset);  % to make trialtime work during warming up
        mglgsave; mglpresentlock(true);
        ml_visual = find(1==TaskObject.Modality|2==TaskObject.Modality);
        for ml_=1:10
            calculate_cam_offset(DAQ); lsl_reset_clock(DAQ); lsl_pull_chunk(DAQ); lsl_clear_chunk(DAQ);
            ml_tc = TimeCounter(null_); ml_tc.Duration = 20; ml_s = create_scene(ml_tc,ml_visual); run_scene(ml_s);
        end
        mglpresentlock(false); mglgrestore;
        
        ml_g = [];
        try
            ml_g = mgladdbox([Screen.BackgroundColor; Screen.BackgroundColor],[100 100]);
            for ml_=1:10, mglactivategraphic(ml_g,1==mod(ml_,2)); mglrendergraphic; mglpresent; end
        catch
        end
        mgldestroygraphic(ml_g);
        
        ml_s = [];
        try
            ml_s = mgladdsound(zeros(480,1),48000);
            for ml_=1:10, mglplaysound(ml_s); while mglgetproperty(ml_s,'isplaying'), end, mglsetproperty(ml_s,'seek',0); end
        catch
        end
        mgldestroysound(ml_s);
        
        param_.PhotoDiodeStatus = false;
        if 1 < MLConfig.PhotoDiodeTrigger, mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[param_.PhotoDiodeStatus ~param_.PhotoDiodeStatus]); end
        ML_GraphicsUsedInThisTrial = false(1,ML_nObject);
        ML_SkippedFrameTimeInfo = [];
        ML_TotalSkippedFrames = 0;
        ML_SceneCount = 0;
        ML_MaxFrameInterval = 0;
        ML_MaxDrawingTime = 0;
    end

if ~isempty(TrialRecord.InterTrialIntervalTimer), while toc(TrialRecord.InterTrialIntervalTimer)*1000 < TrialRecord.InterTrialInterval, end, end
TrialRecord.InterTrialInterval = MLConfig.InterTrialInterval;

ML_VOICE = DAQ.get_device('voice');
if MLConfig.NonStopRecording
    if TrialRecord.CurrentTrialNumber < 2
        start(DAQ);
        warming_up();

        ml_timer = tic; while 0==DAQ.MinSamplesAvailable, if 5<toc(ml_timer), error('Data acquisition stopped.'); end, end
        if ~isempty(ML_VOICE), for ML_=1:3, ML_NUM = ML_VOICE.SamplesAvailable; while ML_VOICE.SamplesAvailable==ML_NUM, end, end, end
        flushmarker(DAQ);
        ML_trialtime_offset = toc(ML_global_timer);
        ML_Clock = clock;
        calculate_cam_offset(DAQ); lsl_reset_clock(DAQ); lsl_pull_chunk(DAQ); lsl_clear_chunk(DAQ);
        ML_global_timer_offset = ML_trialtime_offset;
        flushdata(DAQ);
    else
        ml_timer = tic; while 0==DAQ.MinSamplesAvailable, if 5<toc(ml_timer), error('Data acquisition stopped.'); end, end
    end
    TrialData.TrialDateTime = ML_Clock;
else
    start(DAQ);
    if TrialRecord.CurrentTrialNumber < 2, warming_up(); end

    ml_timer = tic; while 0==DAQ.MinSamplesAvailable, if 5<toc(ml_timer), error('Data acquisition stopped.'); end, end
    if ~isempty(ML_VOICE), for ML_=1:3, ML_NUM = ML_VOICE.SamplesAvailable; while ML_VOICE.SamplesAvailable==ML_NUM, end, end, end
    flushmarker(DAQ);
    ML_trialtime_offset = toc(ML_global_timer);
    TrialData.TrialDateTime = clock;
    if TrialRecord.CurrentTrialNumber < 2, calculate_cam_offset(DAQ); lsl_reset_clock(DAQ); ML_global_timer_offset = ML_trialtime_offset; end
    lsl_pull_chunk(DAQ); lsl_clear_chunk(DAQ);
    flushdata(DAQ);
end
TrialData.AbsoluteTrialStartTime = (ML_trialtime_offset - ML_global_timer_offset) * 1000;
DAQ.init_timer(ML_global_timer,ML_trialtime_offset);
mglsetscreencolor(2,[0.1333 0.3333 0.5490]);

if ~TrialRecord.TestTrial, eventmarker(9); end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%BEGINNING OF TIMING CODE**************************************************
%END OF TIMING CODE********************************************************
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end_trial();

end  % end of trialholder()
