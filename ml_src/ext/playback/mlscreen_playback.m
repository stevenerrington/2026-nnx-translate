classdef mlscreen_playback < handle
    properties
        BackgroundColor
    end
    properties (SetAccess = protected)
        SubjectScreenRect
        Xsize
        Ysize
        SubjectScreenAspectRatio
        SubjectScreenFullSize
        SubjectScreenHalfSize
        DPI_ratio
        PixelsPerDegree
        RefreshRate
        FrameLength
        VBlankLength
        ScanLine
    end
    properties (SetAccess = protected, Hidden)
        EyeTracer
        EyeLineTracer
        Eye2Tracer
        Eye2LineTracer
        JoystickCursor
        Joystick2Cursor
        TouchCursor
        MouseCursor
        MouseCursorSize
        ButtonLabel
        ButtonPressed
        ButtonReleased
        Dashboard        % not used
        EscapeRequested  % not used
        TTL
        Reward           % not used
        RewardCount      % not used
        RewardDuration   % not used
        Stimulation
        PhotodiodeWhite  % not used
        PhotodiodeBlack  % not used
        
        CurrentPosition
        Webcam
    end
    
    methods
        function obj = mlscreen_playback(), end
        function delete(obj), destroy(obj); end
        function destroy(~), mgldestroycontrolscreen(); end
        function set.BackgroundColor(obj,val)
            obj.BackgroundColor = val;
            mglsetscreencolor(1,obj.BackgroundColor);
        end
        
        function create(obj,MLConfig)
            destroy(obj);
            
            if isfield(MLConfig,'Screen')
                ss = [MLConfig.Screen.Xsize MLConfig.Screen.Ysize MLConfig.Screen.RefreshRate];
            else
                ss = regexp(MLConfig.Resolution,'(\d+) x (\d+) (\d+) Hz','tokens'); ss = str2double(ss{1});
            end
            if MLConfig.ForcedUseOfFallbackScreen, rect = eval(MLConfig.FallbackScreenRect); ss(1:2) = rect(3:4)-rect(1:2); end

            obj.SubjectScreenRect = [0 0 ss(1:2)];
            obj.Xsize = ss(1);
            obj.Ysize = ss(2);
            obj.SubjectScreenAspectRatio = obj.Xsize / obj.Ysize;
            obj.SubjectScreenFullSize = [obj.Xsize obj.Ysize];
            obj.SubjectScreenHalfSize = obj.SubjectScreenFullSize / 2;
            screensize = get(0,'ScreenSize');
            obj.DPI_ratio = mglgetadapterdisplaymode(1) / screensize(3);
            obj.BackgroundColor = MLConfig.SubjectScreenBackground;
            obj.PixelsPerDegree = MLConfig.PixelsPerDegree(1);
            obj.RefreshRate = ss(3);
            obj.FrameLength = 1000 / ss(3);
            
            hFig = findobj('tag','mlplayer');
            controlscreenposition = get(hFig,'position');
            replica_pos = get(findobj(hFig,'tag','replica'),'position');
            mglcreateplaybackscreen(obj.SubjectScreenFullSize,obj.BackgroundColor,Pos2Rect([controlscreenposition(1:2)-1 0 0]+replica_pos),[0.25 0.25 0.25],obj.RefreshRate);
            info = mglgetscreeninfo(2);
            if isfield(MLConfig,'Screen')
                obj.VBlankLength = MLConfig.Screen.VBlankLength;
                obj.ScanLine = MLConfig.Screen.ScanLine;
            else
                obj.VBlankLength = info.VBlankLength;
                obj.ScanLine = info.ScanLine;
            end
            
            % create icons
            load('mlimagedata.mat','green_pressed','green_released','stimulation_triggered','ttl_triggered');
            fontsize = 12;
            
            obj.CurrentPosition = mgladdtext('Current position:',12);
            mglsetproperty(obj.CurrentPosition,'fontsize',fontsize);
            
            obj.Webcam = NaN(1,MLConfig.DAQ.nWebcam);
            for m=1:length(obj.Webcam), obj.Webcam(m) = mgladdbitmap([0 0],4); end
            mglsetproperty(obj.Webcam,'zorder','front','zorder','backward');
            
            nbutton = MLConfig.DAQ.nButton;
            obj.ButtonLabel = NaN(1,sum(nbutton));
            obj.ButtonPressed = NaN(1,sum(nbutton));
            obj.ButtonReleased = NaN(1,sum(nbutton));
            for m=1:sum(nbutton)
                obj.ButtonLabel(m) = mgladdtext(sprintf('%d',m),12);
                obj.ButtonPressed(m) = mgladdbitmap(mglimresize(green_pressed,obj.DPI_ratio),12);
                obj.ButtonReleased(m) = mgladdbitmap(mglimresize(green_released,obj.DPI_ratio),12);
            end
            mglsetproperty(obj.ButtonLabel,'center','fontsize',fontsize);
            
            nttl = MLConfig.DAQ.nTTL;
            obj.TTL = NaN(2,sum(nttl));
            for m=1:sum(nttl)
                obj.TTL(1,m) = mgladdtext(sprintf('%d',m),12);
                if MLConfig.DAQ.TTLInvert(m)
                    obj.TTL(2,m) = mgladdbitmap(mglimresize(ttl_triggered(end:-1:1,:,:,:),obj.DPI_ratio),12);
                else
                    obj.TTL(2,m) = mgladdbitmap(mglimresize(ttl_triggered,obj.DPI_ratio),12);
                end
            end
            mglsetproperty(obj.TTL(1,:),'center','fontsize',fontsize);
            
            nstimulation = MLConfig.DAQ.nStimulation;
            obj.Stimulation = NaN(2,sum(nstimulation));
            for m=1:sum(nstimulation)
                obj.Stimulation(1,m) = mgladdtext(sprintf('%d',m),12);
                obj.Stimulation(2,m) = mgladdbitmap(mglimresize(stimulation_triggered,obj.DPI_ratio),12);
            end
            mglsetproperty(obj.Stimulation(1,:),'center','fontsize',fontsize);
            
            mglactivategraphic([obj.ButtonLabel obj.ButtonPressed obj.ButtonReleased obj.TTL(:)' obj.Stimulation(:)'],false);
            
            reposition_icons(obj,MLConfig);
            create_tracers(obj,MLConfig);
        end
        function create_tracers(obj,MLConfig)
            mgldestroygraphic([obj.EyeTracer obj.Eye2Tracer obj.JoystickCursor obj.Joystick2Cursor obj.TouchCursor(:)' obj.MouseCursor]);
            
            nvertex = round(max(5,50 * MLConfig.AISampleRate / 1000));
            obj.EyeLineTracer = strcmp(MLConfig.EyeTracerShape{1},'Line');
            if obj.EyeLineTracer, obj.EyeTracer = mgladdline(MLConfig.EyeTracerColor(1,:),nvertex,1,10); else, obj.EyeTracer = load_cursor('',MLConfig.EyeTracerShape{1},MLConfig.EyeTracerColor(1,:),MLConfig.EyeTracerSize(1),10); end
            obj.Eye2LineTracer = strcmp(MLConfig.EyeTracerShape{2},'Line');
            if obj.Eye2LineTracer, obj.Eye2Tracer = mgladdline(MLConfig.EyeTracerColor(2,:),nvertex,1,10); else, obj.Eye2Tracer = load_cursor('',MLConfig.EyeTracerShape{2},MLConfig.EyeTracerColor(2,:),MLConfig.EyeTracerSize(2),10); end
            
            obj.JoystickCursor = [NaN load_cursor(MLConfig.JoystickCursorImage{1},MLConfig.JoystickCursorShape{1},MLConfig.JoystickCursorColor(1,:),MLConfig.JoystickCursorSize(1),10)];
            obj.Joystick2Cursor = [NaN load_cursor(MLConfig.JoystickCursorImage{2},MLConfig.JoystickCursorShape{2},MLConfig.JoystickCursorColor(2,:),MLConfig.JoystickCursorSize(2),10)];
            
            obj.TouchCursor = NaN(max(2,MLConfig.Touchscreen.NumTouch),2);
            for m=1:size(obj.TouchCursor,1)
                obj.TouchCursor(m,2) = load_cursor(MLConfig.TouchCursorImage,MLConfig.TouchCursorShape,MLConfig.TouchCursorColor,MLConfig.TouchCursorSize,10);
            end
            
            load('mlimagedata.mat','mouse_cursor_S','mouse_cursor_L','mouse_cursor_XL','mouse_cursor_bS','mouse_cursor_bL','mouse_cursor_bXL');
            switch MLConfig.MouseCursorType
                case 1, imdata = mouse_cursor_S;
                case 2, imdata = mouse_cursor_L;
                case 3, imdata = mouse_cursor_XL;
                case 4, imdata = mouse_cursor_bS;
                case 5, imdata = mouse_cursor_bL;
                case 6, imdata = mouse_cursor_bXL;
            end
            obj.MouseCursor = [NaN mgladdbitmap(imdata,10) ...
                mgladdbitmap(mglimread(fullfile(matlabroot,'toolbox/matlab/icons','help_ex.png')),10) ...
                mgladdbitmap(mglimread(fullfile(matlabroot,'toolbox/matlab/icons','help_ex.png')),10)];
            obj.MouseCursorSize = [size(imdata,2) size(imdata,1)];

            mglactivategraphic([obj.EyeTracer obj.Eye2Tracer obj.JoystickCursor obj.Joystick2Cursor obj.TouchCursor(:)' obj.MouseCursor],false);
        end
        function update_tracers(obj,prop,val), mgldestroygraphic(obj.(prop)); obj.(prop) = val; end
        function reposition_icons(obj,MLConfig)
            ControlScreenRect = mglgetscreeninfo(2,'Rect') / obj.DPI_ratio;
            ControlScreenSize = ControlScreenRect(3:4) - ControlScreenRect(1:2);
            
            mglsetproperty(obj.CurrentPosition,'origin',[10 (ControlScreenSize(2)-20) * obj.DPI_ratio]);
            
            by = ControlScreenSize(2) - 30;
            for m=1:sum(MLConfig.DAQ.nButton)
                bx = 40 + (m-1)*40;
                mglsetorigin([obj.ButtonLabel(m) obj.ButtonPressed(m) obj.ButtonReleased(m)], [bx by-30; bx by; bx by] * obj.DPI_ratio);
            end
            
            by = by-50;
            for m=1:sum(MLConfig.DAQ.nTTL)
                bx = 40 + (m-1)*40;
                mglsetorigin(obj.TTL(:,m), [bx by-30; bx by] * obj.DPI_ratio);
            end
            
            by = by-50;
            for m=1:sum(MLConfig.DAQ.nStimulation)
                bx = 40 + (m-1)*40;
                mglsetorigin(obj.Stimulation(:,m), [bx by-30; bx by] * obj.DPI_ratio);
            end
        end
    end
end
