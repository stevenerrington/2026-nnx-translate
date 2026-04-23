classdef mltrialdata < handle
    properties
        Trial
        BlockCount
        TrialWithinBlock
        Block
        Condition
        TrialError
        ReactionTime
        AbsoluteTrialStartTime
        TrialDateTime
        BehavioralCodes
        AnalogData
        ObjectStatusRecord
        RewardRecord
        UserVars
        VariableChanges
        TaskObject
        CycleRate
        Ver = 1
    end
    properties (Transient, Hidden)
        UserMessage
        NewEyeTransform
        NewEye2Transform
        HighFrequency
        Webcam
        WebcamExportAs
        Voice
    end
    
    methods
        function obj = mltrialdata(DAQ)
            obj.BehavioralCodes = struct('CodeTimes',[],'CodeNumbers',[]);
            obj.AnalogData = struct('SampleInterval',[],'Eye',[],'Eye2',[],'EyeExtra',[],'Joystick',[],'Joystick2',[],'Touch',[],'Mouse',[],'KeyInput',[],'PhotoDiode',[]);
            for ml_=1:DAQ.nGeneral, obj.AnalogData.General.(sprintf('Gen%d',ml_)) = []; end
            for ml_=1:sum(DAQ.nButton), obj.AnalogData.Button.(sprintf('Btn%d',ml_)) = []; end
            for ml_=1:DAQ.nLSL, obj.AnalogData.LSL.(sprintf('LSL%d',ml_)) = []; end
        end
        function export_to_file(obj,fout,varname)
            if ~exist('varname','var'), varname = sprintf('Trial%d',obj.Trial); end
            try
                if ~isopen(fout), open(fout,fout.filename,'a'); end
                fout.write(obj,varname);
                
                if ~isempty(obj.HighFrequency)
                    hfreq = fieldnames(obj.HighFrequency)';
                    for m=hfreq, fout.write(obj.HighFrequency.(m{1}),sprintf('%s_%d',m{1},obj.Trial)); end
                end
                
                if ~isempty(obj.Voice), fout.write(obj.Voice,sprintf('Voice_%d',obj.Trial)); end
                
                switch obj.WebcamExportAs
                    case 1  % to the data file (no compression)
                        for m=1:length(obj.Webcam)
                            fout.write(obj.Webcam(m),sprintf('Cam%d_%d',m,obj.Trial));
                        end
                    case {2,3}  % to the data file (compression), as separate AVI or MP4 files
                        [p,n] = fileparts(fout.filename);
                        if ~isempty(p), p = [p filesep]; end
                        
                        for m=1:length(obj.Webcam)
                            cam_no = sprintf('Cam%d_%d',m,obj.Trial);
                            videofile = [p n '_' cam_no '.mp4'];
                            videoinfo = struct('Filename',videofile,'File',[],'Time',obj.Webcam(m).Time);
                            
                            frame_rate = round(1000/median(diff(obj.Webcam(m).Time)));
                            if isnan(frame_rate), frame_rate = 30; end
                            frame = decodeframe(obj.Webcam(m));
                            v = VideoWriter(videofile,'MPEG-4'); %#ok<TNMLP>
                            set(v,'FrameRate',frame_rate);
                            open(v);
                            try
                                for f=1:size(frame,4), writeVideo(v,frame(:,:,:,f)); end
                            catch
                            end
                            close(v);
                            
                            if 2==obj.WebcamExportAs
                                fid = fopen(videofile,'r');
                                videoinfo.File = fread(fid,Inf,'*uint8');
                                fclose(fid);
                                delete(videofile);
                            end
                            
                            fout.write(videoinfo,cam_no,false);
                        end
                end
            catch err
                close(fout);
                rethrow(err);
            end
        end            
    end
end
