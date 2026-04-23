classdef mlscreen < handle
    properties
        BackgroundColor = [0 0 0]
    end
    properties (SetAccess = protected)
        SubjectScreenRect = [0 0 1024 768]  % init values are necessary for previewing GEN before creating screens
        Xsize = 1024
        Ysize = 768
        SubjectScreenAspectRatio = 1024/768
        SubjectScreenFullSize = [1024 768]
        SubjectScreenHalfSize = 0.5 * [1024 768]
        DPI_ratio = 1
        PixelsPerDegree = 72
        RefreshRate = 60
        FrameLength = 1000/60
        VBlankLength = 0.4  % sec * 1000
        ScanLine = [1 768]
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
        Dashboard
        EscapeRequested
        TTL
        Reward
        RewardCount
        RewardDuration
        Stimulation
        PhotodiodeWhite
        PhotodiodeBlack
        HotkeyLocked
    end
    properties (Access = protected)
        IsCreated = false
    end
    
    methods
        function obj = mlscreen(MLConfig), if exist('MLConfig','var') && isa(MLConfig,'mlconfig'), create(obj,MLConfig); end, end
        function delete(obj), destroy(obj); end
        function destroy(obj)
            if ~obj.IsCreated, return, end
            obj.IsCreated = false;
            if mglsubjectscreenexists, mgldestroysubjectscreen; end  % not to destroys control screen when the file format is MAT
        end
        function set.BackgroundColor(obj,val)
            if 3~=numel(val), error('BackgroundColor must be a 1-by-3 vector.'); end
            obj.BackgroundColor = val(:)';
            mglsetscreencolor(1,obj.BackgroundColor);
        end
        
        function create(obj,MLConfig)
            hFig = findobj('tag','mlplayer'); if ~isempty(hFig), close(hFig); drawnow; pause(0.3); end
            
            mglcreatesubjectscreen(MLConfig.SubjectScreenDevice,MLConfig.SubjectScreenBackground,MLConfig.FallbackScreenRect,MLConfig.ForcedUseOfFallbackScreen);
            obj.IsCreated = true;
            
            info = mglgetscreeninfo(1);
            obj.SubjectScreenRect = info.Rect;
            obj.Xsize = info.Rect(3) - info.Rect(1);
            obj.Ysize = info.Rect(4) - info.Rect(2);
            obj.SubjectScreenAspectRatio = obj.Xsize / obj.Ysize;
            obj.SubjectScreenFullSize = [obj.Xsize obj.Ysize];
            obj.SubjectScreenHalfSize = obj.SubjectScreenFullSize / 2;
            screensize = get(0,'ScreenSize');
            obj.DPI_ratio = mglgetadapterdisplaymode(1) / screensize(3);
            obj.BackgroundColor = MLConfig.SubjectScreenBackground;
            obj.PixelsPerDegree = MLConfig.PixelsPerDegree(1);
            obj.RefreshRate = info.RefreshRate;
            obj.FrameLength = info.FrameLength;
            obj.VBlankLength = info.VBlankLength;
            obj.ScanLine = info.ScanLine;
            
            id = mglgetadapteridentifier(MLConfig.SubjectScreenDevice);
            if 4318==id.VendorId, MLConfig.RasterThreshold = 0; end  % NVIDIA
            mglsetrasterthreshold(MLConfig.RasterThreshold);
        end
        function create_tracers(obj,MLConfig)
            DAQ = MLConfig.DAQ;
            load('mlimagedata.mat','green_pressed','green_released','reward_image','stimulation_triggered','ttl_triggered','mouse_cursor_S','mouse_cursor_L','mouse_cursor_XL','mouse_cursor_bS','mouse_cursor_bL','mouse_cursor_bXL');
            fontsize = 12;
            
            mgldestroygraphic([obj.EyeTracer obj.Eye2Tracer obj.JoystickCursor obj.Joystick2Cursor obj.TouchCursor(:)' obj.MouseCursor obj.ButtonLabel obj.ButtonPressed obj.ButtonReleased]);
            mgldestroygraphic([obj.TTL(:)' obj.Stimulation(:)' obj.Dashboard obj.Reward obj.RewardCount obj.RewardDuration obj.HotkeyLocked obj.EscapeRequested]);

            obj.EyeLineTracer = strcmp(MLConfig.EyeTracerShape{1},'Line');
            if obj.EyeLineTracer, obj.EyeTracer = mgladdline(MLConfig.EyeTracerColor(1,:),50,1,10); else, obj.EyeTracer = load_cursor('',MLConfig.EyeTracerShape{1},MLConfig.EyeTracerColor(1,:),MLConfig.EyeTracerSize(1),10); end
            obj.Eye2LineTracer = strcmp(MLConfig.EyeTracerShape{2},'Line');
            if obj.Eye2LineTracer, obj.Eye2Tracer = mgladdline(MLConfig.EyeTracerColor(2,:),50,1,10); else, obj.Eye2Tracer = load_cursor('',MLConfig.EyeTracerShape{2},MLConfig.EyeTracerColor(2,:),MLConfig.EyeTracerSize(2),10); end
            
            obj.JoystickCursor = [load_cursor(MLConfig.JoystickCursorImage{1},MLConfig.JoystickCursorShape{1},MLConfig.JoystickCursorColor(1,:),MLConfig.JoystickCursorSize(1),11) ...
                load_cursor(MLConfig.JoystickCursorImage{1},MLConfig.JoystickCursorShape{1},MLConfig.JoystickCursorColor(1,:),MLConfig.JoystickCursorSize(1),10,0)];
            obj.Joystick2Cursor = [load_cursor(MLConfig.JoystickCursorImage{2},MLConfig.JoystickCursorShape{2},MLConfig.JoystickCursorColor(2,:),MLConfig.JoystickCursorSize(2),11) ...
                load_cursor(MLConfig.JoystickCursorImage{2},MLConfig.JoystickCursorShape{2},MLConfig.JoystickCursorColor(2,:),MLConfig.JoystickCursorSize(2),10,0)];

            obj.TouchCursor = NaN(max(2,MLConfig.Touchscreen.NumTouch),2);  % at least 2 cursors for simulation
            for m=1:size(obj.TouchCursor,1)
                obj.TouchCursor(m,:) = [load_cursor(MLConfig.TouchCursorImage,MLConfig.TouchCursorShape,MLConfig.TouchCursorColor,MLConfig.TouchCursorSize,11) ...
                    load_cursor(MLConfig.TouchCursorImage,MLConfig.TouchCursorShape,MLConfig.TouchCursorColor,MLConfig.TouchCursorSize,10,0)];
            end
            
            switch MLConfig.MouseCursorType
                case 1, imdata = mouse_cursor_S;
                case 2, imdata = mouse_cursor_L;
                case 3, imdata = mouse_cursor_XL;
                case 4, imdata = mouse_cursor_bS;
                case 5, imdata = mouse_cursor_bL;
                case 6, imdata = mouse_cursor_bXL;
            end
            obj.MouseCursor = [mgladdbitmap(imdata,9) mgladdbitmap(imdata,10) ...
                mgladdbitmap(mglimread(fullfile(matlabroot,'toolbox/matlab/icons','help_ex.png')),10) ...
                mgladdbitmap(mglimread(fullfile(matlabroot,'toolbox/matlab/icons','help_ex.png')),10)];
            obj.MouseCursorSize = [size(imdata,2) size(imdata,1)];

            nbutton = sum(DAQ.nButton);
            obj.ButtonLabel = NaN(1,nbutton);
            obj.ButtonPressed = NaN(1,nbutton);
            obj.ButtonReleased = NaN(1,nbutton);
            for m=1:nbutton
                obj.ButtonLabel(m) = mgladdtext(sprintf('%d',m),12);
                mglsetproperty(obj.ButtonLabel(m),'center','fontsize',fontsize);
                obj.ButtonPressed(m) = mgladdbitmap(mglimresize(green_pressed,obj.DPI_ratio),12);
                obj.ButtonReleased(m) = mgladdbitmap(mglimresize(green_released,obj.DPI_ratio),12);
            end
            
            nttl = sum(DAQ.nTTL);
            obj.TTL = NaN(2,nttl);
            for m=1:nttl
                obj.TTL(1,m) = mgladdtext(sprintf('%d',m),12);
                mglsetproperty(obj.TTL(1,m),'center','fontsize',fontsize);
                if DAQ.TTLInvert(m)
                    obj.TTL(2,m) = mgladdbitmap(mglimresize(ttl_triggered(end:-1:1,:,:,:),obj.DPI_ratio),12);
                else
                    obj.TTL(2,m) = mgladdbitmap(mglimresize(ttl_triggered,obj.DPI_ratio),12);
                end
            end
            
            nstimulation = sum(DAQ.nStimulation);
            obj.Stimulation = NaN(2,nstimulation);
            for m=1:nstimulation
                obj.Stimulation(1,m) = mgladdtext(sprintf('%d',m),12);
                mglsetproperty(obj.Stimulation(1,m),'center','fontsize',fontsize);
                obj.Stimulation(2,m) = mgladdbitmap(mglimresize(stimulation_triggered,obj.DPI_ratio),12);
            end
            
            obj.Dashboard = NaN(1,10);
            for m=1:length(obj.Dashboard), obj.Dashboard(m) = mgladdtext('',12); end
            mglsetproperty(obj.Dashboard,'origin',[20 20; 20 40; 20 60; 20 80; 20 100; 20 120; 20 140; 20 160; 20 180; 20 200] * obj.DPI_ratio,'fontsize',fontsize);
            
            obj.Reward = mgladdbitmap(mglimresize(reward_image,obj.DPI_ratio),12);
            obj.RewardCount = mgladdtext('0',12);
            obj.RewardDuration = mgladdtext('0',12);
            mglsetproperty(obj.RewardCount,'center','fontsize',fontsize);
            mglsetproperty(obj.RewardDuration,'right','fontsize',fontsize);

            obj.HotkeyLocked = mgladdtext('Hotkey LOCKED (F12)',12);
            mglsetproperty(obj.HotkeyLocked,'right','middle','fontsize',fontsize,'color',[1 0 0]);
            
            obj.EscapeRequested = mgladdtext('Escape',12);
            mglsetproperty(obj.EscapeRequested,'right','middle','fontsize',fontsize);

            reposition_icons(obj,DAQ);
            mglactivategraphic([obj.EyeTracer obj.Eye2Tracer obj.JoystickCursor obj.Joystick2Cursor obj.TouchCursor(:)' obj.MouseCursor obj.ButtonLabel obj.ButtonPressed obj.ButtonReleased],false);
            mglactivategraphic([obj.TTL(:)' obj.Stimulation(:)' obj.Dashboard obj.Reward obj.RewardCount obj.RewardDuration obj.HotkeyLocked obj.EscapeRequested],false);
        end
        function update_tracers(obj,prop,val), mgldestroygraphic(obj.(prop)); obj.(prop) = val; end
        function reposition_icons(obj,DAQ)
            ControlScreenRect = mglgetscreeninfo(2,'Rect') / obj.DPI_ratio;
            ControlScreenSize = ControlScreenRect(3:4) - ControlScreenRect(1:2);
            for m=1:sum(DAQ.nButton)
                if 20 < m, bx = 420 + (mod(m,10)-1)*40; by = ControlScreenSize(2) + 20 - 50*floor((m-1)/10); else, bx = 20 + (m-1)*40; by = ControlScreenSize(2) - 30; end
                mglsetorigin([obj.ButtonLabel(m) obj.ButtonPressed(m) obj.ButtonReleased(m)], [bx by-30; bx by; bx by] * obj.DPI_ratio);
            end
            by = ControlScreenSize(2) - 80;
            for m=1:sum(DAQ.nTTL)
                bx = 20 + (m-1)*40;
                mglsetorigin(obj.TTL(:,m), [bx by-30; bx by] * obj.DPI_ratio);
            end
            by = by-50;
            for m=1:sum(DAQ.nStimulation)
                bx = 20 + (m-1)*40;
                mglsetorigin(obj.Stimulation(:,m), [bx by-30; bx by] * obj.DPI_ratio);
            end
            mglsetorigin([obj.Reward obj.RewardCount obj.RewardDuration], (repmat(ControlScreenSize,3,1) - [41 80; 41 110; 70 85]) * obj.DPI_ratio);
            mglsetorigin(obj.HotkeyLocked, (ControlScreenSize - [30 50]) * obj.DPI_ratio);
            mglsetorigin(obj.EscapeRequested, (ControlScreenSize - [30 30]) * obj.DPI_ratio);
        end
        function create_photodiode(obj,MLConfig)
            if 1 < MLConfig.PhotoDiodeTrigger
                mgldestroygraphic([obj.PhotodiodeBlack obj.PhotodiodeWhite]);
                sz = MLConfig.PhotoDiodeTriggerSize;
                imdata = cat(3,ones(sz,sz),zeros(sz, sz, 3));
                obj.PhotodiodeBlack = mgladdbitmap(imdata,9);
                imdata = ones(sz, sz, 4);
                obj.PhotodiodeWhite = mgladdbitmap(imdata,9);
                half_sz = sz / 2;
                switch MLConfig.PhotoDiodeTrigger
                    case 2  % upper left
                        xori = half_sz;
                        yori = half_sz;
                    case 3  % upper right
                        xori = obj.Xsize - half_sz;
                        yori = half_sz;
                    case 4  % lower right
                        xori = obj.Xsize - half_sz;
                        yori = obj.Ysize - half_sz;
                    case 5  % lower left
                        xori = half_sz;
                        yori = obj.Ysize - half_sz;
                end
                mglsetorigin([obj.PhotodiodeBlack obj.PhotodiodeWhite],[xori yori]);
                mglactivategraphic([obj.PhotodiodeBlack obj.PhotodiodeWhite],[true false]);
            end
        end
    end
end
