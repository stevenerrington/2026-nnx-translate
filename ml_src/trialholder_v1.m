function varargout = trialholder(MLConfig,TrialRecord,TaskObject,TrialData)

% initialization
global ML_global_timer ML_global_timer_offset ML_prev_eye_position ML_prev_eye2_position ML_trialtime_offset ML_Clock
if isempty(ML_global_timer), ML_global_timer = tic; ML_trialtime_offset = toc(ML_global_timer); end
varargout{1} = [];

DAQ = MLConfig.DAQ;
Screen = MLConfig.Screen;
SIMULATION_MODE = TrialRecord.SimulationMode;
if SIMULATION_MODE, DAQ.add_mouse(); DAQ.init_simulated_devices(); end
ML_SampleInterval = 1000 / MLConfig.AISampleRate;

% write the Info field from the conditions file if it exists in TrialRecord
Info = TrialRecord.CurrentConditionInfo;
StimulusInfo = TrialRecord.CurrentConditionStimulusInfo;

% calibration function provider
EyeCal = mlcalibrate('eye',MLConfig,1);
Eye2Cal = mlcalibrate('eye',MLConfig,2);
JoyCal = mlcalibrate('joy',MLConfig,1);
Joy2Cal = mlcalibrate('joy',MLConfig,2);

% TaskObject variables
ML_nObject = length(TaskObject);

ML_Visual = 1==TaskObject.Modality | 2==TaskObject.Modality;
ML_Visual_InitialFrame = NaN(1,ML_nObject);
ML_Visual_PositionArray = cell(1,ML_nObject);
ML_Visual_StartPosition = ones(1,ML_nObject);
ML_Visual_PositionStep = ones(1,ML_nObject);
ML_Visual_nPosition = zeros(1,ML_nObject);

ML_Movie = 2==TaskObject.Modality;
ML_Movie_FrameByFrame = false(1,ML_nObject); ML_Movie_FrameByFrame(ML_Movie) = TaskObject.MoreInfo(ML_Movie).FrameByFrame;
ML_Movie_StartTime = zeros(1,ML_nObject);
ML_Movie_StartFrame = ones(1,ML_nObject);
ML_Movie_FrameStep = ones(1,ML_nObject);
ML_Movie_nFrame = zeros(1,ML_nObject); ML_Movie_nFrame(ML_Movie) = TaskObject.MoreInfo(ML_Movie).TotalFrames;
ML_Movie_FrameOrderArray = cell(1,ML_nObject);
ML_Movie_nFrameOrder = zeros(1,ML_nObject);
ML_Movie_FrameEventArray = cell(1,ML_nObject);
ML_Movie_nFrameEvent = zeros(1,ML_nObject);

ML_Sound = 3==TaskObject.Modality;
ML_Stimulation = 4==TaskObject.Modality;
ML_TTL = 5==TaskObject.Modality;
ML_IO_Channel = NaN(1,ML_nObject); for ML_=1:ML_nObject, if isfield(TaskObject.MoreInfo(ML_),'Channel'), ML_IO_Channel(ML_) = TaskObject.MoreInfo(ML_).Channel; end, end
ML_ObjectDuration = NaN(1,ML_nObject); for ML_=1:ML_nObject, if isfield(TaskObject.MoreInfo(ML_),'Duration'), ML_ObjectDuration(ML_) = TaskObject.MoreInfo(ML_).Duration; end, end

% DAQ variable cache
ML_eyepresent = SIMULATION_MODE | DAQ.eye_present;
ML_eye2present = SIMULATION_MODE | DAQ.eye2_present;
ML_joypresent = SIMULATION_MODE | DAQ.joystick_present;
ML_joy2present = SIMULATION_MODE | DAQ.joystick2_present;
ML_buttonpresent = SIMULATION_MODE | DAQ.button_present;
ML_touchpresent = SIMULATION_MODE | DAQ.touch_present;
ML_ButtonsAvailable = fi(SIMULATION_MODE,1:10,DAQ.buttons_available);
if DAQ.mouse_present, ML_Mouse = DAQ.get_device('mouse'); else, ML_Mouse = pointingdevice; end

% prepare tracers
ML_PdStatus = false;
if 1 < MLConfig.PhotoDiodeTrigger, mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[ML_PdStatus ~ML_PdStatus]); end
mglactivategraphic(Screen.EyeTracer,ML_eyepresent); mglsetproperty(Screen.EyeTracer,'clear');
mglactivategraphic(Screen.Eye2Tracer,ML_eye2present); mglsetproperty(Screen.Eye2Tracer,'clear');
mglactivategraphic(Screen.ButtonLabel(ML_ButtonsAvailable),true);
mglactivategraphic(Screen.Dashboard,true);
mglactivategraphic([Screen.Reward Screen.RewardCount Screen.RewardDuration Screen.TTL(:)' Screen.Stimulation(:)'], false);

% eyejoytrack variables
ML_TimeFromLastPresent = zeros(1,8);
ML_SampleCycleStage = 0;
ML_SampleCycleTime = [];

% Benchmark variables
ML_Benchmark = false;
ML_BenchmarkSample = [];
ML_BenchmarkFrame = [];
ML_BenchmarkSampleCount = 0;
ML_BenchmarkFrameCount = 0;


    %% function trialtime
    function ml_t = trialtime(), ml_t = (toc(ML_global_timer) - ML_trialtime_offset) * 1000; end  % in milliseconds
 
    %% function toggleobject
    ML_RenderingState = 0;
    ML_CurrentFrameNumber = NaN;
    ML_LastPresentTime = 0;
    ML_eventcode = [];
    ML_extra_eventcode = [];
    ML_forced_new_scene = false;
    ML_scene_updated = false;
    ML_GraphicsUsedInThisTrial = false(1,ML_nObject);
    ML_ShowJoyCursor = [false ML_joypresent];
    ML_ShowJoy2Cursor = [false ML_joy2present];
    ML_ShowTouch = [false ML_touchpresent];
    ML_SkippedFrameTimeInfo = [];
    ML_TotalSkippedFrames = 0;
    ML_ToggleCount = 0;
    ML_ObjectStatusRecord.Time = {};
    ML_ObjectStatusRecord.Status = {};
    ML_ObjectStatusRecord.Position = {};
    ML_ObjectStatusRecord.Scale = {};
    ML_ObjectStatusRecord.Angle = {};
    ML_ObjectStatusRecord.Zorder = {};
    ML_ObjectStatusRecord.BackgroundColor = {};
    ML_ObjectStatusRecord.Info = struct;
    function ml_tflip = toggleobject(stimuli, varargin)
        ml_tflip = [];
       
        if isempty(stimuli)         % do nothing
            return
        elseif 0 < stimuli(1)       % new stimuli to turn on/off
            ml_new_scene = true;
            ML_RenderingState = 0;
        else                        % call from eyejoytrack
            ml_new_scene = false;
            if ML_forced_new_scene, ML_RenderingState = 0; end
        end

        ml_position_update = [];
        ml_frame_update = [];
        non_framebyframe = [];
        
        if 0==ML_RenderingState
            ML_eventcode = [];
            ML_scene_updated = ML_forced_new_scene;
            if TrialRecord.DiscardSkippedFrames || isnan(ML_CurrentFrameNumber), ML_CurrentFrameNumber = floor(trialtime()/Screen.FrameLength); else, ML_CurrentFrameNumber = ML_CurrentFrameNumber + 1; end
            
            if ml_new_scene
                ml_old_status = TaskObject.Status;

                % input arguments
                ml_stim2toggle = false(1,ML_nObject);
                ml_stim2toggle(stimuli) = true;
                ml_vis2toggle = ML_Visual & ml_stim2toggle;
                ml_mov2toggle = ML_Movie & ml_stim2toggle;

                ml_numargs = length(varargin);
                if mod(ml_numargs, 2), error('ToggleObject requires all arguments beyond the first to come in parameter/value pairs'); end
                ml_status_specified = false;
                for ml_ = 1:2:ml_numargs
                    ml_v = varargin{ml_};
                    ml_a = varargin{ml_+1};
                    switch lower(ml_v)
                        case 'eventmarker'
                            if ~isnumeric(ml_a), error('Value for <Toggleobject: EventMarker> must be numeric'); end
                            ML_eventcode = ml_a(:);
                        case 'status'
                            if ischar(ml_a), TaskObject.Status(ml_stim2toggle) = strcmpi(ml_a,'on'); else, TaskObject.Status(ml_stim2toggle) = logical(ml_a); end
                            ml_status_specified = true;
                        case 'moviestartframe'
                            if ~isnumeric(ml_a), error('Value for <Toggleobject: MovieStartFrame> must be numeric'); end
                            if any(ml_a<1), error('Value for <Toggleobject: MovieStartFrame> must be equal to or greater than 1'); end
                            if 1~=length(ml_a) && length(stimuli)~=length(ml_a), error('Number of values for <ToggleObject: MovieStartFrame> must be equal to the number of specified stimuli, or scalar'); end
                            ML_Movie_StartFrame(ml_mov2toggle) = ml_a;
                            ML_Movie_FrameByFrame(ml_mov2toggle) = true;
                            mglsetproperty(TaskObject.ID(ml_mov2toggle),'framebyframe');
                        case 'moviestep'
                            if ~isnumeric(ml_a), error('Value for <Toggleobject: MovieStep> must be numeric'); end
                            if 1~=length(ml_a) && length(stimuli)~=length(ml_a), error('Number of values for <ToggleObject: MovieStep> must be equal to the number of specified stimuli, or scalar'); end
                            ML_Movie_FrameStep(ml_mov2toggle) = ml_a;
                            ML_Movie_FrameByFrame(ml_mov2toggle) = true;
                            mglsetproperty(TaskObject.ID(ml_mov2toggle),'framebyframe');
                        case 'startposition'
                            if ~isnumeric(ml_a), error('Value for <Toggleobject: StartPosition> must be numeric'); end
                            if any(ml_a<1), error('Value for <Toggleobject: StartPosition> must be equal to or greater than 1'); end
                            if 1~=length(ml_a) && length(stimuli)~=length(ml_a), error('Number of values for <ToggleObject: StartPosition> must be equal to the number of specified stimuli, or scalar'); end
                            ML_Visual_StartPosition(ml_vis2toggle) = ml_a;
                        case 'positionstep'
                            if ~isnumeric(ml_a), error('Value for <Toggleobject: PositionStep> must be numeric'); end
                            if 1~=length(ml_a) && length(stimuli)~=length(ml_a), error('Number of values for <ToggleObject: PositionStep> must be equal to the number of specified stimuli, or scalar'); end
                            ML_Visual_PositionStep(ml_vis2toggle) = ml_a;
                        otherwise
                            error('Unrecognized option "%s" calling ToggleObject', ml_v);
                    end
                end
                if ~ml_status_specified, TaskObject.Status(ml_stim2toggle) = ~TaskObject.Status(ml_stim2toggle); end
                ml_ = ml_mov2toggle & 1==ML_Movie_StartFrame & ML_Movie_FrameStep < 0;
                if any(ml_), ML_Movie_StartFrame(ml_) = ML_Movie_nFrame(ml_); end
                ml_ = ml_vis2toggle & 1==ML_Visual_StartPosition & ML_Visual_PositionStep < 0;
                if any(ml_), ML_Visual_StartPosition(ml_) = ML_Visual_nPosition(ml_); end
                
                % set up stimuli
                ml_new_on = ~ml_old_status & TaskObject.Status;
                ml_new_off = ml_old_status & ~TaskObject.Status;
                
                ml_new_on_visual = ml_new_on & ML_Visual;
                if any(ml_new_on_visual)
                    ML_GraphicsUsedInThisTrial = ML_GraphicsUsedInThisTrial | ml_new_on_visual;
                    ML_scene_updated = true;
                    ML_Visual_InitialFrame(ml_new_on_visual) = ML_CurrentFrameNumber;
                    mglactivategraphic(TaskObject.ID(ml_new_on_visual),true);
                end
                ml_new_off_visual = ml_new_off & ML_Visual;
                if any(ml_new_off_visual)
                    ML_scene_updated = ML_scene_updated | any(~isnan(ML_Visual_InitialFrame(ml_new_off_visual)));
                    ML_Visual_InitialFrame(ml_new_off_visual) = NaN;
                    mglactivategraphic(TaskObject.ID(ml_new_off_visual),false);
                end
                
                ml_new_on_sound = ml_new_on & ML_Sound;
                if any(ml_new_on_sound), mglactivatesound(TaskObject.ID(ml_new_on_sound),true); end
                ml_new_off_sound = ml_new_off & ML_Sound;
                if any(ml_new_off_sound), mglstopsound(TaskObject.ID(ml_new_off_sound)); end
                
                ml_new_on_STM = ML_IO_Channel(ml_new_on & ML_Stimulation);
                if ~isempty(ml_new_on_STM)
                    ml_device = unique([DAQ.Stimulation{ml_new_on_STM}]); if ~isempty(ml_device), register(ml_device); end
                    mglactivategraphic(Screen.Stimulation(:,ml_new_on_STM),true);
                end
                ml_new_off_STM = ML_IO_Channel(ml_new_off & ML_Stimulation);
                if ~isempty(ml_new_off_STM)
                    ml_device = unique([DAQ.Stimulation{ml_new_off_STM}]);
                    for ml_= 1:length(ml_device)
                        if ml_device(ml_).RegenerationMode
                            stop(ml_device(ml_),24); if ~isrunning(ml_device(ml_)), start(ml_device(ml_)); end
                        else
                            stop(ml_device(ml_),22);
                        end
                    end
                    mglactivategraphic(Screen.Stimulation(:,ml_new_off_STM),false);
                end
                
                ml_new_on_TTL = ML_IO_Channel(ml_new_on & ML_TTL);
                if ~isempty(ml_new_on_TTL)
                    ml_device = [DAQ.TTL{ml_new_on_TTL}]; if ~isempty(ml_device), register(ml_device,'TTL',DAQ.TTLInvert(ml_new_on_TTL)); end
                    mglactivategraphic(Screen.TTL(:,ml_new_on_TTL),true);
                end
                ml_new_off_TTL = ML_IO_Channel(ml_new_off & ML_TTL);
                if ~isempty(ml_new_off_TTL)
                    for ml_=ml_new_off_TTL, putvalue(DAQ.TTL{ml_},DAQ.TTLInvert(ml_)); end
                    mglactivategraphic(Screen.TTL(:,ml_new_off_TTL),false);
                end
            end
            if ML_forced_new_scene, ml_new_scene = true; ML_forced_new_scene = false; end
            
            ml_elapsed_frame = ML_CurrentFrameNumber - ML_Visual_InitialFrame;

            % visual stimuli position change
            ml_position_update = TaskObject.Status & 0 < ML_Visual_nPosition;
            if any(ml_position_update)
                ml_position_index = mod(ML_Visual_StartPosition-1 + sign(ML_Visual_PositionStep) .* floor(ml_elapsed_frame .* abs(ML_Visual_PositionStep)),ML_Visual_nPosition) + 1;

                ML_scene_updated = true;
                for ml_=find(ml_position_update), TaskObject.Position(ml_,:) = ML_Visual_PositionArray{ml_}(ml_position_index(ml_),:); end
            end
            
            % movie update
            ml_movie_update = TaskObject.Status & ML_Movie;
            if any(ml_movie_update)
                ml_frame_update = ml_movie_update & ML_Movie_FrameByFrame;
                if any(ml_frame_update)
                    ml_frame_index = mod(ML_Movie_StartFrame-1 + sign(ML_Movie_FrameStep) .* floor(ml_elapsed_frame .* abs(ML_Movie_FrameStep)),ML_Movie_nFrame) + 1;

                    ml_frame_order = find(ml_frame_update & 0 < ML_Movie_nFrameOrder);
                    if ~isempty(ml_frame_order)
                        for ml_=ml_frame_order
                            if ml_frame_index(ml_) < ML_Movie_nFrameOrder(ml_), ml_frame_index(ml_) = ML_Movie_FrameOrderArray{ml_}(ml_frame_index(ml_)); end
                        end
                    end
                    ml_frame_event = find(ml_frame_update & 0 < ML_Movie_nFrameEvent);
                    if ~isempty(ml_frame_event)
                        for ml_=ml_frame_event
                            ml_idx = ML_Movie_FrameEventArray{ml_}(:,1)==ml_frame_index(ml_);
                            if any(ml_idx), ML_eventcode = [ML_eventcode; ML_Movie_FrameEventArray{ml_}(ml_idx,2)]; end %#ok<AGROW>
                        end
                    end
                    
                    ML_scene_updated = true;
                    for ml_=find(ml_frame_update), mglsetproperty(TaskObject.ID(ml_),'setnextframe',ml_frame_index(ml_)); end
                end
                
                non_framebyframe = ml_movie_update & ~ML_Movie_FrameByFrame;
                if any(non_framebyframe), ML_scene_updated = ML_scene_updated | any(~isnan(ML_Visual_InitialFrame(non_framebyframe))); end
            end
            
            % photodiode
            if ML_scene_updated && 1 < MLConfig.PhotoDiodeTrigger
                ML_PdStatus = ~ML_PdStatus;
                mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[ML_PdStatus ~ML_PdStatus]);
            end
            ML_TimeFromLastPresent(4) = trialtime;
            
            % render screen
            if ML_scene_updated || ML_ShowJoyCursor(1) || ML_ShowJoy2Cursor(1) || ML_ShowTouch(1)
                ML_scene_updated = true;
                mglrendergraphic(ML_CurrentFrameNumber,1);
            end
            ML_TimeFromLastPresent(5) = trialtime;

            ML_RenderingState = 1;
            if ~ml_new_scene, return, end
        end
                
        if 1==ML_RenderingState
            mglrendergraphic(ML_CurrentFrameNumber,2);
            ML_TimeFromLastPresent(6) = trialtime;

            ML_RenderingState = 2;
            if ~ml_new_scene, return, end
        end

        if 2==ML_RenderingState
            if ml_new_scene
                ml_tflip = mdqmex(9,4,ML_scene_updated,[ML_eventcode; ML_extra_eventcode],false); ML_extra_eventcode = [];
                ML_LastPresentTime = ml_tflip;
                ML_RenderingState = 3;
            else
                if ML_scene_updated
                    ML_TimeFromLastPresent(8) = trialtime;
                    ml_tflip = mdqmex(9,4,true,[ML_eventcode; ML_extra_eventcode],false); ML_extra_eventcode = [];
                    ml_frame_count = round((ml_tflip - ML_LastPresentTime) / Screen.FrameLength);
                    if 0 < ML_LastPresentTime
                        ml_skipped = ml_frame_count - 1;
                        if 0 < ml_skipped
                            if TrialRecord.MarkSkippedFrames, eventmarker(13); end
                            ml_skippedframetime = ML_LastPresentTime + Screen.FrameLength;
                            ml_skippedframetimeinfo = [ml_skippedframetime ml_tflip ml_skipped Screen.FrameLength ML_TimeFromLastPresent];
                            ml_nskippedframetimeinfo = length(ml_skippedframetimeinfo);
                            ML_SkippedFrameTimeInfo(end+1,ml_nskippedframetimeinfo) = 0;
                            ML_SkippedFrameTimeInfo(end,1:ml_nskippedframetimeinfo) = ml_skippedframetimeinfo;
                            ML_TotalSkippedFrames = ML_TotalSkippedFrames + ml_skipped;
                        end
                    end
                    ML_LastPresentTime = ml_tflip;
                    ML_RenderingState = 3;
                else
                    ml_next_flip_time = ML_LastPresentTime + Screen.FrameLength;
                    if ml_next_flip_time < trialtime
                        ML_LastPresentTime = ml_next_flip_time;
                        ML_RenderingState = 3;
                    end
                end
                return
            end
        end
        
        if 3==ML_RenderingState
            mglpresent(2,MLConfig.Touchscreen.On,SIMULATION_MODE);
            
            % update ObjectStatusRecord (used to play back trials from BHV file)
            if ml_new_scene
                ML_ToggleCount = ML_ToggleCount + 1;
                ML_ObjectStatusRecord.Time{ML_ToggleCount,1} = ML_LastPresentTime;
                ML_ObjectStatusRecord.Status{ML_ToggleCount,1} = TaskObject.Status;
                ML_ObjectStatusRecord.Position{ML_ToggleCount,1} = TaskObject.Position;
                ML_ObjectStatusRecord.Scale{ML_ToggleCount,1} = TaskObject.Scale;
                ML_ObjectStatusRecord.Angle{ML_ToggleCount,1} = TaskObject.Angle;
                ML_ObjectStatusRecord.Zorder{ML_ToggleCount,1} = TaskObject.Zorder;
                ML_ObjectStatusRecord.BackgroundColor{ML_ToggleCount,1} = Screen.BackgroundColor;
                ML_ObjectStatusRecord.Info(ML_ToggleCount).Count = ML_ToggleCount;
                if any(ml_position_update)
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).Position = ML_Visual_PositionArray;
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).StartPosition = ML_Visual_StartPosition;
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).PositionStep = ML_Visual_PositionStep;
                end
                if any(ml_frame_update)
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).MovieStartFrame = ML_Movie_StartFrame;
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).MovieFrameStep = ML_Movie_FrameStep;
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).MovieFrameOrder = ML_Movie_FrameOrderArray;
                end
                if any(non_framebyframe)
                    ML_ObjectStatusRecord.Info(ML_ToggleCount).MovieStartTime = ML_Movie_StartTime;
                end
            end
            
            ML_RenderingState = 0;
        end
    end

    %% function eyejoytrack
    ML_TotalTrackingTime = 0;
    ML_MaxCycleTime = 0;
    ML_TotalAcquiredSamples = 0;
    ML_MaxEyeTargetIndex = 10;
    ML_EyeTargetRecord = zeros(ML_MaxEyeTargetIndex,4);
    ML_EyeTargetIndex = 0;
    ML_Eye2TargetRecord = zeros(ML_MaxEyeTargetIndex,4);
    ML_Eye2TargetIndex = 0;
    ML_FlipThreshold = (Screen.FrameLength-Screen.VBlankLength) * fi(0==MLConfig.RasterThreshold,1,MLConfig.RasterThreshold);
    function [ml_ontarget, ml_rt, ml_trialtime] = eyejoytrack(varargin)
        ml_starttime = trialtime;
        ml_ontarget = 0;
        ml_rt = NaN;
        ml_trialtime = NaN;
        ML_TimeFromLastPresent(1) = ML_LastPresentTime;
        ML_TimeFromLastPresent(2) = ml_starttime;

        % bhvanalyzer{:,1} = function name
        % bhvanalyzer{:,2} = target stimuli/buttons
        % bhvanalyzer{:,3} = fixation threshold in visual angles (or button threshold in voltages)
        % bhvanalyzer{:,4} = target position in pixels
        % bhvanalyzer{:,5} = fixation threshold in pixels (or target button index)
        % bhvanalyzer{:,6} = ID of fixation window graphics
        % bhvanalyzer{:,7} = fixation status

        % check input arguments
        if strcmp(varargin{1}, 'idle')
            ml_bhvanalyzer = [];
            ml_nbhvanalyzer = 0;
            ml_maxtime = varargin{2};
        else
            ml_nbhvanalyzer = floor(nargin/3);
            ml_bhvanalyzer = cell(ml_nbhvanalyzer,7);
            ml_bhvanalyzer(:,1:3) = reshape(varargin(1:end-1),3,ml_nbhvanalyzer)';
            ml_bhvanalyzer(:,1) = lower(ml_bhvanalyzer(:,1));
            ml_maxtime = varargin{end};
        end

        ml_holdfix = []; ml_holdfix2 = [];
        for ml_=1:ml_nbhvanalyzer
            % signal type
%             switch ml_bhvanalyzer{ml_,1}
%                 case {'acquirefix','holdfix'}, if ~ML_eyepresent, error('Eye #1 is not defined in I/O menu!'); end
%                 case {'acquirefix2','holdfix2'}, if ~ML_eye2present, error('Eye #2 is not defined in I/O menu!'); end
%                 case {'acquiretarget','holdtarget'}, if ~ML_joypresent, error('Joystick #1 is not defined in I/O menu!'); end
%                 case {'acquiretarget2','holdtarget2'}, if ~ML_joy2present, error('Joystick #2 is not defined in I/O menu!'); end
%                 case {'acquiretouch','holdtouch'}, if ~ML_buttonpresent, error('No button defined in I/O menu!'); end
%                 case {'touchtarget','releasetarget','~touchtarget'}, if ~ML_touchpresent, error('Touchscreen not checked in I/O menu!'); end
%                 case {'acquirefunc','holdfunc'}, if ~isa(ml_bhvanalyzer{ml_,2},'function_handle'), error('The second argument must be a function handle!'); end
%                 otherwise, error('Undefined eyejoytrack function "%s".', ml_bhvanalyzer{ml_,1});
%             end
            
            % check the number of targets
            ml_ntargetobj = length(ml_bhvanalyzer{ml_,2});
            switch ml_bhvanalyzer{ml_,1}
                case 'holdfix', ml_holdfix(end+1) = ml_; if 1~=ml_ntargetobj, error('''%s'' requires only one target!',ml_bhvanalyzer{ml_,1}); end %#ok<AGROW>
                case 'holdfix2', ml_holdfix2(end+1) = ml_; if 1~=ml_ntargetobj, error('''%s'' requires only one target!',ml_bhvanalyzer{ml_,1}); end %#ok<AGROW>
                case {'holdtarget','holdtarget2','holdtouch','releasetarget'}, if 1~=ml_ntargetobj, error('''%s'' requires only one target!',ml_bhvanalyzer{ml_,1}); end
            end
            
            % target type, threshold & stimulus position/button index
            ml_nthreshold = numel(ml_bhvanalyzer{ml_,3});
            switch ml_bhvanalyzer{ml_,1}
                case {'acquiretouch','holdtouch'}
                    ml_invalid_button = ~ismember(ml_bhvanalyzer{ml_,2},ML_ButtonsAvailable);
                    if any(ml_invalid_button), error('Button #%d is not defined in I/O menu!',ml_bhvanalyzer{ml_,2}(find(ml_invalid_button,1))); end
                    if 0==ml_nthreshold
                        DAQ.button_threshold(ml_bhvanalyzer{ml_,2},[]);
                    else
                        ml_bhvanalyzer{ml_,3}(end+1:ml_ntargetobj) = ml_bhvanalyzer{ml_,3}(end);
                        DAQ.button_threshold(ml_bhvanalyzer{ml_,2},ml_bhvanalyzer{ml_,3});
                    end
                    ml_bhvanalyzer{ml_,5} = zeros(ml_ntargetobj,1);
                    for n=1:ml_ntargetobj, ml_bhvanalyzer{ml_,5}(n) = find(ML_ButtonsAvailable==ml_bhvanalyzer{ml_,2}(n),1); end
                case {'acquirefunc','holdfunc'}  % do nothing
                otherwise
                    ml_nonvisual_obj = ~ML_Visual(ml_bhvanalyzer{ml_,2});
                    if any(ml_nonvisual_obj), error('Target #%d is not a visual object!',find(ml_nonvisual_obj,1)); end
                    if 0==ml_nthreshold, error('The fixation radius is not specified!'); end
                    ml_bhvanalyzer{ml_,4} = EyeCal.deg2pix(TaskObject.Position(ml_bhvanalyzer{ml_,2},:));
                    ml_bhvanalyzer{ml_,6} = NaN(ml_ntargetobj,1);
                    if 1==ml_nthreshold || ml_ntargetobj==ml_nthreshold  % circle window
                        ml_bhvanalyzer{ml_,3}(end+1:ml_ntargetobj) = ml_bhvanalyzer{ml_,3}(end);
                        ml_bhvanalyzer{ml_,3} = ml_bhvanalyzer{ml_,3}(:);
                        ml_bhvanalyzer{ml_,5} = ml_bhvanalyzer{ml_,3} * Screen.PixelsPerDegree;
                        for n=1:ml_ntargetobj, ml_bhvanalyzer{ml_,6}(n) = mgladdcircle([0 255 0], ml_bhvanalyzer{ml_,5}(n) .* [2 2], 10); end
                    else  % rect window
                        if 2==ml_nthreshold, ml_bhvanalyzer{ml_,3} = repmat(ml_bhvanalyzer{ml_,3},ml_ntargetobj,1); end
                        ml_bhvanalyzer{ml_,5} = ml_bhvanalyzer{ml_,3} * Screen.PixelsPerDegree;
                        for n=1:ml_ntargetobj, ml_bhvanalyzer{ml_,6}(n) = mgladdbox([0 255 0], ml_bhvanalyzer{ml_,5}(n,:), 10); end
                        ml_bhvanalyzer{ml_,5} = [ml_bhvanalyzer{ml_,4} - ml_bhvanalyzer{ml_,5}/2 ml_bhvanalyzer{ml_,4} + ml_bhvanalyzer{ml_,5}/2]; 
                    end
                    mglsetorigin(ml_bhvanalyzer{ml_,6},ml_bhvanalyzer{ml_,4});
            end
        end

        ml_nstep = 5 + ml_nbhvanalyzer;
        ml_earlybreak = false;
        ml_sampletime = Inf;
        ml_stage_start_time = trialtime;
        ML_SampleCycleTime = zeros(1,ml_nstep + 1);
        ML_SampleCycleTime(2) = ml_stage_start_time - ml_starttime;
        ML_SampleCycleTime(end) = 1;
        ML_TimeFromLastPresent(3) = ml_stage_start_time;
        
        ml_analyzed = false;
        continue_ = true;
        while trialtime - ml_starttime < ml_maxtime
            for ML_SampleCycleStage=1:ml_nstep
                if 2~=ML_RenderingState, toggleobject(0); end
                ML_SampleCycleTime(ML_SampleCycleStage) = trialtime - ml_stage_start_time;
                if 2==ML_RenderingState
                    ml_time_to_next_flip = ML_LastPresentTime + ML_FlipThreshold - trialtime;
                    if ml_time_to_next_flip < max(ML_SampleCycleTime)
                        ML_TimeFromLastPresent(7) = trialtime;
                        ml_tflip = toggleobject(0);
                        if ML_Benchmark && ~isempty(ml_tflip), ML_BenchmarkFrameCount = ML_BenchmarkFrameCount + 1; ML_BenchmarkFrame(ML_BenchmarkFrameCount) = ml_tflip; end
                    end
                end
                ml_stage_start_time = trialtime;

                switch ML_SampleCycleStage
                    case 1  % read samples
                        ML_TotalAcquiredSamples = ML_TotalAcquiredSamples + 1;
                        ML_MaxCycleTime = max(ML_MaxCycleTime, trialtime - ml_sampletime);
                        ml_sampletime = trialtime;
                        if SIMULATION_MODE, DAQ.simulated_input(0); [ml_mouse,ml_mousebutton] = getsample(ML_Mouse); else, getsample(DAQ); end
                        if ML_Benchmark, ML_BenchmarkSampleCount = ML_BenchmarkSampleCount + 1; ML_BenchmarkSample(ML_BenchmarkSampleCount) = ml_sampletime; end
                        ml_kb = kbdgetkey; if ~isempty(ml_kb), hotkey(ml_kb); end
           
                    case 2
                        ml_eye = []; ml_eye2 = []; ml_joy = [];
                        if SIMULATION_MODE
                            ml_eye = EyeCal.control2pix(ml_mouse);
                            ml_eye2 = Eye2Cal.deg2pix(DAQ.SimulatedEye2);
                            ml_joy = JoyCal.deg2pix(DAQ.SimulatedJoystick);
                        else
                            if ML_eyepresent, ml_eye = EyeCal.sig2pix(DAQ.Eye,ML_EyeOffset); end
                            if ML_eye2present, ml_eye2 = Eye2Cal.sig2pix(DAQ.Eye2,ML_Eye2Offset); end
                            if ML_joypresent, ml_joy = JoyCal.sig2pix(DAQ.Joystick,ML_JoyOffset); end
                        end
                        
                    case 3
                        ml_joy2 = []; ml_button = []; ml_touch = [];
                        if SIMULATION_MODE
                            ml_joy2 = Joy2Cal.deg2pix(DAQ.SimulatedJoystick2);
                            ml_button = DAQ.SimulatedButton;
                            ml_touch = repmat(ml_eye,2,1); ml_touch(~ml_mousebutton(1:2),:) = NaN;
                        else
                            if ML_joy2present, ml_joy2 = Joy2Cal.sig2pix(DAQ.Joystick2,ML_Joy2Offset); end
                            if ML_buttonpresent, ml_button = DAQ.Button; end
                            if ML_touchpresent, ml_touch = EyeCal.subject2pix(reshape(DAQ.Touch,2,[])'); end
                        end
                        
                    case 4
                        if ~isempty(ml_eye)
                            if Screen.EyeLineTracer
                                mglsetproperty(Screen.EyeTracer,'addpoint',ml_eye);
                            else
                                mglsetorigin(Screen.EyeTracer,ml_eye);
                            end
                        end
                        if ~isempty(ml_eye2)
                            if Screen.Eye2LineTracer
                                mglsetproperty(Screen.Eye2Tracer,'addpoint',ml_eye2);
                            else
                                mglsetorigin(Screen.Eye2Tracer,ml_eye2);
                            end
                        end
                        if ~isempty(ml_joy), mglsetorigin(Screen.JoystickCursor,ml_joy); end
                        
                    case 5
                        if ~isempty(ml_joy2), mglsetorigin(Screen.Joystick2Cursor,ml_joy2); end
                        if ~isempty(ml_button)
                            mglactivategraphic(Screen.ButtonPressed(ML_ButtonsAvailable),ml_button(ML_ButtonsAvailable));
                            mglactivategraphic(Screen.ButtonReleased(ML_ButtonsAvailable),~ml_button(ML_ButtonsAvailable));
                        end
                        if ~isempty(ml_touch)
                            ml_ntouch = size(ml_touch,1);
                            ml_active_touch = ~isnan(ml_touch(:,1));
                            if ML_ShowTouch(1)
                                mglactivategraphic(Screen.TouchCursor(1:ml_ntouch,1),ml_active_touch);
                                mglsetorigin(Screen.TouchCursor(1:ml_ntouch,1),ml_touch);
                            end
                            if ML_ShowTouch(2)
                                mglactivategraphic(Screen.TouchCursor(1:ml_ntouch,2),ml_active_touch);
                                mglsetorigin(Screen.TouchCursor(1:ml_ntouch,2),ml_touch);
                            end
                            ml_touch = ml_touch(ml_active_touch,:);  % get rid of no touch
                        end
                        
                    otherwise  % check behavior
                        ml_ = ML_SampleCycleStage - 5;
                        switch ml_bhvanalyzer{ml_,1}
                            case 'acquiretouch', ml_bhvanalyzer{ml_,7} = ml_button(ml_bhvanalyzer{ml_,5}); ml_hold = false;
                            case 'holdtouch',    ml_bhvanalyzer{ml_,7} = ml_button(ml_bhvanalyzer{ml_,5}); ml_hold = true;
                            case 'acquirefunc',  if 0==nargin(ml_bhvanalyzer{ml_,2}), ml_bhvanalyzer{ml_,7} = ml_bhvanalyzer{ml_,2}(); else, ml_bhvanalyzer{ml_,7} = ml_bhvanalyzer{ml_,2}(ml_bhvanalyzer{ml_,3}); end, ml_hold = false;
                            case 'holdfunc',     if 0==nargin(ml_bhvanalyzer{ml_,2}), ml_bhvanalyzer{ml_,7} = ml_bhvanalyzer{ml_,2}(); else, ml_bhvanalyzer{ml_,7} = ml_bhvanalyzer{ml_,2}(ml_bhvanalyzer{ml_,3}); end, ml_hold = true;
                                                 if 1~=length(ml_bhvanalyzer{ml_,7}), error('''holdfunc'' requires a logical scalar!'); end
                            otherwise
                                ml_invert = false;
                                switch ml_bhvanalyzer{ml_,1}
                                    case 'acquirefix',     ml_source = ml_eye;   ml_hold = false;
                                    case 'holdfix',        ml_source = ml_eye;   ml_hold = true;
                                    case 'acquirefix2',    ml_source = ml_eye2;  ml_hold = false;
                                    case 'holdfix2',       ml_source = ml_eye2;  ml_hold = true;
                                    case 'acquiretarget',  ml_source = ml_joy;   ml_hold = false;
                                    case 'holdtarget',     ml_source = ml_joy;   ml_hold = true;
                                    case 'acquiretarget2', ml_source = ml_joy2;  ml_hold = false;
                                    case 'holdtarget2',    ml_source = ml_joy2;  ml_hold = true;
                                    case 'touchtarget',    ml_source = ml_touch; ml_hold = false;
                                    case 'releasetarget',  ml_source = ml_touch; ml_hold = true;  if isempty(ml_source), ml_source = NaN(1,2); end
                                    case '~touchtarget',   ml_source = ml_touch; ml_hold = false; ml_invert = true;
                                end
                                if ~isempty(ml_source)
                                    for ml_m = 1:size(ml_source,1)
                                        ml_xy = ml_source(ml_m,:);
                                        if 1==size(ml_bhvanalyzer{ml_,5},2)  % circle window
                                            ml_bhvanalyzer{ml_,7} = xor(ml_invert,sum((ml_bhvanalyzer{ml_,4} - repmat(ml_xy,size(ml_bhvanalyzer{ml_,4},1),1)).^2,2) < ml_bhvanalyzer{ml_,5}.^2);
                                        else
                                            ml_rc = ml_bhvanalyzer{ml_,5};  % rect window
                                            ml_bhvanalyzer{ml_,7} = xor(ml_invert,ml_rc(:,1)<ml_xy(1) & ml_xy(1)<ml_rc(:,3) & ml_rc(:,2)<ml_xy(2) & ml_xy(2)<ml_rc(:,4));
                                        end
                                        if any(ml_bhvanalyzer{ml_,7}), break; end
                                    end
                                end
                        end
                        ml_earlybreak = ml_earlybreak | any(xor(ml_bhvanalyzer{ml_,7},ml_hold));
                end
            end
            ml_analyzed = true;
            if ml_earlybreak || ~continue_, break, end
        end
        if 3==ML_RenderingState, toggleobject(0); end
        
        for ml_=ml_nbhvanalyzer:-1:1
            mgldestroygraphic(ml_bhvanalyzer{ml_,6});
            ml_success = find(ml_bhvanalyzer{ml_,7},1);
            if isempty(ml_success) || ~continue_, ml_ontarget(ml_) = 0; else, ml_ontarget(ml_) = ml_success; end
        end
        if ml_earlybreak || ~continue_
            ml_rt = ml_sampletime - ml_starttime;
            ml_trialtime = ml_sampletime;
            ML_TotalTrackingTime = ML_TotalTrackingTime + ml_rt;
        else
            ML_TotalTrackingTime = ML_TotalTrackingTime + ml_maxtime;
            for ml_ = ml_holdfix
                if ML_EyeTargetIndex < ML_MaxEyeTargetIndex
                    ml_record = [TaskObject.Position(ml_bhvanalyzer{ml_,2},:) [ml_starttime 0] + ml_maxtime/2];  % use the 2nd half of the holding period
                    if ML_SampleInterval*2 < ml_record(4), ML_EyeTargetIndex = ML_EyeTargetIndex + 1; ML_EyeTargetRecord(ML_EyeTargetIndex,:) = ml_record; end
                end
            end
            for ml_ = ml_holdfix2
                if ML_Eye2TargetIndex < ML_MaxEyeTargetIndex
                    ml_record = [TaskObject.Position(ml_bhvanalyzer{ml_,2},:) [ml_starttime 0] + ml_maxtime/2];  % use the 2nd half of the holding period
                    if ML_SampleInterval*2 < ml_record(4), ML_Eye2TargetIndex = ML_Eye2TargetIndex + 1; ML_Eye2TargetRecord(ML_Eye2TargetIndex,:) = ml_record; end
                end
            end
        end
        if ~ml_analyzed && 0<ml_nbhvanalyzer, user_warning('Duration for eyejoytrack() is too short'); end
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
        if ML_touchpresent, mglcallmessageloop(SIMULATION_MODE); end
        [ml_xy,ml_button] = getsample(ML_Mouse);
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
    ML_EyeOffset = [0 0];
    function varargout = eye_position()
        if SIMULATION_MODE
            ml_eye = mouse_position();
        elseif ML_eyepresent
            getsample(DAQ);
            ml_eye = EyeCal.sig2deg(DAQ.Eye,ML_EyeOffset);
        else
            ml_eye = NaN(1,2);
        end
        switch nargout
            case 1, varargout{1} = ml_eye;
            case 2, varargout{1} = ml_eye(1); varargout{2} = ml_eye(2);
        end
    end
    
    %% function eye2_position
    ML_Eye2Offset = [0 0];
    function varargout = eye2_position()
        if SIMULATION_MODE
            ml_eye2 = DAQ.SimulatedEye2;
        elseif ML_eye2present
            getsample(DAQ);
            ml_eye2 = Eye2Cal.sig2deg(DAQ.Eye2,ML_Eye2Offset);
        else
            ml_eye2 = NaN(1,2);
        end
        switch nargout
            case 1, varargout{1} = ml_eye2;
            case 2, varargout{1} = ml_eye2(1); varargout{2} = ml_eye2(2);
        end
    end
    
    %% function joystick_position
    ML_JoyOffset = [0 0];
    function varargout = joystick_position()
        if SIMULATION_MODE
            ml_joy = DAQ.SimulatedJoystick;
        elseif ML_joypresent
            getsample(DAQ);
            ml_joy = JoyCal.sig2deg(DAQ.Joystick,ML_JoyOffset);
        else
            ml_joy = NaN(1,2);
        end
        switch nargout
            case 1, varargout{1} = ml_joy;
            case 2, varargout{1} = ml_joy(1); varargout{2} = ml_joy(2);
        end
    end

    %% function joystick2_position
    ML_Joy2Offset = [0 0];
    function varargout = joystick2_position()
        if SIMULATION_MODE
            ml_joy2 = DAQ.SimulatedJoystick2;
        elseif ML_joy2present
            getsample(DAQ);
            ml_joy2 = Joy2Cal.sig2deg(DAQ.Joystick2,ML_Joy2Offset);
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
        if ML_touchpresent, mglcallmessageloop(SIMULATION_MODE); end
        if SIMULATION_MODE
            [ml_xy,ml_button] = getsample(ML_Mouse);
            ml_touch = repmat(EyeCal.control2deg(ml_xy),1,2); ml_touch(~ml_button(1),1:2) = NaN; ml_touch(~ml_button(2),3:4) = NaN;
        elseif ML_touchpresent
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
                    for m=DAQ.highfrequency_available, ml_data{m} = ml_samples(:,ml_chan(m)); end
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
                case 'eye', ml_data = EyeCal.sig2deg(DAQ.Eye,ML_EyeOffset);
                case 'eye2', ml_data = Eye2Cal.sig2deg(DAQ.Eye2,ML_Eye2Offset);
                case 'eyeextra', ml_data = DAQ.EyeExtra;
                case {'joy','joystick'}, ml_data = JoyCal.sig2deg(DAQ.Joystick,ML_JoyOffset);
                case {'joy2','joystick2'}, ml_data = Joy2Cal.sig2deg(DAQ.Joystick2,ML_Joy2Offset);
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
        if any(ML_nObject < stimnum), error('Some of given stimuli do not exist.'); end
        if any(~ML_Visual(stimnum)), error('Some of given stimuli are non-visual.'); end

        if 2<nargin, xydeg = [xydeg(:) ydeg(:)]; end

        TaskObject.Position(stimnum,:) = xydeg;
        ML_Visual_PositionArray(stimnum) = {[]};
        ML_Visual_StartPosition(stimnum) = 1;
        ML_Visual_PositionStep(stimnum) = 1;
        ML_Visual_nPosition(stimnum) = 0;
        if any(TaskObject.Status(stimnum)), ML_forced_new_scene = true; end
        ml_success = true;
    end

    %% function rescale_object
    function rescale_object(stimnum, scale)
        if numel(stimnum)==numel(scale), scale = repmat(scale(:),1,2); end
        TaskObject.Scale(stimnum) = scale;
        if any(TaskObject.Status(stimnum)), ML_forced_new_scene = true; end
    end

    %% function rotate_object
    function rotate_object(stimnum, angle)
        TaskObject.Angle(stimnum) = angle;
        if any(TaskObject.Status(stimnum)), ML_forced_new_scene = true; end
    end

    %% function set_object_path
    function ml_success = set_object_path(stimnum, xydeg, ydeg)
        if ~isscalar(stimnum), error('This function works for one stimulus at a time. Please pass a scalar.'); end
        if ML_nObject < stimnum, error('Stimulus #%d does not exist.',stimnum); end
        if ~ML_Visual(stimnum), error('Stimulus #%d is not a visual stimulus.',stimnum); end

        if 2<nargin, xydeg = [xydeg(:) ydeg(:)]; end
        
        ml_npath = size(xydeg,1);
        if 1 == ml_npath
            reposition_object(stimnum,xydeg,ydeg);
        else
            ML_Visual_PositionArray{stimnum} = xydeg;
            ML_Visual_StartPosition(stimnum) = 1;
            ML_Visual_PositionStep(stimnum) = 1;
            ML_Visual_nPosition(stimnum) = ml_npath;
            if any(TaskObject.Status(stimnum)), ML_forced_new_scene = true; end
        end
        ml_success = true;
    end

    %% function set_frame_order
    function ml_success = set_frame_order(stimnum,frameorder)
        if ~isscalar(stimnum), error('This function works for one stimulus at a time. Please pass a scalar.'); end
        if ML_nObject < stimnum, error('Stimulus #%d does not exist.',stimnum); end
        if ~ML_Movie(stimnum), error('Stimulus #%d is not a movie.',stimnum); end
        if ~isnumeric(frameorder), error('FrameOrder must be numeric.'); end
        if any(ML_Movie_nFrame(stimnum) < frameorder), error('FrameOrder is out of range'); end

        if isempty(frameorder)
            ML_Movie_FrameOrderArray{stimnum} = [];
            ML_Movie_nFrameOrder(stimnum) = 0;
        else
            ML_Movie_FrameByFrame(stimnum) = true;
            mglsetproperty(TaskObject.ID(stimnum),'framebyframe');
            ML_Movie_FrameOrderArray{stimnum} = frameorder(:);
            ML_Movie_nFrameOrder(stimnum) = numel(frameorder);
            if any(TaskObject.Status(stimnum)), ML_forced_new_scene = true; end
        end
        ml_success = true;
    end
    
    %% function set_frame_event
    function set_frame_event(stimnum,framenum,evcode)
        if ~isscalar(stimnum), error('This function works for one stimulus at a time. Please pass a scalar.'); end
        if ML_nObject < stimnum, error('Stimulus #%d does not exist.',stimnum); end
        if ~ML_Movie(stimnum), error('Stimulus #%d is not a movie.',stimnum); end
        if ~isnumeric(framenum) || ~isnumeric(evcode), error('Frame-triggered event marker arguments must be numeric.'); end
        if numel(framenum) ~= numel(evcode), error('Frame-triggered event marker arguments must be of equal length.'); end

        ML_Movie_FrameEventArray{stimnum} = [framenum(:) evcode(:)];
        ML_Movie_nFrameEvent(stimnum) = numel(framenum);
    end

    %% function set_bgcolor(bgcolor)
    function set_bgcolor(bgcolor)
        if ~exist('bgcolor','var'), bgcolor = []; end
        Screen.BackgroundColor = fi(isempty(bgcolor),MLConfig.SubjectScreenBackground,bgcolor);
        ML_forced_new_scene = true;
    end

    %% function idle
    function idle(duration, bgcolor, event)
        switch nargin
            case 1, bgcolor = [];
            case 3, ML_extra_eventcode = event(:);
        end
        if ~isempty(bgcolor), ml_prev_color = Screen.BackgroundColor; set_bgcolor(bgcolor); end
        eyejoytrack('idle', duration);
        if ~isempty(bgcolor), set_bgcolor(ml_prev_color); end
    end
    
    %% function set_iti
    function set_iti(t), TrialRecord.InterTrialInterval = t; end

    %% functon showcursor
    mglactivategraphic(Screen.JoystickCursor,ML_ShowJoyCursor);
    function showcursor(cflag)
        if ischar(cflag), ml_state = strcmpi(cflag,'on'); else, ml_state = logical(cflag); end
        ML_ShowJoyCursor = [ml_state ML_ShowJoyCursor(1)|ml_state];
        mglactivategraphic(Screen.JoystickCursor,ML_ShowJoyCursor);
    end

    %% functon showcursor2
    mglactivategraphic(Screen.Joystick2Cursor,ML_ShowJoy2Cursor);
    function showcursor2(cflag)
        if ischar(cflag), ml_state = strcmpi(cflag,'on'); else, ml_state = logical(cflag); end
        ML_ShowJoy2Cursor = [ml_state ML_ShowJoy2Cursor(1)|ml_state];
        mglactivategraphic(Screen.Joystick2Cursor,ML_ShowJoy2Cursor);
    end

    %% functon showtouch
    function showtouch(cflag)
        if ischar(cflag), ml_state = strcmpi(cflag,'on'); else, ml_state = logical(cflag); end
        ML_ShowTouch = [ml_state ML_ShowTouch(1)|ml_state];
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
        
        ml_ = ismember(stimnum,find(ML_Movie&~ML_Movie_FrameByFrame));
        if any(ml_)
            time_in_msec(length(time_in_msec)+1:length(stimnum)) = time_in_msec(end);
            stimnum = stimnum(ml_); time_in_msec = time_in_msec(ml_);
            ML_Movie_StartTime(stimnum) = time_in_msec/1000;
            ml_ = ~isnan(ML_Visual_InitialFrame(stimnum));
            if any(ml_), ML_Visual_InitialFrame(stimnum(ml_)) = floor(trialtime()/Screen.FrameLength); ML_forced_new_scene = true; end
        end
    end

    %% function get_object_duration
    function [duration_in_msec,duration_in_frames] = get_object_duration(stimnum)
        duration_in_msec = ML_ObjectDuration(stimnum) * 1000;
        duration_in_frames = ceil(ML_ObjectDuration(stimnum) * Screen.RefreshRate);
    end
    
    %% deprecated: function rewind_movie
    function rewind_movie(stimnum,time_in_msec)
        if ~exist('stimnum','var'), stimnum = find(ML_Movie & ~ML_Movie_FrameByFrame); end
        if ~exist('time_in_msec','var'), time_in_msec = 0; end
        rewind_object(stimnum,time_in_msec);
    end

    %% deprecated: function rewind_sound
    function rewind_sound(stimnum,time_in_msec)
        if ~exist('stimnum','var'), stimnum = find(ML_Sound); end
        if ~exist('time_in_msec','var'), time_in_msec = 0; end
        rewind_object(stimnum,time_in_msec);
    end

    %% deprecated: function get_movie_duration
    function [duration_in_msec,duration_in_frames] = get_movie_duration(stimnum)
        if ~exist('stimnum','var'), stimnum = find(ML_Movie); end
        [duration_in_msec,duration_in_frames] = get_object_duration(stimnum);
    end

    %% deprecated: function get_sound_duration
    function duration_in_msec = get_sound_duration(stimnum)
        if ~exist('stimnum','var'), stimnum = find(ML_Sound); end
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
        mdqmex(9,3,ml_code);
        TrialRecord.InterTrialIntervalTimer = tic;
        
        % turn off the photodiode trigger so that it becomes black when the next trial begins.
        if ML_PdStatus && 1 < MLConfig.PhotoDiodeTrigger
            mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[false true]);
            mglrendergraphic(ML_CurrentFrameNumber,1,true);
            mglpresent(1);
        end

        if TrialRecord.TestTrial, stop(DAQ); return, end
        
        TrialData.AnalogData.SampleInterval = ML_SampleInterval;
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
                if ~isempty(DAQ.Eye), TrialData.AnalogData.Eye = EyeCal.sig2deg(DAQ.Eye,ML_EyeOffset); end
                if ~isempty(DAQ.Eye2), TrialData.AnalogData.Eye2 = Eye2Cal.sig2deg(DAQ.Eye2,ML_Eye2Offset); end
                if ~isempty(DAQ.EyeExtra), TrialData.AnalogData.EyeExtra = DAQ.EyeExtra; end
                if ~isempty(DAQ.Joystick), TrialData.AnalogData.Joystick = JoyCal.sig2deg(DAQ.Joystick,ML_JoyOffset); end
                if ~isempty(DAQ.Joystick2), TrialData.AnalogData.Joystick2 = Joy2Cal.sig2deg(DAQ.Joystick2,ML_Joy2Offset); end
                if ~isempty(DAQ.Touch), TrialData.AnalogData.Touch = EyeCal.subject2deg(DAQ.Touch); end
                if ~isempty(DAQ.Mouse), TrialData.AnalogData.Mouse = [EyeCal.subject2deg(DAQ.Mouse) DAQ.MouseButton]; end
                if ~isempty(DAQ.KeyInput), TrialData.AnalogData.KeyInput = DAQ.KeyInput; end
                if ~isempty(DAQ.PhotoDiode), TrialData.AnalogData.PhotoDiode = DAQ.PhotoDiode; end
                for ml_=DAQ.buttons_available, TrialData.AnalogData.Button.(sprintf('Btn%d',ml_)) = DAQ.Button{ml_}; end
            end
            for ml_=DAQ.general_available, TrialData.AnalogData.General.(sprintf('Gen%d',ml_)) = DAQ.General{ml_}; end
        else
            ml_MinSamplesExpected = ceil(trialtime());
            ml_SamplePoint = 1:ML_SampleInterval:ml_MinSamplesExpected;
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
                if ~isempty(DAQ.Eye), TrialData.AnalogData.Eye = EyeCal.sig2deg(DAQ.Eye(ml_SamplePoint,:),ML_EyeOffset); end
                if ~isempty(DAQ.Eye2), TrialData.AnalogData.Eye2 = Eye2Cal.sig2deg(DAQ.Eye2(ml_SamplePoint,:),ML_Eye2Offset); end
                if ~isempty(DAQ.EyeExtra), TrialData.AnalogData.EyeExtra = DAQ.EyeExtra(ml_SamplePoint,:); end
                if ~isempty(DAQ.Joystick), TrialData.AnalogData.Joystick = JoyCal.sig2deg(DAQ.Joystick(ml_SamplePoint,:),ML_JoyOffset); end
                if ~isempty(DAQ.Joystick2), TrialData.AnalogData.Joystick2 = Joy2Cal.sig2deg(DAQ.Joystick2(ml_SamplePoint,:),ML_Joy2Offset); end
                if ~isempty(DAQ.Touch), TrialData.AnalogData.Touch = EyeCal.subject2deg(DAQ.Touch(ml_SamplePoint,:)); end
                if ~isempty(DAQ.Mouse), TrialData.AnalogData.Mouse = [EyeCal.subject2deg(DAQ.Mouse(ml_SamplePoint,:)) DAQ.MouseButton(ml_SamplePoint,:)]; end
                if ~isempty(DAQ.KeyInput), TrialData.AnalogData.KeyInput = DAQ.KeyInput(ml_SamplePoint,:); end
                if ~isempty(DAQ.PhotoDiode), TrialData.AnalogData.PhotoDiode = DAQ.PhotoDiode(ml_SamplePoint,:); end
                for ml_=DAQ.buttons_available, TrialData.AnalogData.Button.(sprintf('Btn%d',ml_)) = DAQ.Button{ml_}(ml_SamplePoint,:); end
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
            mglsetproperty(TaskObject.ID(ML_Movie_FrameByFrame),'setnextframe',1);

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
            if all(0==ML_EyeOffset) && 0 < ML_EyeTargetIndex && ~isempty(TrialData.AnalogData.Eye)
                try
                    ML_EyeTargetRecord = ML_EyeTargetRecord(1:ML_EyeTargetIndex,:);
                    ML_EyeTargetRecord(:,3) = ceil(ML_EyeTargetRecord(:,3) ./ ML_SampleInterval);
                    ML_EyeTargetRecord(:,4) = ML_EyeTargetRecord(:,3) + floor(ML_EyeTargetRecord(:,4) ./ ML_SampleInterval) - 1;
                    ml_npoint = size(ML_EyeTargetRecord,1);
                    ml_new_fix_point = zeros(ml_npoint,2);
                    for ml_ = 1:ml_npoint, ml_new_fix_point(ml_,:) = median(TrialData.AnalogData.Eye(ML_EyeTargetRecord(ml_,3):ML_EyeTargetRecord(ml_,4),:),1); end
                    ML_EyeOffset = mean(ml_new_fix_point - ML_EyeTargetRecord(:,1:2),1) * EyeCal.rotation_rev_t .* (MLConfig.EyeAutoDriftCorrection / 100);

                    if MLConfig.SummarySceneDuringITI
                        ML_EyeTargetRecord(:,1:2) = EyeCal.deg2pix(ML_EyeTargetRecord(:,1:2));
                        ml_new_fix_point = EyeCal.deg2pix(ml_new_fix_point);
                        ml_size = 0.3 * Screen.PixelsPerDegree;
                        for ml_ = 1:ml_npoint
                            ml_id = mgladdcircle(repmat(MLConfig.FixationPointColor,2,1),ml_size,10); mglsetorigin(ml_id,ML_EyeTargetRecord(ml_,1:2));
                            ml_id = mgladdcircle(repmat(MLConfig.EyeTracerColor(1,:),2,1),ml_size,10); mglsetorigin(ml_id,ml_new_fix_point(ml_,:));
                        end
                    end
                catch
                    warning('Eye #1 Auto drift correction failed!!!');
                end
            end
            if all(0==ML_Eye2Offset) && 0 < ML_Eye2TargetIndex && ~isempty(TrialData.AnalogData.Eye2)
                try
                    ML_Eye2TargetRecord = ML_Eye2TargetRecord(1:ML_Eye2TargetIndex,:);
                    ML_Eye2TargetRecord(:,3) = ceil(ML_Eye2TargetRecord(:,3) ./ ML_SampleInterval);
                    ML_Eye2TargetRecord(:,4) = ML_Eye2TargetRecord(:,3) + floor(ML_Eye2TargetRecord(:,4) ./ ML_SampleInterval) - 1;
                    ml_npoint = size(ML_Eye2TargetRecord,1);
                    ml_new_fix_point = zeros(ml_npoint,2);
                    for ml_ = 1:ml_npoint, ml_new_fix_point(ml_,:) = median(TrialData.AnalogData.Eye2(ML_Eye2TargetRecord(ml_,3):ML_Eye2TargetRecord(ml_,4),:),1); end
                    ML_Eye2Offset = mean(ml_new_fix_point - ML_Eye2TargetRecord(:,1:2),1) * Eye2Cal.rotation_rev_t .* (MLConfig.EyeAutoDriftCorrection / 100);

                    if MLConfig.SummarySceneDuringITI
                        ML_Eye2TargetRecord(:,1:2) = Eye2Cal.deg2pix(ML_Eye2TargetRecord(:,1:2));
                        ml_new_fix_point = Eye2Cal.deg2pix(ml_new_fix_point);
                        ml_size = 0.3 * Screen.PixelsPerDegree;
                        for ml_ = 1:ml_npoint
                            ml_id = mgladdcircle(repmat(MLConfig.FixationPointColor,2,1),ml_size,10); mglsetorigin(ml_id,ML_EyeTargetRecord(ml_,1:2));
                            ml_id = mgladdcircle(repmat(MLConfig.EyeTracerColor(2,:),2,1),ml_size,10); mglsetorigin(ml_id,ml_new_fix_point(ml_,:));
                        end
                    end
                catch
                    warning('Eye #2 Auto drift correction failed!!!');
                end
            end
        end
        mglsetscreencolor(2,fi(MLConfig.NonStopRecording,[0.0667 0.1666 0.2745],[0.25 0.25 0.25]));
        mdqmex(1,108);  % ClearControlScreenEdge
        mglrendergraphic(ML_CurrentFrameNumber,2,true);
        mglpresent(2);
        if MLConfig.SummarySceneDuringITI, mgldestroygraphic(mlsetdiff(mglgetallobjects,object_id)); mglactivategraphic(object_id,object_status); end

        % update EyeTransform
        if any(ML_EyeOffset), EyeCal.translate(ML_EyeOffset); end
        if any(ML_Eye2Offset), Eye2Cal.translate(ML_Eye2Offset); end
        
        [TrialData.BehavioralCodes.CodeTimes,TrialData.BehavioralCodes.CodeNumbers] = mdqmex(42,2);
        TrialData.ReactionTime = rt;
        TrialData.ObjectStatusRecord.Time = vertcat(ML_ObjectStatusRecord.Time{1:ML_ToggleCount});
        TrialData.ObjectStatusRecord.Status = vertcat(ML_ObjectStatusRecord.Status{1:ML_ToggleCount});
        TrialData.ObjectStatusRecord.Position = ML_ObjectStatusRecord.Position(1:ML_ToggleCount);
        TrialData.ObjectStatusRecord.Scale = ML_ObjectStatusRecord.Scale(1:ML_ToggleCount);
        TrialData.ObjectStatusRecord.Angle = vertcat(ML_ObjectStatusRecord.Angle{1:ML_ToggleCount});
        TrialData.ObjectStatusRecord.Zorder = vertcat(ML_ObjectStatusRecord.Zorder{1:ML_ToggleCount});
        TrialData.ObjectStatusRecord.BackgroundColor = vertcat(ML_ObjectStatusRecord.BackgroundColor{1:ML_ToggleCount});
        TrialData.ObjectStatusRecord.Info = rmfield(ML_ObjectStatusRecord.Info(1:ML_ToggleCount),'Count');
        [TrialData.RewardRecord.StartTimes,TrialData.RewardRecord.EndTimes] = mdqmex(43,4);
        if 0==ML_TotalTrackingTime, TrialData.CycleRate = [0 0]; else, TrialData.CycleRate = [ML_MaxCycleTime round(1000*ML_TotalAcquiredSamples/ML_TotalTrackingTime)]; end
        TrialData.NewEyeTransform = EyeCal.get_transform_matrix();
        TrialData.NewEye2Transform = Eye2Cal.get_transform_matrix();
        TrialData.VariableChanges.EyeOffset = ML_EyeOffset;
        TrialData.VariableChanges.Eye2Offset = ML_Eye2Offset;
        TrialData.VariableChanges.reward_dur = reward_dur;
        TrialData.UserVars.SkippedFrameTimeInfo = ML_SkippedFrameTimeInfo;
        TrialData.TaskObject.FrameByFrameMovie = ML_Movie_FrameByFrame;
        TrialData.TaskObject.CurrentConditionInfo = TrialRecord.CurrentConditionInfo;

        ml_ = any(TrialData.ObjectStatusRecord.Status,1);
        ml_used = TaskObject.MoreInfo(ml_).Filename;
        TrialRecord.TaskInfo.Stimuli = unique([TrialRecord.TaskInfo.Stimuli ml_used]);
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
            ml_pos = TaskObject.Position(ML_Visual & TaskObject.Status,:);
            switch size(ml_pos,1)
                case 0, origin = [0 0];
                case 1, origin = ml_pos;
                otherwise, [~,ml_]= min(sum((ml_pos - repmat(ml_eye,size(ml_pos,1),1)).^2,2)); origin = ml_pos(ml_,:);
            end
        end
        switch devnum
            case 1
                ML_prev_eye_position(end+1,:) = (ml_eye - origin) * EyeCal.rotation_rev_t;
                ML_EyeOffset = ML_EyeOffset + ML_prev_eye_position(end,:);
            otherwise
                ML_prev_eye2_position(end+1,:) = (ml_eye - origin) * Eye2Cal.rotation_rev_t;
                ML_Eye2Offset = ML_Eye2Offset + ML_prev_eye2_position(end,:);
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
    hotkey('u', 'if ~isempty(ML_prev_eye_position), ML_EyeOffset = ML_EyeOffset - ML_prev_eye_position(end,:); ML_prev_eye_position(end,:) = []; end');
    hotkey('v', 'forced_eye_drift_correction([0 0],2);');  % adjust eye offset
    hotkey('i', 'if ~isempty(ML_prev_eye2_position), ML_Eye2Offset = ML_Eye2Offset - ML_prev_eye2_position(end,:); ML_prev_eye2_position(end,:) = []; end');
    hotkey('f12', 'TrialRecord.HotkeyLocked = ~TrialRecord.HotkeyLocked; mglactivategraphic(Screen.HotkeyLocked,TrialRecord.HotkeyLocked);');
end

kbdflush;
rt = NaN;

    function warming_up()
        ML_trialtime_offset = toc(ML_global_timer); DAQ.init_timer(ML_global_timer,ML_trialtime_offset);  % to make trialtime work during warming up
        mglgsave; mglpresentlock(true);
        for ml_=1:10
            calculate_cam_offset(DAQ); lsl_reset_clock(DAQ); lsl_pull_chunk(DAQ); lsl_clear_chunk(DAQ);
            toggleobject(find(ML_Visual),'status','on'); eyejoytrack('acquirefunc',@dummy_function,[],20); toggleobject(find(ML_Visual),'status','off');
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

        ML_PdStatus = false;
        if 1 < MLConfig.PhotoDiodeTrigger, mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[ML_PdStatus ~ML_PdStatus]); end
        ML_RenderingState = 0;
        ML_CurrentFrameNumber = 0;
        ML_LastPresentTime = 0;
        ML_GraphicsUsedInThisTrial = false(1,ML_nObject);
        ML_SkippedFrameTimeInfo = [];
        ML_TotalSkippedFrames = 0;
        ML_ToggleCount = 0;
        ML_TotalTrackingTime = 0;
        ML_MaxCycleTime = 0;
        ML_TotalAcquiredSamples = 0;

        function val = dummy_function(), val = false; end
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
