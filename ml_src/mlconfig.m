classdef mlconfig  % ConstructOnLoad is not necessary since the new definition will be enforced by loadobj()
    properties  % variables related to UI
        SubjectScreenDevice
        DiagonalSize = 50.8
        ViewingDistance = 57
        AdjustedPPD = false
        FallbackScreenRect = '[0,0,1024,768]'
        ForcedUseOfFallbackScreen = false
        SubjectScreenBackground = [0 0 0]
        FixationPointImage = ''
        FixationPointShape = 'Square'
        FixationPointColor = [1 1 1]
        FixationPointDeg = 0.2
        EyeNumber = 1
        EyeTracerShape = {'Line','Circle'}
        EyeTracerColor = [1 0 0; 1 0 1]
        EyeTracerSize = [5 5]
        JoystickNumber = 1
        JoystickCursorImage = {'',''}
        JoystickCursorShape = {'Square','Square'}
        JoystickCursorColor = [0 1 0; 0 0.5 1]
        JoystickCursorSize = [10 10]
        TouchCursorImage = 'hand_touch.png'
        TouchCursorShape = 'Circle'
        TouchCursorColor = [1 1 0]
        TouchCursorSize = 5
        MouseCursorType = 1
        PhotoDiodeTrigger = 1
        PhotoDiodeTriggerSize = 64
        RasterThreshold = 0.9
        ErrorLogic = 1
        CondLogic = 1
        CondSelectFunction = ''
        BlockLogic = 1
        BlockSelectFunction = ''
        BlockChangeFunction = ''
        RemoteAlert = false
        InterTrialInterval = 2000
        SummarySceneDuringITI = false
        NonStopRecording = false
        UserPlotFunction = ''
        IO = []
        AudioEngine = struct('ID',1,'Device',1,'Format',1);
        HighFrequencyDAQ = struct('Adaptor',[],'DevID',[],'SampleRate',[])
        MouseKey = struct('Mouse',false,'KeyCode',[37 38 39 40])
        Touchscreen = struct('On',false,'NumTouch',1)
        USBJoystick = repmat(struct('ID','','NumButton',0),1,2)
        Webcam = repmat(struct('ID','','Property',[]),1,4);
        WebcamExportAs = 1
        EyeTracker
        SerialPort = struct('Port','','BaudRate',38400,'ByteSize',8,'StopBits','OneStopBit','Parity','NoParity')
        VoiceRecording = struct('ID','','SampleRate',11025,'Stereo','Mono','Exclusive',false)
        LabStreamingLayer = struct('BufferLength',360,'Stream',{cell(6,1)})
        IOTestParam
        AIConfiguration = 'NonReferencedSingleEnded'
        AISampleRate = 1000
        StrobeTrigger = 1
        StrobePulseSpec = struct('T1',125,'T2',125)
        RewardFuncArgs = struct('JuiceLine',1,'Duration',100,'NumReward',1,'PauseTime',40,'TriggerVal',5,'Custom','')
        RewardPolarity = 1
        EyeCalibration = [1 1]
        EyeTransform = cell(2,3)
        EyeAutoDriftCorrection = 0
        JoystickCalibration = [1 1]
        JoystickTransform = cell(2,3)
        NumberOfTrialsToRunInThisBlock
        CountOnlyCorrectTrials
        BlocksToRun = []
        FirstBlockToRun = []
        TotalNumberOfTrialsToRun = 99999
        TotalNumberOfBlocksToRun = 99999
        ExperimentName = 'Experiment'
        Investigator = 'Investigator'
        SubjectName = ''
        FilenameFormat = 'yymmdd_sname_cname'
        Filetype = '.bhv2'
        SaveStimuli = false
        MinifyRuntime = true
        ControlScreenZoom = 90
    end
    properties (Dependent)  % related to UI, but not edittable
        Resolution
        PixelsPerDegree
        FormattedName
    end
    properties (Transient)  % variables that are not saved in the config file
        MLVersion
        MLPath
        MLConditions
        DAQ
        Screen
        System
        IOList
    end
    properties (Constant, Hidden)
        DefaultNumberOfTrialsToRunInThisBlock = 9999
        DefaultCountOnlyCorrectTrials = false
        DependentFields = {'Resolution','PixelsPerDegree','FormattedName'}
        TransientFields = {'MLVersion','MLPath','MLConditions','DAQ','Screen','System','IOList'}
        IOFields = {'IO','AudioEngine','HighFrequencyDAQ','MouseKey','Touchscreen','USBJoystick','Webcam','WebcamExportAs','EyeTracker','SerialPort', ...
                    'VoiceRecording','LabStreamingLayer','AIConfiguration','AISampleRate','StrobeTrigger','StrobePulseSpec','RewardPolarity'};
    end

    methods (Static)
        function obj = loadobj(obj)  % when class definition has changed, load() provides the saved values to this function in a struct.
            a = obj; obj = mlconfig; for m=intersect(fieldnames(obj),fieldnames(a))', obj.(m{1}) = a.(m{1}); end  % ensure to use new definition
            obj = update(obj);
        end
    end
    methods
        function field = fieldnames(obj)
            field = mlsetdiff(properties(obj),[obj.DependentFields obj.TransientFields]);
        end
        function obj = mlconfig()
            obj.MLPath = mlpath;
            obj.MLConditions = mlconditions;
            obj.DAQ = mldaq;
            obj.Screen = mlscreen;
            obj.System = mlsystem;

            obj.SubjectScreenDevice = obj.System.NumberOfScreenDevices;
            obj.USBJoystick(1).IP_address = '127.0.0.1'; obj.USBJoystick(1).Port = '10003';
            obj.USBJoystick(2).IP_address = '127.0.0.1'; obj.USBJoystick(2).Port = '10004';

            obj.EyeTracker = struct('Name','None','ID','');
            obj.EyeTracker.MyEyeTracker.IP_address = '127.0.0.1';
            obj.EyeTracker.MyEyeTracker.Port = '10001';
            obj.EyeTracker.MyEyeTracker.Protocol = 'UDP';
            obj.EyeTracker.MyEyeTracker.Source = [0 0];  % [binocular num_extra]
            obj.EyeTracker.ViewPoint.IP_address = '169.254.110.159';
            obj.EyeTracker.ViewPoint.Port = '5000';
            obj.EyeTracker.ViewPoint.Source = [0 2 0.5 20; 0 10 0.5 -20; 1 1 0.5 20; 1 1 0.5 -20; 0 1 0 1; 0 1 0 1; 0 1 0 1; 0 1 0 1; 0 1 0 1; 0 1 0 1];
            obj.EyeTracker.EyeLink.IP_address = '100.1.1.1';
            obj.EyeTracker.EyeLink.Filter = 0;     % 0: off, 1: std, 2: extra
            obj.EyeTracker.EyeLink.PupilSize = 2;  % 1: area, 2: diameter
            obj.EyeTracker.EyeLink.Source = [2 2 0 -0.0005; 2 5 0 0.0005; 2 1 0 -0.0005; 2 1 0 0.0005; 2 1 0 1; 2 1 0 1; 2 1 0 1; 2 1 0 1; 2 1 0 1; 2 1 0 1];
            obj.EyeTracker.ISCAN.IP_address = '127.0.0.1';
            obj.EyeTracker.ISCAN.Port = '12345';
            obj.EyeTracker.ISCAN.Source = [2 0 0.02; 2 0 0.02; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1];
            obj.EyeTracker.ISCAN.Binocular = false;
            obj.EyeTracker.TOMrs.IP_address = '169.254.35.127';
            obj.EyeTracker.TOMrs.Port = '65535';
            obj.EyeTracker.TOMrs.CameraProfile = 'Default';
            obj.EyeTracker.TOMrs.Source = [2 320 0.02; 3 240 0.02; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1];
            obj.EyeTracker.Tobii.SerialNumber = 'TPSP1-010202816665';
            obj.EyeTracker.Tobii.GazeOutputFrequency = 1200;
            obj.EyeTracker.Tobii.EyeTrackingMode = 'monkey';
            obj.EyeTracker.Tobii.Source = [2 0.5 20; 3 0.5 -20; 1 0.5 20; 1 0.5 -20; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1];
            obj.EyeTracker.Tobii.CalibrationDataFile = '';

            obj.NumberOfTrialsToRunInThisBlock = obj.DefaultNumberOfTrialsToRunInThisBlock;
            obj.CountOnlyCorrectTrials = obj.DefaultCountOnlyCorrectTrials;

            obj.IOTestParam = struct('general_selected',[],'general_range',[],'highfreq_selected',[],'highfreq_range',[],'voice_range',[],'update_interval',[]);
        end
        function export_to_file(obj,fout,varname)
            if ~exist('varname','var'), varname = 'MLConfig'; end
            try
                dest = [];
                field = [mlsetdiff(properties(obj),obj.TransientFields); 'MLVersion'; 'MLPath'; 'Screen'; 'System'];
                for m=1:length(field), dest.(field{m}) = obj.(field{m}); end
                if ~isopen(fout), open(fout,fout.filename,'a'); end
                fout.write(dest,varname);
            catch err
                close(fout);
                rethrow(err);
            end
        end
        function delete(obj)
            delete(obj.DAQ);
            delete(obj.Screen);
        end

        function tf = isequal(obj,val)
            if ~strcmp(class(obj),class(val)), tf = false; return, end
            field = mlsetdiff(fieldnames(obj),{'EyeNumber','JoystickNumber'});
            tf = true; for m=1:length(field), if ~isequaln(obj.(field{m}),val.(field{m})), tf = false; break, end, end
        end

        function val = get.Resolution(obj)
            try
                [width,height,refreshrate] = mglgetadapterdisplaymode(obj.SubjectScreenDevice);
                val = sprintf('%d x %d %.0f Hz',width,height,refreshrate);
            catch
                val = '';
            end
        end
        function val = get.PixelsPerDegree(obj)
            try
                [width,height] = mglgetadapterdisplaymode(obj.SubjectScreenDevice);
                pixels_in_diagonal = sqrt(width^2 + height^2);
                if obj.AdjustedPPD
                    viewing_deg = obj.DiagonalSize / (obj.ViewingDistance * tand(1));
                else
                    viewing_deg = 2 * atan2(obj.DiagonalSize / 2, obj.ViewingDistance) * 180 / pi;  % atan2d is introduced in R2012b
                end
                val = pixels_in_diagonal / viewing_deg * [1 -1];
            catch
                val = NaN(1,2);
            end
        end
        function val = get.FormattedName(obj)
            try
                val = obj.FilenameFormat;
                format = {'yyyy','yy','mmm','mm','ddd','dd','HH','MM','SS'};
                for m=1:length(format), val = regexprep(val,format{m},datestr(now,format{m})); end
                val = regexprep(val,'expname|ename',obj.ExperimentName);
                val = regexprep(val,'yourname|yname',obj.Investigator);
                [~,filename] = fileparts(obj.MLPath.ConditionsFile);
                val = regexprep(val,'condname|cname',filename);
                val = regexprep(val,'subjname|sname',obj.SubjectName);
            catch
                val = '';
            end
        end

        function obj = update(obj,s)
            if exist('s','var'), for m=mlsetdiff(fieldnames(obj),fieldnames(s))', s.(m{1}) = obj.(m{1}); end, obj = s; end  % for mlread

            if ~isscalar(obj.RasterThreshold)||obj.RasterThreshold<0||1<obj.RasterThreshold, obj.RasterThreshold = 0.9; end
            if ~isfield(obj.RewardFuncArgs,'JuiceLine'), obj.RewardFuncArgs.JuiceLine = 1; end
            if ~isstruct(obj.Touchscreen), a = struct('On',false,'NumTouch',1); a.On = obj.Touchscreen; obj.Touchscreen = a; end
            if ~isstruct(obj.USBJoystick), a = repmat(struct('ID',''),1,2); a(1).ID = obj.USBJoystick; obj.USBJoystick = a; end
            if ~isfield(obj.USBJoystick,'NumButton'), for m=1:length(obj.USBJoystick), obj.USBJoystick(m).NumButton = 0; end, end
            if ~isfield(obj.USBJoystick,'IP_address'), for m=1:length(obj.USBJoystick), obj.USBJoystick(m).IP_address = '127.0.0.1'; end, end
            if ~isfield(obj.USBJoystick,'Port'), for m=1:length(obj.USBJoystick), obj.USBJoystick(m).Port = sprintf('%d',10002+m); end, end
            if ~isfield(obj.VoiceRecording,'Exclusive'), obj.VoiceRecording.Exclusive = false; end
            if ischar(obj.EyeTracerShape), obj.EyeTracerShape = {obj.EyeTracerShape,'Circle'}; end
            if 1==size(obj.EyeTracerColor,1), obj.EyeTracerColor = [obj.EyeTracerColor; 1 0 1]; end
            if isscalar(obj.EyeTracerSize), obj.EyeTracerSize = [obj.EyeTracerSize 5]; end
            if isscalar(obj.EyeCalibration), obj.EyeCalibration = [obj.EyeCalibration 1]; end
            if 1==size(obj.EyeTransform,1), obj.EyeTransform = [obj.EyeTransform; cell(1,3)]; end
            if ischar(obj.JoystickCursorImage), obj.JoystickCursorImage = {obj.JoystickCursorImage,''}; end
            if ischar(obj.JoystickCursorShape), obj.JoystickCursorShape = {obj.JoystickCursorShape,'Square'}; end
            if 1==size(obj.JoystickCursorColor,1), obj.JoystickCursorColor = [obj.JoystickCursorColor; 0 0.5 1]; end
            if isscalar(obj.JoystickCursorSize), obj.JoystickCursorSize = [obj.JoystickCursorSize 10]; end
            if isscalar(obj.JoystickCalibration), obj.JoystickCalibration = [obj.JoystickCalibration 1]; end
            if 1==size(obj.JoystickTransform,1), obj.JoystickTransform = [obj.JoystickTransform; cell(1,3)]; end
            if isempty(obj.EyeTracker.ViewPoint)
                obj.EyeTracker.ViewPoint.IP_address = '169.254.110.159';
                obj.EyeTracker.ViewPoint.Port = '5000';
                obj.EyeTracker.ViewPoint.Source = [0 2 0.5 20; 0 10 0.5 -20; 1 1 0.5 20; 1 1 0.5 -20; 0 1 0 1; 0 1 0 1; 0 1 0 1; 0 1 0 1];
            elseif size(obj.EyeTracker.ViewPoint.Source,1)<8
                obj.EyeTracker.ViewPoint.Source(5:8,:) = obj.EyeTracker.ViewPoint.Source(3:6,:);
                obj.EyeTracker.ViewPoint.Source(3:4,:) = obj.EyeTracker.ViewPoint.Source(1:2,:);
                obj.EyeTracker.ViewPoint.Source(3:4,1) = 1-obj.EyeTracker.ViewPoint.Source(3:4,1);
                obj.EyeTracker.ViewPoint.Source(3:4,2) = 1;
            end
            if isempty(obj.EyeTracker.EyeLink)
                obj.EyeTracker.EyeLink.IP_address = '100.1.1.1';
                obj.EyeTracker.EyeLink.Filter = 0;     % 0: off, 1: std, 2: extra
                obj.EyeTracker.EyeLink.PupilSize = 2;  % 1: area, 2: diameter
                obj.EyeTracker.EyeLink.Source = [2 2 0 -0.0005; 2 5 0 0.0005; 2 1 0 -0.0005; 2 1 0 0.0005; 2 1 0 1; 2 1 0 1; 2 1 0 1; 2 1 0 1];
            elseif size(obj.EyeTracker.EyeLink.Source,1)<8
                obj.EyeTracker.EyeLink.Source = [repmat(obj.EyeTracker.EyeLink.Source(1:2,:),2,1); obj.EyeTracker.EyeLink.Source(3:6,:)];
                obj.EyeTracker.EyeLink.Source(3:4,2) = 1;
            end
            if ~isfield(obj.EyeTracker,'ISCAN')
                obj.EyeTracker.ISCAN.IP_address = '127.0.0.1';
                obj.EyeTracker.ISCAN.Port = '12345';
                obj.EyeTracker.ISCAN.Source = [2 0 0.02; 2 0 0.02; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1];
                obj.EyeTracker.ISCAN.Binocular = false;
            end
            if ~isfield(obj.EyeTracker,'TOMrs')
                obj.EyeTracker.TOMrs.IP_address = '169.254.35.127';
                obj.EyeTracker.TOMrs.CameraProfile = 'Default';
                obj.EyeTracker.TOMrs.Source = [2 320 0.02; 3 240 0.02; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1; 1 0 1];
            end
            if ~isfield(obj.EyeTracker.TOMrs,'Port'), obj.EyeTracker.TOMrs.Port = '65535'; end
            if ~isfield(obj.EyeTracker,'MyEyeTracker')
                obj.EyeTracker.MyEyeTracker.IP_address = '127.0.0.1';
                obj.EyeTracker.MyEyeTracker.Port = '10001';
                obj.EyeTracker.MyEyeTracker.Protocol = 'UDP';
                obj.EyeTracker.MyEyeTracker.Source = [0 0];  % [binocular num_extra]
            end
            if ~isfield(obj.EyeTracker,'Tobii')
                obj.EyeTracker.Tobii.SerialNumber = 'TPSP1-010202816665';
                obj.EyeTracker.Tobii.GazeOutputFrequency = 1200;
                obj.EyeTracker.Tobii.EyeTrackingMode = 'monkey';
                obj.EyeTracker.Tobii.Source = [2 0.5 20; 3 0.5 -20; 1 0.5 20; 1 0.5 -20; 1 0 1; 1 0 1; 1 0 1; 1 0 1];
            end
            if ~isfield(obj.EyeTracker.Tobii,'CalibrationDataFile')
                obj.EyeTracker.Tobii.CalibrationDataFile = '';
            end
            if ~isfield(obj.IO,'Invert')
                for m=1:size(obj.IO,1), obj.IO(m).Invert = false; end
            end
            
            nparam = 10;  % increase # of eye tracker params
            nsource = size(obj.EyeTracker.ViewPoint.Source,1); if nsource<nparam, obj.EyeTracker.ViewPoint.Source(nsource+1:nparam,:) = repmat([0 1 0 1],nparam-nsource,1); end
            nsource = size(obj.EyeTracker.EyeLink.Source,1);   if nsource<nparam, obj.EyeTracker.EyeLink.Source(nsource+1:nparam,:) = repmat([2 1 0 1],nparam-nsource,1); end
            nsource = size(obj.EyeTracker.ISCAN.Source,1);     if nsource<nparam, obj.EyeTracker.ISCAN.Source(nsource+1:nparam,:) = repmat([1 0 1],nparam-nsource,1); end
            nsource = size(obj.EyeTracker.TOMrs.Source,1);     if nsource<nparam, obj.EyeTracker.TOMrs.Source(nsource+1:nparam,:) = repmat([1 0 1],nparam-nsource,1); end
            nsource = size(obj.EyeTracker.Tobii.Source,1);     if nsource<nparam, obj.EyeTracker.Tobii.Source(nsource+1:nparam,:) = repmat([1 0 1],nparam-nsource,1); end
        end
    end
end
