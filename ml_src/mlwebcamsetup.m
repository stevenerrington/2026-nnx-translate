function property = mlwebcamsetup(id, property)

if ~exist('id','var'), id = ''; end
if ~exist('property','var'), property = []; end

if isa(id,'videocapture')
    cam = id;
    property = export(cam);
else
    if ~any(strcmpi('webcam',daqhwinfo('all'))), error('No webcam found!!!'); end
    info = daqhwinfo('webcam');
    camid = find(strcmp(id,info.InstalledBoardIds),1);
    if isempty(camid)
        cam = videocapture('webcam',info.InstalledBoardIds{1});
    else
        cam = videocapture('webcam',info.InstalledBoardIds{camid});
        cam.import(property);
    end
end
cam.TriggerType = 'Manual';
info = daqhwinfo(cam); name = info.DeviceName;
Running = cam.Running;
Logging = cam.Logging;
if ~Running, start(cam); end
if ~Logging, trigger(cam); end

% variables
old_property = property;
hDlg = [];
hAxis = [];
hTag = struct;
exit_code = 0;
screensize = get(0,'ScreenSize');
DPI_ratio = mglgetadapterdisplaymode(1) / screensize(3);

% task
err1 = [];
try
    init();
    run_scene();
catch err
    err1 = err;
end

if ishandle(hDlg), close(hDlg); else, exit_code = -1; end
if ~Logging, stop(cam); end
if ~Running, stop(cam); end  % in case of manual trigger, stop it completely
getdata(cam);                % empty the buffer

if 1==exit_code
    property = export(cam);
else
    property = old_property; cam.import(property);
end
if ~isempty(err1), rethrow(err1); end

    function run_scene()
        kbdflush;
        while 0==exit_code
            if ~ishandle(hDlg), exit_code = -1; break, end

            imdata = getdata(cam);
            if ~isempty(imdata.Frame)
                if iscell(imdata.Frame), imdata.Frame = imdata.Frame(end); else, imdata.Frame = imdata.Frame(:,:,end); end
                try
                    image(decodeframe(imdata));
                catch
                    text(0.5,0.5,'Cannot decode the frame','FontSize',15,'HorizontalAlignment','center');
                end
                set(hAxis,'XTick',[]);
                drawnow;
            end

            kb = kbdgetkey();
            if ~isempty(kb)
                switch kb
                    case 1, exit_code = -1;  % esc
                end
            end
            
            pause(0.001);
        end
    end

    function UIcallback(hObject,~)
        obj_tag = get(hObject,'tag');
        switch obj_tag
            case 'Format'
                val = get(gcbo,'value');
                if val==cam.SelectedFormat, return, end
                stop(cam); stop(cam);
                try cam.SelectedFormat = val; catch, end
                set(hTag.FrameRate(1),'string',cam.FrameRate);
                set(hTag.FrameRate(2),'min',cam.FrameRateRange(1),'max',cam.FrameRateRange(2),'value',cam.FrameRate);
                start(cam); trigger(cam); init();
            case 'VerticalFlip'
                val = get(gcbo,'value');
                if val==cam.(obj_tag), return, end
                cam.(obj_tag) = val;
            case {'FrameRate','FrameRateRange'}
                if strcmp(obj_tag,'FrameRate'), val = str2double(get(gcbo,'string')); else, val = get(gcbo,'value'); end
                if val==cam.FrameRate, return, end
                stop(cam); stop(cam);
                try cam.FrameRate = val; catch, end
                set(hTag.FrameRate(1),'string',cam.FrameRate);
                set(hTag.FrameRate(2),'value',cam.FrameRate);
                start(cam); trigger(cam); init();
            case {'Brightness','Contrast','Hue','Saturation','Sharpness','Gamma','ColorEnable','WhiteBalance', ...
                    'BacklightCompensation','Gain','Pan','Tilt','Roll','Zoom','Exposure','Iris','Focus'}
                val = str2double(get(gcbo,'string'));
                range_prop = [obj_tag 'Range'];
                if isempty(cam.(range_prop))
                    cam.(obj_tag) = val;
                else
                    range = cam.(range_prop);
                    cam.(obj_tag) = round((val - range(1))/range(3))*range(3) + range(1);
                    set(hTag.(obj_tag)(1),'string',cam.(obj_tag)(1));
                    set(hTag.(obj_tag)(2),'value',cam.(obj_tag)(1));
                end
            case {'BrightnessRange','ContrastRange','HueRange','SaturationRange','SharpnessRange','GammaRange','ColorEnableRange','WhiteBalanceRange', ...
                    'BacklightCompensationRange','GainRange','PanRange','TiltRange','RollRange','ZoomRange','ExposureRange','IrisRange','FocusRange'}
                value_prop = obj_tag(1:end-5);
                if ~isempty(cam.(value_prop))
                    range = cam.(obj_tag);
                    cam.(value_prop) = round((get(gcbo,'value') - range(1))/range(3))*range(3) + range(1);
                    set(hTag.(value_prop)(1),'string',cam.(value_prop)(1));
                    set(hTag.(value_prop)(2),'value',cam.(value_prop)(1));
                end
            case 'savebutton', exit_code = 1;
            case 'cancelbutton', exit_code = -1;
        end
    end

    function init()
        cw = cam.Width / DPI_ratio;
        ch = cam.Height / DPI_ratio;
        fw = cw + 320;
        fh = max(ch,530);
        if isempty(hDlg)
            hFig = findobj('tag','mlmonitor');
            if isempty(hFig), hFig = findobj('tag','mlmainmenu'); end
            if isempty(hFig), pos = GetMonitorPosition(mglgetcommandwindowrect); else, pos = get(hFig,'position'); end
            scr_pos = GetMonitorPosition(Pos2Rect(pos));

            fx = pos(1) + 0.5 * (pos(3) - fw);
            if fx < scr_pos(1), fx = scr_pos(1) + 8; end
            fy = min(pos(2) + 0.5 * (pos(4) - fh),sum(scr_pos([2 4])) - fh - 30);
            fig_pos = [fx fy fw fh];
        else
            fig_pos = get(hDlg,'Position');
            fig_pos = [fig_pos(1) fig_pos(2)+fig_pos(4)-fh fw fh];
            close(hDlg);
        end
        scr_pos = GetMonitorPosition(fig_pos);
        if scr_pos(3)<fig_pos(3), cw = scr_pos(3)-400; fw = cw+320; fig_pos(1) = (scr_pos(3)-fw)/2; fig_pos(3) = fw; end
        if scr_pos(4)<fig_pos(4), ch = round(cw*cam.Height/cam.Width); fh = max(ch,530); fig_pos(2) = (scr_pos(4)-fh)/2; fig_pos(4) = fh; end
        
        fontsize = 9;
        bgcolor = [0.9255 0.9137 0.8471];
        callbackfunc = @UIcallback;

        hDlg = figure;
        hAxis = gca;
        set(hDlg,'units','pixels','position',fig_pos,'numbertitle','off','name',[name ' Setup'],'menubar','none','resize','off','windowstyle','modal','color',bgcolor);
        set(hAxis,'units','pixels','Position',[0 fh-ch cw ch]);
        
        x0 = cw + 10;
        y0 = fh - 50;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Format','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.Format = uicontrol('parent',hDlg,'style','popupmenu','position',[x0+100 y0+6 200 22],'tag','Format','string',cam.SupportedFormat,'value',cam.SelectedFormat,'fontsize',fontsize,'callback',callbackfunc);
        if isobject(id), set(hTag.Format,'enable','off'); end

        y0 = y0 - 30;
        hTag.VerticalFlip(1) = uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Vertical flip','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.VerticalFlip(2) = uicontrol('parent',hDlg,'style','checkbox','position',[x0+100 y0+10 15 15],'tag','VerticalFlip','value',cam.VerticalFlip,'fontsize',fontsize,'callback',callbackfunc);

        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Frame rate','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.FrameRate(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','FrameRate','fontsize',fontsize,'callback',callbackfunc);
        hTag.FrameRate(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','FrameRateRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.FrameRate), set(hTag.FrameRate,'enable','off'); else, set(hTag.FrameRate(1),'string',cam.FrameRate); if cam.FrameRateRange(1)==cam.FrameRateRange(2), set(hTag.FrameRate(2),'enable','off'); else, set(hTag.FrameRate(2),'min',cam.FrameRateRange(1),'max',cam.FrameRateRange(2),'value',cam.FrameRate(1)); end, end
        
        y0 = y0 - 40;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Brightness','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.Brightness(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Brightness','fontsize',fontsize,'callback',callbackfunc);
        hTag.Brightness(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','BrightnessRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.Brightness), set(hTag.Brightness,'enable','off'); else, set(hTag.Brightness(1),'string',cam.Brightness(1)); if isempty(cam.BrightnessRange), set(hTag.Brightness(2),'enable','off'); else, set(hTag.Brightness(2),'min',cam.BrightnessRange(1),'max',cam.BrightnessRange(2),'value',cam.Brightness(1)); end, end
        
        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Contrast','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.Contrast(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Contrast','fontsize',fontsize,'callback',callbackfunc);
        hTag.Contrast(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','ContrastRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.Contrast), set(hTag.Contrast,'enable','off'); else, set(hTag.Contrast(1),'string',cam.Contrast(1)); if isempty(cam.ContrastRange), set(hTag.Contrast(2),'enable','off'); else, set(hTag.Contrast(2),'min',cam.ContrastRange(1),'max',cam.ContrastRange(2),'value',cam.Contrast(1)); end, end

        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Hue','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.Hue(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Hue','fontsize',fontsize,'callback',callbackfunc);
        hTag.Hue(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','HueRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.Hue), set(hTag.Hue,'enable','off'); else, set(hTag.Hue(1),'string',cam.Hue(1)); if isempty(cam.HueRange), set(hTag.Hue(2),'enable','off'); else, set(hTag.Hue(2),'min',cam.HueRange(1),'max',cam.HueRange(2),'value',cam.Hue(1)); end, end

        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Saturation','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.Saturation(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Saturation','fontsize',fontsize,'callback',callbackfunc);
        hTag.Saturation(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','SaturationRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.Saturation), set(hTag.Saturation,'enable','off'); else, set(hTag.Saturation(1),'string',cam.Saturation(1)); if isempty(cam.SaturationRange), set(hTag.Saturation(2),'enable','off'); else, set(hTag.Saturation(2),'min',cam.SaturationRange(1),'max',cam.SaturationRange(2),'value',cam.Saturation(1)); end, end

        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Sharpness','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.Sharpness(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Sharpness','fontsize',fontsize,'callback',callbackfunc);
        hTag.Sharpness(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','SharpnessRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.Sharpness), set(hTag.Sharpness,'enable','off'); else, set(hTag.Sharpness(1),'string',cam.Sharpness(1)); if isempty(cam.SharpnessRange), set(hTag.Sharpness(2),'enable','off'); else, set(hTag.Sharpness(2),'min',cam.SharpnessRange(1),'max',cam.SharpnessRange(2),'value',cam.Sharpness(1)); end, end

        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Gamma','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.Gamma(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Gamma','fontsize',fontsize,'callback',callbackfunc);
        hTag.Gamma(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','GammaRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.Gamma), set(hTag.Gamma,'enable','off'); else, set(hTag.Gamma(1),'string',cam.Gamma(1)); if isempty(cam.GammaRange), set(hTag.Gamma(2),'enable','off'); else, set(hTag.Gamma(2),'min',cam.GammaRange(1),'max',cam.GammaRange(2),'value',cam.Gamma(1)); end, end

%         y0 = y0 - 30;
%         uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Color enable','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
%         hTag.ColorEnable(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','ColorEnable','fontsize',fontsize,'callback',callbackfunc);
%         hTag.ColorEnable(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','ColorEnableRange','fontsize',fontsize,'callback',callbackfunc);
%         if isempty(cam.ColorEnable), set(hTag.ColorEnable,'enable','off'); else, set(hTag.ColorEnable(1),'string',cam.ColorEnable(1)); if isempty(cam.ColorEnableRange), set(hTag.ColorEnable(2),'enable','off'); else, set(hTag.ColorEnable(2),'min',cam.ColorEnableRange(1),'max',cam.ColorEnableRange(2),'value',cam.ColorEnable(1)); end, end

        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','White balance','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.WhiteBalance(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','WhiteBalance','fontsize',fontsize,'callback',callbackfunc);
        hTag.WhiteBalance(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','WhiteBalanceRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.WhiteBalance), set(hTag.WhiteBalance,'enable','off'); else, set(hTag.WhiteBalance(1),'string',cam.WhiteBalance(1)); if isempty(cam.WhiteBalanceRange), set(hTag.WhiteBalance(2),'enable','off'); else, set(hTag.WhiteBalance(2),'min',cam.WhiteBalanceRange(1),'max',cam.WhiteBalanceRange(2),'value',cam.WhiteBalance(1)); end, end

        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0+7 90 25],'string','Backlight','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        uicontrol('parent',hDlg,'style','text','position',[x0 y0-7 90 25],'string','compensation','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.BacklightCompensation(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','BacklightCompensation','fontsize',fontsize,'callback',callbackfunc);
        hTag.BacklightCompensation(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','BacklightCompensationRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.BacklightCompensation), set(hTag.BacklightCompensation,'enable','off'); else, set(hTag.BacklightCompensation(1),'string',cam.BacklightCompensation(1)); if isempty(cam.BacklightCompensationRange), set(hTag.BacklightCompensation(2),'enable','off'); else, set(hTag.BacklightCompensation(2),'min',cam.BacklightCompensationRange(1),'max',cam.BacklightCompensationRange(2),'value',cam.BacklightCompensation(1)); end, end

%         y0 = y0 - 30;
%         uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Gain','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
%         hTag.Gain(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Gain','fontsize',fontsize,'callback',callbackfunc);
%         hTag.Gain(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','GainRange','fontsize',fontsize,'callback',callbackfunc);
%         if isempty(cam.Gain), set(hTag.Gain,'enable','off'); else, set(hTag.Gain(1),'string',cam.Gain(1)); if isempty(cam.GainRange), set(hTag.Gain(2),'enable','off'); else, set(hTag.Gain(2),'min',cam.GainRange(1),'max',cam.GainRange(2),'value',cam.Gain(1)); end, end
% 
%         y0 = y0 - 30;
%         uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Pan','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
%         hTag.Pan(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Pan','fontsize',fontsize,'callback',callbackfunc);
%         hTag.Pan(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','PanRange','fontsize',fontsize,'callback',callbackfunc);
%         if isempty(cam.Pan), set(hTag.Pan,'enable','off'); else, set(hTag.Pan(1),'string',cam.Pan(1)); if isempty(cam.PanRange), set(hTag.Pan(2),'enable','off'); else, set(hTag.Pan(2),'min',cam.PanRange(1),'max',cam.PanRange(2),'value',cam.Pan(1)); end, end
% 
%         y0 = y0 - 30;
%         uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Tilt','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
%         hTag.Tilt(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Tilt','fontsize',fontsize,'callback',callbackfunc);
%         hTag.Tilt(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','TiltRange','fontsize',fontsize,'callback',callbackfunc);
%         if isempty(cam.Tilt), set(hTag.Tilt,'enable','off'); else, set(hTag.Tilt(1),'string',cam.Tilt(1)); if isempty(cam.TiltRange), set(hTag.Tilt(2),'enable','off'); else, set(hTag.Tilt(2),'min',cam.TiltRange(1),'max',cam.TiltRange(2),'value',cam.Tilt(1)); end, end
% 
%         y0 = y0 - 30;
%         uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Roll','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
%         hTag.Roll(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Roll','fontsize',fontsize,'callback',callbackfunc);
%         hTag.Roll(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','RollRange','fontsize',fontsize,'callback',callbackfunc);
%         if isempty(cam.Roll), set(hTag.Roll,'enable','off'); else, set(hTag.Roll(1),'string',cam.Roll(1)); if isempty(cam.RollRange), set(hTag.Roll(2),'enable','off'); else, set(hTag.Roll(2),'min',cam.RollRange(1),'max',cam.RollRange(2),'value',cam.Roll(1)); end, end

        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Zoom','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.Zoom(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Zoom','fontsize',fontsize,'callback',callbackfunc);
        hTag.Zoom(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','ZoomRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.Zoom), set(hTag.Zoom,'enable','off'); else, set(hTag.Zoom(1),'string',cam.Zoom(1)); if isempty(cam.ZoomRange), set(hTag.Zoom(2),'enable','off'); else, set(hTag.Zoom(2),'min',cam.ZoomRange(1),'max',cam.ZoomRange(2),'value',cam.Zoom(1)); end, end

        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Exposure','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.Exposure(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Exposure','fontsize',fontsize,'callback',callbackfunc);
        hTag.Exposure(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','ExposureRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.Exposure), set(hTag.Exposure,'enable','off'); else, set(hTag.Exposure(1),'string',cam.Exposure(1)); if isempty(cam.ExposureRange), set(hTag.Exposure(2),'enable','off'); else, set(hTag.Exposure(2),'min',cam.ExposureRange(1),'max',cam.ExposureRange(2),'value',cam.Exposure(1)); end, end

        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Iris','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.Iris(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Iris','fontsize',fontsize,'callback',callbackfunc);
        hTag.Iris(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','IrisRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.Iris), set(hTag.Iris,'enable','off'); else, set(hTag.Iris(1),'string',cam.Iris(1)); if isempty(cam.IrisRange), set(hTag.Iris(2),'enable','off'); else, set(hTag.Iris(2),'min',cam.IrisRange(1),'max',cam.IrisRange(2),'value',cam.Iris(1)); end, end

        y0 = y0 - 30;
        uicontrol('parent',hDlg,'style','text','position',[x0 y0 90 25],'string','Focus','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
        hTag.Focus(1) = uicontrol('parent',hDlg,'style','edit','position',[x0+100 y0+5 40 22],'tag','Focus','fontsize',fontsize,'callback',callbackfunc);
        hTag.Focus(2) = uicontrol('parent',hDlg,'style','slider','position',[x0+150 y0+5 150 22],'tag','FocusRange','fontsize',fontsize,'callback',callbackfunc);
        if isempty(cam.Focus), set(hTag.Focus,'enable','off'); else, set(hTag.Focus(1),'string',cam.Focus(1)); if isempty(cam.FocusRange), set(hTag.Focus(2),'enable','off'); else, set(hTag.Focus(2),'min',cam.FocusRange(1),'max',cam.FocusRange(2),'value',cam.Focus(1)); end, end

        y0 = 15;
        hTag.savebutton = uicontrol('parent',hDlg,'style','pushbutton','position',[fw-200 y0 90 25],'tag','savebutton','string','Save','fontsize',fontsize,'callback',callbackfunc);
        hTag.cancelbutton = uicontrol('parent',hDlg,'style','pushbutton','position',[fw-100 y0 90 25],'tag','cancelbutton','string','Cancel (ESC)','fontsize',fontsize,'callback',callbackfunc);
    end
end
