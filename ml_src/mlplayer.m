function mlplayer(datafile,varargin)

newline = char(10); %#ok<CHARTEN>

data = [];
MLConfig = [];
DAQ = [];
Screen = [];
TrialRecord = [];
varlist = [];
TaskObject = [];
cam_data = [];
cam_transparency = 30;
BaseDirectory = [fileparts(mfilename('fullpath')) filesep];
stimulus_dest = [tempdir 'mlstimuli' filesep];

SampleInterval = [];
current_trial = [];
current_frame = 0;
max_sample = 0;
max_frame = [];
playing = false;
stopped = false;

tracer_update = true;
nonvisual_time = [];
nonvisual_id = [];

% v1 specific
framebyframe = [];
movie_nframe = [];
movie_length = [];

% v2 specific
new_playback_position = false;
current_scene = 0;
param_ = [];
EyeCal = [];
Eye2Cal = [];
JoyCal = [];
Joy2Cal = [];
Tracker = [];
scene = [];
eye_ = [];
eye2_ = [];
joy_ = [];
joy2_ = [];
touch_ = [];
button_ = [];
mouse_ = [];
null_ = [];
adapterID = [];
adapterList = [];

hFig = [];
hTag = struct;
hTxt = struct;
hListener = [];
replica_pos = [];
export_size = [];
ControlScreenZoomRange = [5 300];
search_path = struct('base_path',[],'no_for_all',false,'no_for_all_webcam',false);
error_type_color = [0 1 0; 0 1 1; 1 1 0; 0 0 1; 0.5 0.5 0.5; 1 0 1; 1 0 0; .3 .7 .5; .7 .2 .5; .5 .5 1; .75 .75 .5];
error_type_str = {'Correct','No response','Late response','Break fixation','No fixation','Early response','Incorrect','Lever break','Ignored','Aborted'};
error_type = error_type_str;
TracerMenu = {'EyeNumber','EyeTracerShape','EyeTracerColor','EyeTracerSize','JoystickNumber','JoystickCursorImage','JoystickCursorShape', ...
    'JoystickCursorColor','JoystickCursorSize','TouchCursorImage','TouchCursorShape','TouchCursorColor','TouchCursorSize','MouseCursorType'};
load('mlimagedata.mat','reward_image','sound_triggered','stimulation_triggered','ttl_triggered');

init();

exception = [];
if exist('datafile','var')
    try
        enable_UI('off');
        set(hTag.PlayButton,'enable','inactive','string','Loading','backgroundcolor',[0.6392 0.2863 0.6431],'foregroundcolor',[1 1 1]); drawnow;
        if 1<nargin
            data = datafile;
            MLConfig = varargin{1};
            TrialRecord = varargin{2};
            datafile = varargin{3};
            varlist = varargin{4};
            load_data(0);
        else
            load_data(datafile);
        end
    catch exception
        data = [];
    end
    enable_UI('on');
end
update_UI();
if ~isempty(data) && ~playing, render_scene(); end
if ~isempty(exception), rethrow(exception); end

    function dummy_function(varargin), end
    function t = trialtime(), t = current_frame * Screen.FrameLength; end

    function render_scene(present)
        if ~exist('present','var'), present = true; end
        
        % nonvisual stimuli
        prev_event = floor(nonvisual_time / Screen.FrameLength) < current_frame;
        mglactivategraphic(nonvisual_id(~prev_event,:),false);
        mglactivategraphic(nonvisual_id(prev_event,:),true);
        
        % show cam video
        mglactivategraphic(Screen.Webcam,false);
        if iscell(cam_data) && get(hTag.CamVideo,'value')
            showLargeVideo = get(hTag.LargeVideo,'value');
            ncam = find(~cellfun(@isempty,cam_data),1,'last');
            for m=1:ncam
                if isempty(cam_data{m}), continue, end
                frame_no = find(cam_data{m}.Time < current_frame,1,'last');
                if isempty(frame_no), frame_no = 1; end
                
                framesize = size(cam_data{m}.Frame);
                if showLargeVideo
                    if present
                        mglsetproperty(Screen.CurrentPosition,'text',sprintf('Current position: %.0f ms',round(current_frame * Screen.FrameLength)));
                        viewsize = replica_pos(3:4) * Screen.DPI_ratio / fi(1==ncam,1,2);
                    else  % export as video
                        viewsize = export_size(1:2) * Screen.DPI_ratio / fi(1==ncam,1,2);
                    end
                    origin = [viewsize(1)*(mod(m-1,2)+0.5) viewsize(2)*(floor(m/3)+0.5)];
                else
                    if present
                        viewsize = replica_pos(3:4) * Screen.DPI_ratio / 4;
                    else
                        viewsize = export_size(1:2) * Screen.DPI_ratio / 4;
                    end
                    origin = [viewsize(1)*(m-0.5) viewsize(2)*0.5];
                end
                if viewsize(1)/viewsize(2) < framesize(2)/framesize(1), scale = viewsize(1)/framesize(2); else, scale = viewsize(2)/framesize(1); end
                if ~showLargeVideo, origin(2) = framesize(1) * scale * 0.5; end
                mglsetproperty(Screen.Webcam(m),'active',true,'bitmap',cat(3,round((100-cam_transparency)*2.55)*ones(framesize(1:2),'uint8'),cam_data{m}.Frame(:,:,:,frame_no)),'origin',origin,'scale',scale);
            end
        end
        
        % tracer update
        if tracer_update
            tracer_update = false;
            Screen.create_tracers(MLConfig);
            % The these tracers need reactivation, since they are activated only once when the scene starts.
            mglactivategraphic(Screen.EyeTracer,DAQ.eye_present);    
            mglactivategraphic(Screen.Eye2Tracer,DAQ.eye2_present);
            mglactivategraphic(Screen.JoystickCursor,DAQ.joystick_present);
            mglactivategraphic(Screen.Joystick2Cursor,DAQ.joystick2_present);
            mglactivategraphic(Screen.MouseCursor(2),DAQ.mouse_present);
        end
        
        aidata = data(current_trial).AnalogData;
        obj = data(current_trial).ObjectStatusRecord;
        all_visual = 1==TaskObject.Modality | 2==TaskObject.Modality;
        switch data(current_trial).Ver
            case 1
                mglsetproperty(Screen.CurrentPosition,'text',sprintf('Current position: %.0f ms',round(current_frame * Screen.FrameLength)));
                last_sample = min(round(current_frame * Screen.FrameLength / SampleInterval) + 1,max_sample);
                first_sample = min(round(max(0,current_frame-1) * Screen.FrameLength / SampleInterval) + 1,last_sample);
                
                if DAQ.eye_present
                    if Screen.EyeLineTracer
                        mglsetproperty(Screen.EyeTracer,'addpoint',EyeCal.deg2pix(aidata.Eye(first_sample:last_sample,:)));
                    else
                        mglsetorigin(Screen.EyeTracer,EyeCal.deg2pix(aidata.Eye(last_sample,:)));
                    end
                end
                if DAQ.eye2_present
                    if Screen.Eye2LineTracer
                        mglsetproperty(Screen.Eye2Tracer,'addpoint',Eye2Cal.deg2pix(aidata.Eye2(first_sample:last_sample,:)));
                    else
                        mglsetorigin(Screen.Eye2Tracer,EyeCal.deg2pix(aidata.Eye2(last_sample,:)));
                    end
                end
                if DAQ.joystick_present
                    mglsetorigin(Screen.JoystickCursor,JoyCal.deg2pix(aidata.Joystick(last_sample,:)));
                end
                if DAQ.joystick2_present
                    mglsetorigin(Screen.Joystick2Cursor,Joy2Cal.deg2pix(aidata.Joystick2(last_sample,:)));
                end
                if DAQ.touch_present
                    touch = reshape(aidata.Touch(last_sample,:),2,[])';
                    mglactivategraphic(Screen.TouchCursor(:,2),~isnan(touch(:,1)));
                    mglsetorigin(Screen.TouchCursor(:,2),EyeCal.deg2pix(touch));
                end
                if DAQ.mouse_present  % This is for old data files. trialholder_v1 does not use mouse as a tracker.
                    mouse = aidata.Mouse(last_sample,:);
                    xy = mouse(any(mouse(3:4)),1:2);
                    if ~isempty(xy)
                        mglactivategraphic(Screen.TouchCursor(1),true);
                        mglsetorigin(Screen.TouchCursor(1),EyeCal.deg2pix(xy));
                    else
                        mglactivategraphic(Screen.TouchCursor,false);
                    end
                end
                if DAQ.button_present
                    status = false(1,DAQ.nButton);
                    buttons_available = DAQ.buttons_available();
                    for m=buttons_available, status(m) = aidata.Button.(sprintf('Btn%d',m))(end); end
                    mglactivategraphic(Screen.ButtonPressed(buttons_available),status(buttons_available));
                    mglactivategraphic(Screen.ButtonReleased(buttons_available),~status(buttons_available));
                end
                
                frame_no = floor(obj.Time / Screen.FrameLength);
                prev_frame = frame_no < current_frame;
                last_update = find(prev_frame,1,'last');
                if isempty(last_update)
                    Screen.BackgroundColor = MLConfig.SubjectScreenBackground;
                    mglactivategraphic(TaskObject.ID,false);
                else
                    if isfield(obj,'BackgroundColor'), Screen.BackgroundColor = obj.BackgroundColor(last_update,:); end
                    
                    status = logical(obj.Status(last_update,:));
                    mglactivategraphic(TaskObject.ID(all_visual),status(all_visual));
                    if isfield(obj,'Scale'), if iscell(obj.Scale), TaskObject.Scale = obj.Scale{last_update,:}; else, TaskObject.Scale = repmat(obj.Scale(last_update,:)',1,2); end, end
                    if isfield(obj,'Angle'), TaskObject.Angle = obj.Angle(last_update,:); end
                    if isfield(obj,'Zorder'), TaskObject.Zorder = obj.Zorder(last_update,:); end
                    
                    active_visual = all_visual & status;
                    if any(active_visual)
                        for m=find(active_visual)
                            elapsed_frame = current_frame - frame_no(find(prev_frame & 1==diff([0; obj.Status(:,m)]),1,'last'));
                            
                            position = [];
                            frame = [];
                            if isfield(obj,'Info') && ~isempty(obj.Info)
                                info = obj.Info;
                                
                                if isfield(info,'Position') && ~isempty(info(last_update).Position) && ~isempty(info(last_update).Position{m})
                                    startposition = info(last_update).StartPosition(m);
                                    positionstep =  info(last_update).PositionStep(m);
                                    position_index = mod(startposition-1 + sign(positionstep) .* floor(elapsed_frame .* abs(positionstep)),size(info(last_update).Position{m},1)) + 1;
                                    position = info(last_update).Position{m}(position_index,:);
                                end
                                
                                if 2==TaskObject.Modality(m)  % if the 'Info' field exists and the stimulus is a movie, either MovieStartFrame or MovieStartTime field must exist.
                                    if framebyframe(m)
                                        startframe = info(last_update).MovieStartFrame(m);
                                        framestep =  info(last_update).MovieFrameStep(m);
                                        frameorder = info(last_update).MovieFrameOrder{m};
                                        frame = mod(startframe-1 + sign(framestep) .* floor(elapsed_frame .* abs(framestep)),movie_nframe(m)) + 1;
                                        if ~isempty(frameorder), frame = frameorder(frame); end
                                        mglsetproperty(TaskObject.ID(m),'setnextframe',frame);
                                    else
                                        frame = elapsed_frame / Screen.RefreshRate + info(last_update).MovieStartTime(m);
                                        if frame < movie_length(m) || mglgetproperty(TaskObject.ID(m),'looping')
                                            if new_playback_position, mglsetproperty(TaskObject.ID(m),'seek',frame); end
                                        else
                                            mglactivategraphic(TaskObject.ID(m),false);
                                        end
                                    end
                                end
                            end
                            
                            if isempty(position), position = obj.Position{last_update}(m,:); end
                            mglsetorigin(TaskObject.ID(m),Screen.SubjectScreenHalfSize + MLConfig.PixelsPerDegree.*position);
                            if isempty(frame) && 2==TaskObject.Modality(m)
                                frame = elapsed_frame / Screen.RefreshRate;
                                if frame < movie_length(m) || mglgetproperty(TaskObject.ID(m),'looping')
                                    if new_playback_position, mglsetproperty(TaskObject.ID(m),'seek',frame); end
                                else
                                    mglactivategraphic(TaskObject.ID(m),false);
                                end
                            end
                        end
                        new_playback_position = false;
                    end
                end
                
                mglsetscreencolor(2,fi(0==current_frame || current_frame==max_frame,[0.25 0.25 0.25],[0.1333 0.3333 0.5490]));
                mglrendergraphic(current_frame);
                
            otherwise  % 2, 2.1, 2.2, 3
                if isfield(obj,'Time'), Time = obj.Time; else, Time = [obj.SceneParam(:).Time]; end
                frame_no = ceil(Time / Screen.FrameLength);
                prev_frame = frame_no <= current_frame;
                scene_no = find(prev_frame,1,'last'); if isempty(scene_no), scene_no = 0; end
                if scene_no~=current_scene || new_playback_position
                    new_playback_position = false;
                    if ~isempty(scene), scene.fini(param_); scene = []; end
                    Tracker.fini(param_);
                    current_scene = scene_no;
                    
                    if 0==current_scene
                        current_frame = 0; set(hTag.Progressbar,'value',current_frame);
                        Screen.BackgroundColor = MLConfig.SubjectScreenBackground;
                        mglactivategraphic(TaskObject.ID,false);
                    else
                        current_frame = frame_no(current_scene); set(hTag.Progressbar,'value',current_frame);
                        param_.SceneStartTime = Time(scene_no);
                        param_.SceneStartFrame = current_frame;
                        param_.FrameNum = current_frame;
                        param_.reset();
                        
                        if iscell(obj.SceneParam)
                            Position = obj.Position{current_scene};
                            Screen.BackgroundColor = obj.BackgroundColor(current_scene,:);
                            Visual = obj.SceneParam{current_scene}.Visual;
                            Movie = obj.SceneParam{current_scene}.Movie;
                            nMovie = length(Movie);
                            if isfield(obj,'MovieCurrentPosition'), MovieCurrentPosition = obj.MovieCurrentPosition{current_scene}; else, MovieCurrentPosition = zeros(1,nMovie); end
                            MovieLooping = false(1,nMovie);
                            adapter = obj.SceneParam{current_scene}.AdapterList;
                            args = obj.SceneParam{current_scene}.AdapterArgs;
                        else
                            s = obj.SceneParam(current_scene);
                            Position = s.Position;
                            Screen.BackgroundColor = s.BackgroundColor;
                            Visual = s.Visual;
                            Movie = s.Movie;
                            nMovie = length(Movie);
                            MovieCurrentPosition = s.MovieCurrentPosition;
                            MovieLooping = s.MovieLooping;
                            if isfield(s,'Scale'), if numel(TaskObject.ID)==numel(s.Scale), TaskObject.Scale = repmat(s.Scale(:),1,2); else, TaskObject.Scale = s.Scale; end, end
                            if isfield(s,'Angle'), TaskObject.Angle = s.Angle; end
                            if isfield(s,'Zorder'), TaskObject.Zorder = s.Zorder; end
                            adapter = s.AdapterList;
                            args = s.AdapterArgs;
                            if isfield(s,'Cursor'), param_.Cursor = s.Cursor; end
                            param_.User.CustomTrackers = get(hTag.CustomTracers,'value');
                        end
                        TaskObject.Position = Position;
                        mglactivategraphic(TaskObject.ID(all_visual),false);
                        mglactivategraphic(TaskObject.ID(Visual),true);
                        for m=1:nMovie, mglsetproperty(TaskObject.ID(Movie(m)),'seek',MovieCurrentPosition(m),'looping',MovieLooping(m)); end
                        scene = reconstruct_adapter(adapter,args);
                        
                        Tracker.init(param_);
                        scene.init(param_);
                    end
                end
                
                mglsetproperty(Screen.CurrentPosition,'text',sprintf('Current position: %.0f ms, Scene: %d',round(current_frame * Screen.FrameLength),current_scene));
                last_sample = min(round(current_frame * Screen.FrameLength / SampleInterval) + 1,max_sample);
                first_sample = min(round(max(0,current_frame-1) * Screen.FrameLength / SampleInterval) + 1,last_sample);
                DAQ.nSampleFromMarker = first_sample-1;
                
                if DAQ.eye_present, DAQ.Eye = aidata.Eye(first_sample:last_sample,:); end
                if DAQ.eye2_present, DAQ.Eye2 = aidata.Eye2(first_sample:last_sample,:); end
                if DAQ.joystick_present, DAQ.Joystick = aidata.Joystick(first_sample:last_sample,:); end
                if DAQ.joystick2_present, DAQ.Joystick2 = aidata.Joystick2(first_sample:last_sample,:); end
                DAQ.Button = cell(1,DAQ.nButton); for m=DAQ.buttons_available(), DAQ.Button{m} = aidata.Button.(sprintf('Btn%d',m))(first_sample:last_sample); end
                DAQ.General = cell(1,DAQ.nGeneral); for m=DAQ.general_available(), DAQ.General{m} = aidata.General.(sprintf('Gen%d',m))(first_sample:last_sample); end
                if DAQ.touch_present, DAQ.Touch = aidata.Touch(first_sample:last_sample,:); end
                if DAQ.mouse_present
                    DAQ.Mouse = aidata.Mouse(first_sample:last_sample,1:2);
                    DAQ.MouseButton = logical(aidata.Mouse(first_sample:last_sample,3:4));
                    if DAQ.keyinput_present, DAQ.KeyInput = aidata.KeyInput(first_sample:last_sample,:); end
                end
                
                param_.FrameNum = current_frame;
                Tracker.acquire(param_);
                if ~isempty(scene)
                    scene.analyze(param_);
                    scene.draw(param_);
                    param_.LastFlipTime = trialtime();
                    if isnan(param_.FirstFlipTime), param_.FirstFlipTime = param_.LastFlipTime; end
                end
                
                mglsetscreencolor(2,fi(0==current_frame || current_frame==max_frame,[0.25 0.25 0.25],[0.1333 0.3333 0.5490]));
                mglrendergraphic(current_frame);
        end
        
        if present, mglpresent; end
    end

    function o = reconstruct_adapter(adapter,args)
        nadapter = length(adapter);
        for m=1:nadapter
            if ~isempty(args{m}) && (isstruct(args{m}{1}) || isa(args{m}{1},'SceneParam'))  % adapter aggregator
                try
                    idx = [];
                    if 3<data(current_trial).Ver  % if AdapterID is used
                        a = find(strcmp(args{m}{end}(:,1),'AdapterID'),1);  % args{m}{end} is always a cell because of AdapterID in this version
                        idx = find(args{m}{end}{a,2}==adapterID,1);
                    end
                    if iscell(args{m}{end}), ns = length(args{m})-1; else, ns = length(args{m}); end
                    s = cell(1,ns); for n=1:ns, s{n} = reconstruct_adapter(args{m}{n}.AdapterList,args{m}{n}.AdapterArgs); end
                    if isempty(idx), o = eval([adapter{m} '(s)']); else, o = adapterList{idx}.replace(s); end
                    if iscell(args{m}{end}), o.import(args{m}{end}); end
                    if isempty(idx) && 3<data(current_trial).Ver, adapterID(end+1) = o.AdapterID; adapterList{end+1} = o; end
                catch err
                    rethrow(err);
                end
            else
                switch adapter{m}
                    case 'EyeTracker', if isempty(eye_), error('The datafile does not contain eye data.'); else, o = eye_; end
                    case 'Eye2Tracker', if isempty(eye2_), error('The datafile does not contain eye2 data.'); else, o = eye2_; end
                    case 'JoyTracker', if isempty(joy_), error('The datafile does not contain joystick data.'); else, o = joy_; end
                    case 'Joy2Tracker', if isempty(joy2_), error('The datafile does not contain joystick2 data.'); else, o = joy2_; end
                    case 'ButtonTracker', if isempty(button_), error('The datafile does not contain button data.'); else, o = button_; end
                    case 'TouchTracker', if isempty(touch_), error('The datafile does not contain touch data.'); else, o = touch_; end
                    case 'MouseTracker', if isempty(mouse_), error('The datafile does not contain mouse data.'); else, o = mouse_; end
                    case 'NullTracker', o = null_;
                    otherwise
                        try
                            idx = [];
                            if 3<data(current_trial).Ver
                                a = find(strcmp(args{m}(:,1),'AdapterID'),1);
                                idx = find(args{m}{a,2}==adapterID,1);
                            end
                            if isempty(idx), o = eval([adapter{m} '(o)']); else, o = adapterList{idx}.replace(o); end
                            o.import(args{m});
                            if isempty(idx) && 3<data(current_trial).Ver, adapterID(end+1) = o.AdapterID; adapterList{end+1} = o; end
                        catch err
                            if any(strcmp(err.identifier,{'MATLAB:UndefinedFunction';'MATLAB:class:undefinedMethod'}))
                                filepath = validate_path([adapter{m} '.m']);
                                if ~isempty(filepath)
                                    addpath(fileparts(filepath));
                                    o = eval([adapter{m} '(o)']); o.import(args{m});
                                else
                                    warning('The %s adapter is missing. The task may not be replayed well.',adapter{m});
                                end
                            else
                                rethrow(err);
                            end
                        end
                end
            end
        end
    end

    function export_video()
        mglsetcontrolscreenshow(false);
        e = '.mp4'; compression = 'MPEG-4';
        [n,p] = uiputfile({['*' e],[compression ' (*' e ')']},'Save as');
        if isnumeric(n), mglsetcontrolscreenshow(true); return, end
        filename = [p n];
        
        v = [];
        wb = [];
        err = [];
        try
            mglsetcontrolscreenrect(Pos2Rect([replica_pos(1:2) export_size]));
            mglsetcontrolscreenzoom(1);
            Screen.reposition_icons(MLConfig);
            init_trial(true,false);
            frame = current_frame;
            mglsetproperty([Screen.EyeTracer Screen.Eye2Tracer],'clear');
            mglactivategraphic(Screen.CurrentPosition,false);
            
            current_frame = 0;
            v = VideoWriter(filename,compression);
            set(v,'FrameRate',Screen.RefreshRate);
            open(v);
            set_on_move([]);
            wb = waitbar(current_frame/max_frame,sprintf('%d / %d frames',current_frame,max_frame),'Name',sprintf('Writing %s',[p n]));
            while current_frame <= max_frame
                render_scene(false);
                writeVideo(v,mglgetscreenbuffer(2));
                waitbar(current_frame/max_frame,wb,sprintf('%3d / %3d frames',current_frame,max_frame));
                current_frame = current_frame + 1;
            end
        catch err
        end
        if ~isempty(v), close(v); end
        if ~isempty(wb), close(wb); end
        set_on_move();
        
        mglsetcontrolscreenrect(Pos2Rect(replica_pos));
        mglsetcontrolscreenzoom(MLConfig.ControlScreenZoom/100);
        Screen.reposition_icons(MLConfig);
        init_trial(false,false);
        current_frame = frame;
        mglsetproperty([Screen.EyeTracer Screen.Eye2Tracer],'clear');
        mglactivategraphic(Screen.CurrentPosition,true);
        render_scene();
        
        mglsetcontrolscreenshow(true);
        if ~isempty(err), rethrow(err); end
    end

    function init_trial(export,reload_webcam)
        if ~exist('export','var'), export = false; end
        if ~exist('reload_webcam','var'), reload_webcam = true; end
        playing = false;
        
        aidata = data(current_trial).AnalogData;
        taskobject = data(current_trial).TaskObject;
        adapterID = [];
        adapterList = [];
        
        % rebuild TrialRecord
        block = [data(1:current_trial).Block];
        trialrecord.CurrentTrialNumber = data(current_trial).Trial;
        trialrecord.CurrentTrialWithinBlock = data(current_trial).TrialWithinBlock;
        trialrecord.CurrentCondition = data(current_trial).Condition;
        trialrecord.CurrentBlock = data(current_trial).Block;
        trialrecord.CurrentBlockCount = sum(diff([0 block]));
        if isfield(taskobject,'CurrentConditionInfo'), trialrecord.CurrentConditionInfo = taskobject.CurrentConditionInfo; else, trialrecord.CurrentConditionInfo = []; end
        trialrecord.ConditionsPlayed = [data(1:current_trial-1).Condition];
        trialrecord.ConditionsThisBlock = [];  % this field is not reconstructable
        trialrecord.BlocksPlayed = [data(1:current_trial-1).Block];
        trialrecord.BlockCount = cumsum(diff([0 block(1:end-1)]));
        trialrecord.BlockOrder = block(0<(diff([0 block])));
        trialrecord.BlocksSelected = MLConfig.BlocksToRun;
        trialrecord.TrialErrors = [data(1:current_trial-1).TrialError];
        trialrecord.ReactionTimes = [data(1:current_trial-1).ReactionTime];
        if 1<current_trial
            trialrecord.LastTrialAnalogData = data(current_trial-1).AnalogData;
            trialrecord.LastTrialCodes = data(current_trial-1).BehavioralCodes;
        else
            trialrecord.LastTrialAnalogData = [];
            trialrecord.LastTrialCodes = [];
        end
        
        EyeCal = mlcalibrate('eye',MLConfig,1);
        Eye2Cal = mlcalibrate('eye',MLConfig,2);
        JoyCal = mlcalibrate('joy',MLConfig,1);
        Joy2Cal = mlcalibrate('joy',MLConfig,2);
        
        obj = data(current_trial).ObjectStatusRecord;
        mglsetproperty([Screen.EyeTracer Screen.Eye2Tracer],'clear');
        nsample = floor(data(current_trial).BehavioralCodes.CodeTimes(end)/SampleInterval);
        if DAQ.eye_present, nsample = [nsample size(aidata.Eye,1)]; end
        if DAQ.eye2_present, nsample = [nsample size(aidata.Eye2,1)]; end
        if DAQ.joystick_present, nsample = [nsample size(aidata.Joystick,1)]; end
        if DAQ.joystick2_present, nsample = [nsample size(aidata.Joystick2,1)]; end
        for m=DAQ.buttons_available(), nsample = [nsample size(aidata.Button.(sprintf('Btn%d',m)),1)]; end
        for m=DAQ.general_available(), nsample = [nsample size(aidata.General.(sprintf('Gen%d',m)),1)]; end
        if DAQ.touch_present, nsample = [nsample size(aidata.Touch,1)]; end
        if DAQ.mouse_present, nsample = [nsample size(aidata.Mouse,1)]; end
        max_sample = min(nsample(0<nsample));
        max_frame = floor(max_sample * SampleInterval / Screen.FrameLength) + 1;
        current_frame = 0;
        set(hTag.Progressbar,'min',0,'max',max_frame,'value',current_frame);
        
        % create TaskObject
        if ~isempty(scene), scene.fini(param_); scene = []; end  % fini before recreating TaskObject
        if isfield(taskobject,'Attribute'), C = taskobject.Attribute; else, C = taskobject; end
        if iscell(C) && ischar(C{1}), C = {C}; end
        ntaskobj = length(C);
        if ~isempty(TaskObject), delete(TaskObject); end
        TaskObject = mltaskobject_playback(C,MLConfig);
        if isfield(taskobject,'Size'), TaskObject.Size = taskobject.Size; else, TaskObject.Size = 50 * ones(ntaskobj,2); end
        createobj(TaskObject,C,MLConfig,trialrecord,@validate_path);
        
        nonvisual = [];
        switch data(current_trial).Ver
            case 1
                if ~isempty(obj.Position)
                    TaskObject.Position = obj.Position{1};
                    status = 1==diff([zeros(1,ntaskobj); obj.Status]);
                    for m=1:ntaskobj
                        if ~any(status(:,m)), continue, end
                        switch TaskObject.Modality(m)
                            case 3, row = obj.Time(status(:,m)); row(:,2) = m; row(:,3) = 3;
                            case 4, row = obj.Time(status(:,m)); row(:,2) = m; row(:,3) = 4;
                            case 5, row = obj.Time(status(:,m)); row(:,2) = m; row(:,3) = 5;
                            otherwise, row = [];
                        end
                        nonvisual = [nonvisual; row];
                    end
                end
                
                movie = 2==TaskObject.Modality;
                if isfield(taskobject,'FrameByFrameMovie')
                    framebyframe = logical(taskobject.FrameByFrameMovie);
                    mglsetproperty(TaskObject.ID(framebyframe),'framebyframe');
                else
                    framebyframe = false(1,ntaskobj);
                end
                
                if any(movie)
                    movie_nframe = zeros(1,ntaskobj);
                    movie_length = zeros(1,ntaskobj);
                    for m=find(movie)
                        mov = mglgetproperty(TaskObject.ID(m),'info');
                        movie_nframe(m) = mov.TotalFrames;
                        movie_length(m) = mov.Duration;
                    end
                end
            otherwise  % 2, 2.1, 2.2, 3
                if isfield(obj,'Position')
                    if ~isempty(obj.Position), TaskObject.Position = obj.Position{1}; end
                else
                    TaskObject.Position = obj.SceneParam(1).Position;
                end
                if ~isempty(Tracker), Tracker.fini(param_); end
                
                param_ = RunSceneParam(MLConfig);
                param_.Screen = Screen;
                param_.DAQ = DAQ;
                param_.TaskObject = TaskObject;
                param_.Mouse = [];
                param_.SimulationMode = false;
                param_.trialtime = @trialtime;
                param_.goodmonkey = @dummy_function;
                param_.dashboard = @dummy_function;
                param_.Cursor.ShowJoy = [false DAQ.joystick_present];
                param_.Cursor.ShowJoy2 = [false DAQ.joystick2_present];
                param_.Cursor.ShowTouch = [false DAQ.touch_present];
                
                Tracker = TrackerAggregate();
                if DAQ.eye_present, eye_ = EyeTracker(MLConfig,TaskObject,EyeCal,2,@validate_path); Tracker.add(eye_); end
                if DAQ.eye2_present, eye2_ = Eye2Tracker(MLConfig,TaskObject,Eye2Cal,2,@validate_path); Tracker.add(eye2_); end
                if DAQ.joystick_present, joy_ = JoyTracker(MLConfig,TaskObject,JoyCal,2,param_,@validate_path); Tracker.add(joy_); end
                if DAQ.joystick2_present, joy2_ = Joy2Tracker(MLConfig,TaskObject,Joy2Cal,2,param_,@validate_path); Tracker.add(joy2_); end
                if DAQ.button_present, button_ = ButtonTracker(MLConfig,TaskObject,EyeCal,2,@validate_path); Tracker.add(button_); end
                if DAQ.touch_present, touch_ = TouchTracker(MLConfig,TaskObject,EyeCal,2,param_,@validate_path); Tracker.add(touch_); end
                if DAQ.mouse_present
                    switch data(current_trial).Ver
                        case {2,2.1}, touch_ = TouchTracker_v1(MLConfig,TaskObject,EyeCal,2,@validate_path); Tracker.add(touch_);
                        otherwise, mouse_ = MouseTracker(MLConfig,TaskObject,EyeCal,2,param_,@validate_path); Tracker.add(mouse_);
                    end
                end
                null_ = NullTracker(MLConfig,TaskObject,EyeCal,2,@validate_path);
                
                current_scene = 0;
                nscene = length(obj.SceneParam);
                for m=1:nscene
                    if iscell(obj.SceneParam)
                        t = obj.Time(m);
                        sound = obj.SceneParam{m}.Sound';
                        STM = obj.SceneParam{m}.STM';
                        TTL = obj.SceneParam{m}.TTL';
                    else
                        t = obj.SceneParam(m).Time;
                        sound = obj.SceneParam(m).Sound';
                        STM = obj.SceneParam(m).STM';
                        TTL = obj.SceneParam(m).TTL';
                    end
                    
                    if ~isempty(sound), sound = [repmat(t,length(sound),1) sound]; sound(:,3) = 3; end %#ok<*AGROW>
                    if ~isempty(STM), STM = [repmat(t,length(STM),1) STM]; STM(:,3) = 4; end
                    if ~isempty(TTL), TTL = [repmat(t,length(TTL),1) TTL]; TTL(:,3) = 5; end
                    nonvisual = [nonvisual; sound; STM; TTL];
                end
        end
        reward = data(current_trial).RewardRecord.StartTimes;
        if isempty(reward), reward = zeros(0,1); end  % 0x1 empty can be indexed with subscripts, which makes it unnecessary to test whether nonvisual_* is empty
        reward(:,3) = 0; reward(:,2) = ntaskobj+1;
        nonvisual = [nonvisual; reward];
        [~,idx] = sort(nonvisual(:,1));
        nonvisual = nonvisual(idx,:);
        nonvisual_time = nonvisual(:,1);
        
        if export
            device = 2;
            scale = Screen.Xsize / replica_pos(3);
            width = Screen.Xsize / scale;
        else
            device = 4;
            scale = Screen.DPI_ratio;
            width = replica_pos(3);
        end
        
        mgldestroygraphic(nonvisual_id); nonvisual_id = NaN(size(nonvisual,1),2);
        for m=1:size(nonvisual,1)
            switch nonvisual(m,3)
                case 0, nonvisual_id(m,1) = mgladdbitmap(mglimresize(reward_image,scale),device);          % nonvisual_id(m,2) = mgladdtext('Reward',device);
                case 3, nonvisual_id(m,1) = mgladdbitmap(mglimresize(sound_triggered,scale),device);       nonvisual_id(m,2) = mgladdtext(TaskObject.Label{nonvisual(m,2)},device);
                case 4, nonvisual_id(m,1) = mgladdbitmap(mglimresize(stimulation_triggered,scale),device); nonvisual_id(m,2) = mgladdtext(TaskObject.Label{nonvisual(m,2)},device);
                case 5
                    no = str2double(regexp(TaskObject.Label{nonvisual(m,2)},'\d+','match'));
                    if DAQ.TTLInvert(no)
                        nonvisual_id(m,1) = mgladdbitmap(mglimresize(ttl_triggered(end:-1:1,:,:,:),scale),device);
                    else
                        nonvisual_id(m,1) = mgladdbitmap(mglimresize(ttl_triggered,scale),device);
                    end
                    nonvisual_id(m,2) = mgladdtext(TaskObject.Label{nonvisual(m,2)},device);
            end
            mglsetproperty(nonvisual_id(m,1),'origin',[width-25 m*40] * scale,'zorder','front');
            mglsetproperty(nonvisual_id(m,2),'active',false,'origin',[width-50 m*40] * scale,'right','middle','fontsize',12,'zorder','front');
        end
        
        % load cam_data
        if reload_webcam && iscell(cam_data)
            for m=1:DAQ.nWebcam
                err = [];
                try
                    [cam_data{m}.Frame,cam_data{m}.Time] = mlreadsignal(sprintf('webcam%d',m),current_trial,datafile);
                catch err
                    if strcmp(err.identifier,'mlreadsignal:filenotfound') && ~search_path.no_for_all_webcam
                        videoname = err.message(1:find(' '==err.message,1)-1);
                        err = [];
                        mglsetcontrolscreenshow(false);
                        options.Interpreter = 'tex';
                        options.Default = 'Yes';
                        qstring = ['\fontsize{10}Can''t find the file, ''' regexprep(videoname,'([\^_\\])','\\$1'), '''.' newline 'Would you like to manually locate it?'];
                        button = questdlg(qstring,'Missing webcam video','Yes','No','No for all',options);
                        switch button
                            case 'Yes'
                                [n,p] = uigetfile(videoname);
                                if 0~=n
                                    try
                                        [cam_data{m}.Frame,cam_data{m}.Time] = mlreadsignal(sprintf('webcam%d',m),current_trial,datafile,p);
                                        if ispref('NIMH_MonkeyLogic','SearchPath'), p = [p getpref('NIMH_MonkeyLogic','SearchPath')]; else, p = {p}; end
                                        setpref('NIMH_MonkeyLogic','SearchPath',p);
                                    catch err
                                    end
                                end
                            case 'No for all', search_path.no_for_all_webcam = true;
                        end
                        mglsetcontrolscreenshow(true);
                    end
                end
                if ~isempty(err), warning(err.identifier,'%s',err.message); continue, end
                if ~isempty(cam_data{m})
                    if isempty(cam_data{m}.Frame), cam_data{m} = []; continue, end
                    cam_data{m}.Time = floor(cam_data{m}.Time / Screen.FrameLength);
                end
            end
        end
    end

    function load_data(filename)
        if ~exist('filename','var'), filename = ''; end
        delete([stimulus_dest '*.*']); load([BaseDirectory 'mlimagedata.mat'],'missing_image'); mglpngwrite(missing_image,[stimulus_dest 'missing_image']);
        if ischar(filename)
            try
                mglsetcontrolscreenshow(false);
                [data,config,TrialRecord,datafile,varlist] = mlread(filename);
                mglsetcontrolscreenshow(true);
                mlexportstim(stimulus_dest,datafile);
            catch err
                mglsetcontrolscreenshow(true);
                rethrow(err);
            end
            if ~isempty(MLConfig)
                config = copyfield(config,MLConfig,{'EyeTracerShape','EyeTracerColor','EyeTracerSize', ...
                    'JoystickCursorImage','JoystickCursorShape','JoystickCursorColor','JoystickCursorSize', ...
                    'TouchCursorImage','TouchCursorShape','TouchCursorColor','TouchCursorSize', ...
                    'ControlScreenZoom'});
            end
            MLConfig = config;
        end
        if isempty(data), return; end
        [p,n,e] = fileparts(datafile);
        
        % search_path should be defined before calling validate_path()
        search_path.base_path = {stimulus_dest};
        search_path.base_path{end+1} = [pwd filesep];
        search_path.base_path{end+1} = BaseDirectory;
        d = [BaseDirectory 'mgl' filesep]; if exist(d,'dir'), search_path.base_path{end+1} = d; end
        if isfield(MLConfig,'MLPath')
            d = MLConfig.MLPath.ExperimentDirectory; if exist(d,'dir'), search_path.base_path{end+1} = d; end
        end
        search_path.no_for_all = false;
        search_path.no_for_all_webcam = false;
        
        MLConfig.FixationPointImage = validate_path(MLConfig.FixationPointImage);
        MLConfig.JoystickCursorImage{1} = validate_path(MLConfig.JoystickCursorImage{1});
        MLConfig.JoystickCursorImage{2} = validate_path(MLConfig.JoystickCursorImage{2});
        MLConfig.TouchCursorImage = validate_path(MLConfig.TouchCursorImage);
        MLConfig.DAQ = DAQ; create(DAQ,MLConfig,data(1).AnalogData);
        create(Screen,MLConfig); MLConfig.Screen = Screen;
        mglsetcontrolscreenzoom(MLConfig.ControlScreenZoom/100);
        SampleInterval = 1000 / MLConfig.AISampleRate;
        if isfield(TrialRecord,'TaskInfo') && isfield(TrialRecord.TaskInfo,'TrialErrorCodes'), error_type = TrialRecord.TaskInfo.TrialErrorCodes; else, error_type = error_type_str; end
        
        video = [80 160 320 640 800 1024] * Screen.DPI_ratio;
        video(video<300|1300<video) = [];
        video = unique([video Screen.Xsize/2 Screen.Xsize]');
        video(:,2) = video./Screen.SubjectScreenAspectRatio;
        video = video(all(video==round(video),2),:);
        export_size = cell(1,size(video,1));
        for m=1:size(video,1), export_size{m} = sprintf('%d x %d',video(m,:)); end
        set(hTag.ExportSize,'string',export_size);
        export_size = video(1,:);
        
        current_trial = 1;
        if ~isempty(p), cd(p); end
        set(gcf,'name',['MonkeyLogic Player: ' n e]);
        Trial = [data.Trial]; nTrial = length(Trial); TrialError = [data.TrialError]; str = cell(nTrial,1);
        for m=1:nTrial
            color = round(error_type_color(TrialError(m)+1,:)*255);
            str{m} = sprintf('<html><font color="rgb(%d,%d,%d)">%d</font></html>',color,Trial(m));
        end
        set(hTag.TrialList,'string',str,'value',current_trial);
        
        cam_data = fi(any(strncmp(varlist,'Cam',3)),cell(1,DAQ.nWebcam),[]);
        tracer_update = true;
        
        init_trial();
    end

    function update_UI()
        set(hTag.LoadButton,'enable','on');
        enable = fi(isempty(data),'off','on');
        set(hTag.Progressbar,'enable',enable,'value',current_frame);
        if isempty(data)
            set(hTag.PlayButton,'string','Play','backgroundcolor',[0.94 0.94 0.94],'foregroundcolor',[1 1 1]);
        else
            set(hTag.PlayButton,'string',fi(playing,'Stop','Play'),'backgroundcolor',fi(playing,[1 0 0],[0 1 0]),'foregroundcolor',[0 0 0]);
        end
        set([hTag.PlayButton hTag.TrialList hTag.ExportSize hTag.ExportButton],'enable',enable);
        if isempty(data), return, end
        
        set(hTag.ScreenZoom1,'string',num2str(MLConfig.ControlScreenZoom));
        set(hTag.ScreenZoom2,'value',MLConfig.ControlScreenZoom);
        
        if get(hTag.CustomTracers,'value')
            eyenum = get(hTag.EyeNumber,'value');
            MLConfig.EyeTracerShape{eyenum} = set_listbox_value(hTag.EyeTracerShape,MLConfig.EyeTracerShape{eyenum});
            set_button_color(hTag.EyeTracerColor,MLConfig.EyeTracerColor(eyenum,:));
            set(hTag.EyeTracerSize,'string',num2str(MLConfig.EyeTracerSize(eyenum)),'enable',fi(strcmp(MLConfig.EyeTracerShape(eyenum),'Line'),'off','on'));
            
            joynum = get(hTag.JoystickNumber,'value');
            set(hTag.JoystickCursorImage,'string',strip_path(MLConfig.JoystickCursorImage{joynum},'Select a(n) image/movie'));
            enable = fi(isempty(MLConfig.JoystickCursorImage{joynum}),'on','off');
            MLConfig.JoystickCursorShape{joynum} = set_listbox_value(hTag.JoystickCursorShape,MLConfig.JoystickCursorShape{joynum},'enable',enable);
            set_button_color(hTag.JoystickCursorColor,MLConfig.JoystickCursorColor(joynum,:),'enable',enable);
            set(hTag.JoystickCursorSize,'string',num2str(MLConfig.JoystickCursorSize(joynum)),'enable',enable);
            
            set(hTag.TouchCursorImage,'string',strip_path(MLConfig.TouchCursorImage,'Select a(n) image/movie'));
            enable = fi(isempty(MLConfig.TouchCursorImage),'on','off');
            MLConfig.TouchCursorShape = set_listbox_value(hTag.TouchCursorShape,MLConfig.TouchCursorShape,'enable',enable);
            set_button_color(hTag.TouchCursorColor,MLConfig.TouchCursorColor,'enable',enable);
            set(hTag.TouchCursorSize,'string',num2str(MLConfig.TouchCursorSize),'enable',enable);
            
            set(hTag.MouseCursorType,'value',MLConfig.MouseCursorType);
        end
        
        set(hTag.CamVideo,'enable',fi(iscell(cam_data),'on','off'));
        enable = fi(iscell(cam_data) & get(hTag.CamVideo,'value'),'on','off');
        set(hTag.LargeVideoStr,'enable',enable);
        set(hTag.LargeVideo,'enable',enable);
        set(hTag.Transparency(2),'enable',enable,'string',num2str(cam_transparency));
        set(hTag.Transparency(3),'enable',enable,'value',cam_transparency);
        
        set(hTag.Block,'string',data(current_trial).Block);
        set(hTag.TrialWithinBlock,'string',data(current_trial).TrialWithinBlock);
        set(hTag.Condition,'string',data(current_trial).Condition);
        TrialError = data(current_trial).TrialError;
        if 0<=TrialError && TrialError<=9
            set(hTag.TrialError,'string',sprintf('%s (%d)',error_type{TrialError+1},TrialError),'backgroundcolor',error_type_color(TrialError+1,:),'foregroundcolor',fi(3==TrialError,[1 1 1],[0 0 0]));
        else
            set(hTag.TrialError,'string',TrialError,'backgroundcolor',[0.9255 0.9137 0.8471],'foregroundcolor',[0 0 0]);
        end
        set(hTag.ReactionTime,'string',round(data(current_trial).ReactionTime));
        time = data(current_trial).BehavioralCodes.CodeTimes;
        if ~isempty(time)
            num = data(current_trial).BehavioralCodes.CodeNumbers;
            if isfield(TrialRecord,'TaskInfo') && isfield(TrialRecord.TaskInfo,'BehavioralCodes')
                [a,b] = ismember(num,TrialRecord.TaskInfo.BehavioralCodes.CodeNumbers);
                codenames = [TrialRecord.TaskInfo.BehavioralCodes.CodeNames; {''}];
                b(~a) = length(codenames);
                code = codenames(b);
            else
                code = cell(length(num),1);
            end
            for m=1:length(num)
                code{m} = sprintf('%.0f [%d] %s',time(m),num(m),code{m});
            end
            ncode = get(hTag.BehavioralCodes,'value');
            if size(code,1) < ncode, ncode = 1; end
            set(hTag.BehavioralCodes,'value',ncode,'string',code);
        end
    end
    function enable_UI(enable)
        if ~exist('enable','var'), enable = 'on'; end
        if strcmpi(enable,'on') && isempty(data), return, end
        for m=fields(hTag)', set(hTag.(m{1}),'enable',enable); end
        if strcmpi(enable,'off'), return, end
        enable = fi(get(hTag.CustomTracers,'value'),'on','off');
        set(hTxt.Text([3:10 21:23]),'enable',enable);
        for m=TracerMenu, set(hTag.(m{1}),'enable',enable); end
    end

    function UIcallback(hObject,~)
        err = [];
        obj_tag = get(hObject,'tag');
        switch obj_tag
            case 'ScreenZoom1'
                val = round(str2double(get(gcbo,'string')));
                if ControlScreenZoomRange(1)<=val && val<=ControlScreenZoomRange(2), MLConfig.ControlScreenZoom = val; end
                mglsetcontrolscreenzoom(MLConfig.ControlScreenZoom/100);
            case 'ScreenZoom2'
                val = round(get(gcbo,'value'));
                if ControlScreenZoomRange(1)<=val && val<=ControlScreenZoomRange(2), MLConfig.ControlScreenZoom = val; end
                mglsetcontrolscreenzoom(MLConfig.ControlScreenZoom/100);
            case 'CustomTracers'
                tracer_update = get(gcbo,'value');
                enable_UI('on');
            case {'EyeTracerShape','JoystickCursorShape'}
                item = get(gcbo,'string');
                val = item{get(gcbo,'value')};
                no = get(fi(strncmp(obj_tag,'Eye',3),hTag.EyeNumber,hTag.JoystickNumber),'value');
                if ~strcmp(val,MLConfig.(obj_tag){no}), MLConfig.(obj_tag){no} = val; tracer_update = true; end
            case {'EyeTracerColor','JoystickCursorColor'}
                mglsetcontrolscreenshow(false);
                no = get(fi(strncmp(obj_tag,'Eye',3),hTag.EyeNumber,hTag.JoystickNumber),'value');
                val = uisetcolor(MLConfig.(obj_tag)(no,:),'Pick up a color');
                if any(val~=MLConfig.(obj_tag)(no,:)), MLConfig.(obj_tag)(no,:) = val; tracer_update = true; end
                mglsetcontrolscreenshow(true);
            case {'EyeTracerSize','JoystickCursorSize'}
                val = str2double(get(gcbo,'string'));
                no = get(fi(strncmp(obj_tag,'Eye',3),hTag.EyeNumber,hTag.JoystickNumber),'value');
                if val~=MLConfig.(obj_tag)(no), MLConfig.(obj_tag)(no) = val; tracer_update = true; end
            case 'JoystickCursorImage'
                mglsetcontrolscreenshow(false);
                joynum = get(hTag.JoystickNumber,'value');
                [filename,filepath] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.gif;*.mp4;*.avi;*.mpg;*.mpeg','Image/Movie Files'; '*.*','All Files'},'Select a(n) image/movie file',fileparts(MLConfig.(obj_tag){joynum}));
                val = fi(0==filename,'',[filepath filename]);
                if ~strcmp(val,MLConfig.(obj_tag){joynum}), MLConfig.(obj_tag){joynum} = val; tracer_update = true; end
                mglsetcontrolscreenshow(true);
            case 'TouchCursorShape'
                item = get(gcbo,'string');
                val = item{get(gcbo,'value')};
                if ~strcmp(val,MLConfig.(obj_tag)), MLConfig.(obj_tag) = val; tracer_update = true; end
            case 'TouchCursorColor'
                mglsetcontrolscreenshow(false);
                val = uisetcolor(MLConfig.(obj_tag),'Pick up a color');
                if any(val~=MLConfig.(obj_tag)), MLConfig.(obj_tag) = val; tracer_update = true; end
                mglsetcontrolscreenshow(true);
            case 'TouchCursorSize'
                val = str2double(get(gcbo,'string'));
                if val~=MLConfig.(obj_tag), MLConfig.(obj_tag) = val; tracer_update = true; end
            case 'TouchCursorImage'
                mglsetcontrolscreenshow(false);
                [filename,filepath] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.gif;*.mp4;*.avi;*.mpg;*.mpeg','Image/Movie Files'; '*.*','All Files'},'Select a(n) image/movie file',fileparts(MLConfig.(obj_tag)));
                val = fi(0==filename,'',[filepath filename]);
                if ~strcmp(val,MLConfig.(obj_tag)), MLConfig.(obj_tag) = val; tracer_update = true; end
                mglsetcontrolscreenshow(true);
            case 'MouseCursorType'
                val = get(gcbo,'value');
                if val~=MLConfig.(obj_tag), MLConfig.(obj_tag) = val; tracer_update = true; end
            case 'Transparency1'
                val = round(str2double(get(gcbo,'string')));
                if 0<=val && val<=100, cam_transparency = val; end
            case 'Transparency2'
                val = round(get(gcbo,'value'));
                if 0<=val && val<=100, cam_transparency = val; end
            case 'TrialList'
                try
                    val = get(gcbo,'value');
                    if isempty(val) || val==current_trial, return, end  % val can be empty sometimes.
                    enable_UI('off');
                    set(hTag.PlayButton,'enable','inactive','string','Loading','backgroundcolor',[0.6392 0.2863 0.6431],'foregroundcolor',[1 1 1]);
                    drawnow;
                    current_trial = val;
                    stopped = true;
                    init_trial();
                catch err
                end
                enable_UI('on');
            case 'ProgressBar'
                current_frame = round(get(gcbo,'value'));
                mglsetproperty([Screen.EyeTracer Screen.Eye2Tracer],'clear');
                new_playback_position = true;
            case 'PlayButton'
                playing = ~playing;
                if playing
                    stopped = false;
                    set(gcbo,'string','Stop','backgroundcolor',[1 0 0]); drawnow;
                    if current_frame==max_frame, init_trial(false,false); current_frame = 0; playing = true; mglsetproperty([Screen.EyeTracer Screen.Eye2Tracer],'clear'); end
                    while current_frame <= max_frame && playing
                        render_scene();
                        if 0==mod(current_frame,2), set(hTag.Progressbar,'value',current_frame); drawnow; end
                        current_frame = current_frame + 1;
                    end
                    if stopped, return, end
                    current_frame = min(current_frame,max_frame);
                    playing = false;
                else
                    return
                end
            case 'LoadButton'
                try
                    enable_UI('off');
                    set(hTag.PlayButton,'enable','inactive','string','Loading','backgroundcolor',[0.6392 0.2863 0.6431],'foregroundcolor',[1 1 1]);
                    drawnow;
                    load_data();
                catch err
                    data = [];
                end
                enable_UI('on');
            case 'ExportSize'
                item = get(gcbo,'string');
                val =  get(gcbo,'val');
                resolution = item{val};
                cs = regexp(resolution,'(\d+) x (\d+)','tokens');
                export_size = str2double(cs{1}) / Screen.DPI_ratio;
            case 'ExportButton', export_video();
        end
        update_UI();
        if ~isempty(err), rethrow(err); end
        if ~isempty(data), render_scene(); end
    end

    function init()
        addpath(BaseDirectory,[BaseDirectory 'mgl'],[BaseDirectory 'ext'],[BaseDirectory 'daqtoolbox'], ...
            [BaseDirectory 'daqtoolbox' filesep 'liblsl'],[BaseDirectory 'daqtoolbox' filesep 'liblsl' filesep 'bin'], ...
            [BaseDirectory 'ext' filesep 'playback'],[BaseDirectory 'ext' filesep 'SlackMatlab'],[BaseDirectory 'ext' filesep 'deprecated']);
        if ~exist(stimulus_dest,'dir'), mkdir(stimulus_dest); end
        MLVersion = fileread([BaseDirectory 'NIMH_MonkeyLogic_version.txt']);
        
        hFig = findobj('tag','mlplayer');
        if isempty(hFig)
            fig_pos = [0 0 990 570];
            if ispref('NIMH_MonkeyLogic','LastMLPlayerPosition'), last_pos = getpref('NIMH_MonkeyLogic','LastMLPlayerPosition'); fig_pos(3:4) = max([fig_pos(3:4); last_pos(3:4)]); end

            h = findobj('tag','mlmainmenu');
            if isempty(h), screen_pos = GetMonitorPosition(mglgetcommandwindowrect); pos = screen_pos; else, pos = get(h,'position'); screen_pos = GetMonitorPosition(Pos2Rect(pos)); end
            if screen_pos(3) < fig_pos(3), fig_pos(3) = screen_pos(3); end
            if screen_pos(4)-110 < fig_pos(4), fig_pos(4) = screen_pos(4)-110; end  % taskbar (40*2) + titlebar (30)

            fig_pos(1) = min(max(pos(1) + 0.5 * (pos(3) - fig_pos(3)), screen_pos(1)), sum(screen_pos([1 3])) - fig_pos(3));
            fig_pos(2) = min(max(pos(2) + 0.5 * (pos(4) - fig_pos(4) - 30), screen_pos(2) + 40), sum(screen_pos([2 4])) - fig_pos(4) - 30);
        else
            fig_pos = get(hFig,'position');
            close(hFig);
        end
        replica_pos = fig_pos + [0 30 -270 -30];
        
        fontsize = 9;
        figure_bgcolor = [.65 .70 .80];
        frame_bgcolor = [0.9255 0.9137 0.8471];
        purple_bgcolor = [.8 .76 .82];
        callbackfunc = @UIcallback;
        
        hFig = figure;
        set(hFig,'tag','mlplayer','units','pixels','position',fig_pos,'numbertitle','off','name',sprintf('MonkeyLogic Player %s',MLVersion),'menubar','none','resize','on','color',frame_bgcolor);
        
        set(hFig,'closerequestfcn',@closeDlg);
        set_on_move();
        set(hFig,'sizechangedfcn',@on_resize);
        
        hTag.Replica = uicontrol('style','frame','tag','replica','backgroundcolor',[0 0 0],'foregroundcolor',[0 0 0]);
        hTag.Progressbar = uicontrol('style','slider','tag','ProgressBar','min',0,'max',10,'sliderstep',[0.005 0.05],'value',0,'position',[0 0 fig_pos(3)-410 30],'callback',callbackfunc);
        hTag.PlayButton = uicontrol('style','pushbutton','tag','PlayButton','position',[fig_pos(3)-410 0 70 30],'string','Play','fontsize',fontsize,'callback',callbackfunc);
        hTag.LoadButton = uicontrol('style','pushbutton','tag','LoadButton','position',[fig_pos(3)-340 0 70 30],'string','Load','fontsize',fontsize,'callback',callbackfunc);
        
        bgcolor = figure_bgcolor;
        hTxt.Text(1) = uicontrol('style','frame','backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        hTxt.Text(2) = uicontrol('style','text','string','Zoom (%)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.ScreenZoom1 = uicontrol('style','edit','tag','ScreenZoom1','fontsize',fontsize,'callback',callbackfunc);
        hTag.ScreenZoom2 = uicontrol('style','slider','tag','ScreenZoom2','min',ControlScreenZoomRange(1),'max',ControlScreenZoomRange(2),'sliderstep',[1 10]./(ControlScreenZoomRange(2)-ControlScreenZoomRange(1)),'value',ControlScreenZoomRange(1),'fontsize',fontsize,'callback',callbackfunc);
        
        hTxt.Text(24) = uicontrol('style','text','string','Customize tracers','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.CustomTracers = uicontrol('style','checkbox','tag','CustomTracers','value',false,'callback',callbackfunc);

        hTxt.Text(3) = uicontrol('style','text','string','Eye','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTxt.Text(4) = uicontrol('style','text','string','tracer','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.EyeNumber = uicontrol('style','popupmenu','tag','EyeNumber','string',{'#1','#2'},'value',1,'fontsize',fontsize,'callback',callbackfunc);
        hTag.EyeTracerShape = uicontrol('style','popupmenu','tag','EyeTracerShape','string', {'Line','Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.EyeTracerColor = uicontrol('style','pushbutton','tag','EyeTracerColor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        hTag.EyeTracerSize = uicontrol('style','edit','tag','EyeTracerSize','fontsize',fontsize,'callback',callbackfunc);
        hTxt.Text(5) = uicontrol('style','text','string','px','backgroundcolor',bgcolor,'fontsize',fontsize);
        
        hTxt.Text(6) = uicontrol('style','text','string','Joy','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTxt.Text(7) = uicontrol('style','text','string','cursor','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.JoystickNumber = uicontrol('style','popupmenu','tag','JoystickNumber','string',{'#1','#2'},'value',1,'fontsize',fontsize,'callback',callbackfunc);
        hTag.JoystickCursorImage = uicontrol('style','pushbutton','tag','JoystickCursorImage','fontsize',fontsize,'callback',callbackfunc);
        
        hTxt.Text(21) = uicontrol('style','text','string','or','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.JoystickCursorShape = uicontrol('style','popupmenu','tag','JoystickCursorShape','string', {'Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.JoystickCursorColor = uicontrol('style','pushbutton','tag','JoystickCursorColor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        hTag.JoystickCursorSize = uicontrol('style','edit','tag','JoystickCursorSize','fontsize',fontsize,'callback',callbackfunc);
        hTxt.Text(8) = uicontrol('style','text','string','px','backgroundcolor',bgcolor,'fontsize',fontsize);
        
        hTxt.Text(9) = uicontrol('style','text','string','Touch cursor','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.TouchCursorImage = uicontrol('style','pushbutton','tag','TouchCursorImage','fontsize',fontsize,'callback',callbackfunc);
        
        hTxt.Text(22) = uicontrol('style','text','string','or','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.TouchCursorShape = uicontrol('style','popupmenu','tag','TouchCursorShape','string', {'Circle','Square'},'fontsize',fontsize,'callback',callbackfunc);
        hTag.TouchCursorColor = uicontrol('style','pushbutton','tag','TouchCursorColor','string','Color','fontsize',fontsize,'callback',callbackfunc);
        hTag.TouchCursorSize = uicontrol('style','edit','tag','TouchCursorSize','fontsize',fontsize,'callback',callbackfunc);
        hTxt.Text(10) = uicontrol('style','text','string','px','backgroundcolor',bgcolor,'fontsize',fontsize);
        
        hTxt.Text(23) = uicontrol('style','text','string','Mouse cursor','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.MouseCursorType = uicontrol('style','popupmenu','tag','MouseCursorType','string',{'White small','White large','White extra large','Black small','Black large','Black extra large'},'fontsize',fontsize,'callback',callbackfunc);

        hTxt.Text(11) = uicontrol('style','text','string','Cam Video','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.CamVideo = uicontrol('style','checkbox','tag','CamVideo','value',true,'callback',callbackfunc);
        hTag.LargeVideoStr = uicontrol('style','text','tag','LargeVideoStr','string','Large video','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hTag.LargeVideo = uicontrol('style','checkbox','tag','LargeVideo','value',false,'callback',callbackfunc);
        hTag.Transparency(1) = uicontrol('style','text','string','Transparency (%)','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','right');
        hTag.Transparency(2) = uicontrol('style','edit','tag','Transparency1','fontsize',fontsize,'callback',callbackfunc);
        hTag.Transparency(3) = uicontrol('style','slider','tag','Transparency2','min',0,'max',100,'sliderstep',[0.01 0.1],'value',cam_transparency,'fontsize',fontsize,'callback',callbackfunc);

        bgcolor = frame_bgcolor;
        hTxt.Text(12) = uicontrol('style','text','string','Trial','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hTag.TrialList = uicontrol('style','listbox','tag','TrialList','backgroundcolor',[1 1 1],'fontsize',fontsize,'callback',callbackfunc);
        hTxt.Text(13) = uicontrol('style','text','string','Block:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.Block = uicontrol('style','text','tag','Block','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        hTxt.Text(14) = uicontrol('style','text','string','Trial in block:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.TrialWithinBlock = uicontrol('style','text','tag','TrialWithinBlock','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        hTxt.Text(15) = uicontrol('style','text','string','Condition:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.Condition = uicontrol('style','text','tag','Condition','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        hTxt.Text(16) = uicontrol('style','text','string','Error type:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.TrialError = uicontrol('style','text','tag','TrialError','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold');
        hTxt.Text(17) = uicontrol('style','text','string','Reaction time:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.ReactionTime = uicontrol('style','text','tag','ReactionTime','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        hTxt.Text(18) = uicontrol('style','text','string','ms','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
        hTag.BehavioralCodes = uicontrol('style','listbox','tag','BehavioralCodes','backgroundcolor',[1 1 1],'fontsize',fontsize,'callback',callbackfunc);
        
        bgcolor = purple_bgcolor;
        hTxt.Text(19) = uicontrol('style','frame','backgroundcolor',bgcolor,'foregroundcolor',bgcolor);
        hTxt.Text(20) = uicontrol('style','text','string','Export as MP4','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.ExportSize = uicontrol('style','popupmenu','tag','ExportSize','string','800 x 600','fontsize',fontsize,'callback',callbackfunc);
        hTag.ExportButton = uicontrol('style','pushbutton','tag','ExportButton','string','Export','fontsize',fontsize,'callback',callbackfunc);
        
        enable_UI('off');
        on_resize;
        
        DAQ = mldaq_playback();
        Screen = mlscreen_playback();
    end
    function closeDlg(varargin)
        playing = false;
        stopped = true;
        setpref('NIMH_MonkeyLogic','LastMLPlayerPosition',get(hFig,'position'));
        closereq;
        destroy(Screen);  % Screen is not automatically removed in old MATLAB versions.
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
            replica_pos = fig_pos + [0 30 -270 -30];
            mglsetcontrolscreenrect(Pos2Rect(replica_pos));
        end
    end
    function on_resize(varargin)
        fig_pos = get(hFig,'position');
        replica_pos = fig_pos + [0 30 -270 -30];
        if all(0<replica_pos(3:4)), set(hTag.Replica,'position',[1 31 replica_pos(3:4)]); end
        if 410<fig_pos(3), set(hTag.Progressbar,'position',[1 1 fig_pos(3)-410 30]); end
        set(hTag.PlayButton,'position',[fig_pos(3)-409 1 70 30]);
        set(hTag.LoadButton,'position',[fig_pos(3)-339 1 70 30]);
        
        x0 = fig_pos(3)-269; y0 = fig_pos(4)-30; w0 = 85; x1 = x0 + w0;
        set(hTxt.Text(1),'position',[x0 y0-238 271 278]);
        set(hTxt.Text(2),'position',[x0+2 y0 65 22]);
        set(hTag.ScreenZoom1,'position',[x1 y0+4 37 21]);
        set(hTag.ScreenZoom2,'position',[x1+45 y0+4 135 20]);
        
        y0 = y0 - 25;
        set(hTxt.Text(24),'position',[x0+2 y0+3 120 18]);
        set(hTag.CustomTracers,'position',[x1+45 y0+4 15 15]);

        y0 = y0 - 30;
        set(hTxt.Text(3),'position',[x0+12 y0+7 65 22]);
        set(hTxt.Text(4),'position',[x0+2 y0-8 65 22]);
        set(hTag.EyeNumber,'position',[x0+42 y0+4 40 22]);
        set(hTag.EyeTracerShape,'position',[x1 y0+3 65 22]);
        set(hTag.EyeTracerColor,'position',[x1+70 y0+3 55 22]);
        set(hTag.EyeTracerSize,'position',[x1+130 y0+3 35 22]);
        set(hTxt.Text(5),'position',[x1+165 y0-1 20 22]);
        
        y0 = y0 - 30;
        set(hTxt.Text(6),'position',[x0+12 y0+9 60 18]);
        set(hTxt.Text(7),'position',[x0+2 y0-6 60 18]);
        set(hTag.JoystickNumber,'position',[x0+42 y0+4 40 22]);
        set(hTag.JoystickCursorImage,'position',[x1 y0+3 180 22]);
        
        y0 = y0 - 25;
        set(hTxt.Text(21),'position',[x0+25 y0-1 50 22]);
        set(hTag.JoystickCursorShape,'position',[x1 y0+3 65 22]);
        set(hTag.JoystickCursorColor,'position',[x1+70 y0+3 55 22]);
        set(hTag.JoystickCursorSize,'position',[x1+130 y0+3 35 22]);
        set(hTxt.Text(8),'position',[x1+165 y0-1 20 22]);
        
        y0 = y0 - 30;
        set(hTxt.Text(9),'position',[x0+2 y0+3 90 18]);
        set(hTag.TouchCursorImage,'position',[x1 y0+3 180 22]);
        
        y0 = y0 - 25;
        set(hTxt.Text(22),'position',[x0+25 y0-1 50 22]);
        set(hTag.TouchCursorShape,'position',[x1 y0+3 65 22]);
        set(hTag.TouchCursorColor,'position',[x1+70 y0+3 55 22]);
        set(hTag.TouchCursorSize,'position',[x1+130 y0+3 35 22]);
        set(hTxt.Text(10),'position',[x1+165 y0-1 20 22]);

        y0 = y0 - 25;
        set(hTxt.Text(23),'position',[x0+2 y0+3 90 18]);
        set(hTag.MouseCursorType,'position',[x1 y0+3 180 22]);
        
        y0 = y0 - 25;
        set(hTxt.Text(11),'position',[x0+2 y0+3 90 18]);
        set(hTag.CamVideo,'position',[x1 y0+6 15 15]);
        set(hTag.LargeVideoStr,'position',[x1+50 y0+3 100 18]);
        set(hTag.LargeVideo,'position',[x1+130 y0+6 15 15]);
        y0 = y0 - 18;
        set(hTag.Transparency(1),'position',[x0+2 y0 110 18]);
        set(hTag.Transparency(2),'position',[x1+32 y0 37 21]);
        set(hTag.Transparency(3),'position',[x1+75 y0 105 20]);
        
        y0 = y0 - 6;
        set(hTxt.Text(12),'position',[x0+5 y0-22 w0-10 22]);
        h0 = fig_pos(4)-317; if h0<0, h0 = 0; end
        set(hTag.TrialList,'position',[x0+5 31 w0-10 h0]);
        set(hTxt.Text(13),'position',[x1+5 y0-22 90 22]);
        set(hTag.Block,'position',[x1+95 y0-22 60 22]);
        set(hTxt.Text(14),'position',[x1+5 y0-44 100 22]);
        set(hTag.TrialWithinBlock,'position',[x1+95 y0-44 60 22]);
        set(hTxt.Text(15),'position',[x1+5 y0-66 100 22]);
        set(hTag.Condition,'position',[x1+95 y0-66 60 22]);
        set(hTxt.Text(16),'position',[x1+5 y0-88 100 22]);
        set(hTag.TrialError,'position',[x1+70 y0-84 110 18]);
        set(hTxt.Text(17),'position',[x1+5 y0-110 100 22]);
        set(hTag.ReactionTime,'position',[x1+95 y0-110 60 22]);
        set(hTxt.Text(18),'position',[x1+155 y0-110 25 22]);
        h0 = fig_pos(4)-406; if h0<0, h0 = 0; end
        set(hTag.BehavioralCodes,'position',[x1 31 180 h0]);
        
        set(hTxt.Text(19),'position',[x0 0 271 31]);
        set(hTxt.Text(20),'position',[x0+1 1 140 22]);
        set(hTag.ExportSize,'position',[x1 5 110 22]);
        set(hTag.ExportButton,'position',[x1+115 1 70 30]);
        
        if mglcontrolscreenexists
            mglsetcontrolscreenrect(Pos2Rect(replica_pos));
            Screen.reposition_icons(MLConfig);
            if ~playing, mglrendergraphic; mglpresent; end
        end
        drawnow;
    end

    function op = fi(tf,op1,op2)
        if tf, op = op1; else, op = op2; end
    end
    function set_button_color(h,color,varargin)
        set(h,'backgroundcolor',color,'foregroundcolor',hsv2rgb(rem(rgb2hsv(color)+0.5,1)),varargin{:});
    end
    function str = set_listbox_value(h,item,varargin)
        items = get(h,'string');
        val = find(strcmpi(items,item),1);
        if isempty(val), val = 1; end
        set(h,'value',val,varargin{:});
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
    function [filepath,filename] = validate_path(filepath)
        if isempty(filepath), filename = filepath; return, end
        [filepath,filename] = mlsetpath(filepath,search_path.base_path,datafile);
        if isempty(filepath) && ~search_path.no_for_all
            mglsetcontrolscreenshow(false);
            options.Interpreter = 'tex';
            options.Default = 'Yes';
            qstring = ['\fontsize{10}Can''t find the file, ''' regexprep(filename,'([\^_\\])','\\$1') '''.' newline ...
                'Would you like to manually locate it?'];
            button = questdlg(qstring,'Missing stimulus file','Yes','No','No for all',options);
            switch button
                case 'Yes'
                    [n,p] = uigetfile(filename);
                    if 0~=n
                        filepath = [p n];
                        if ispref('NIMH_MonkeyLogic','SearchPath'), p = [p getpref('NIMH_MonkeyLogic','SearchPath')]; else, p = {p}; end
                        setpref('NIMH_MonkeyLogic','SearchPath',p);
                    end
                case 'No for all', search_path.no_for_all = true;
            end
            mglsetcontrolscreenshow(true);
        end
    end
    function dest = copyfield(dest,src,field)
        if isempty(src), src = struct; end
        if isempty(dest), dest = struct; end
        if ~exist('field','var'), field = intersect(fieldnames(dest),fieldnames(src)); end
        for m=1:length(field), dest.(field{m}) = src.(field{m}); end
    end
end
