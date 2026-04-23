function varargout = mlphotodiodetuner(MLConfig)

if isempty(findobj('tag','mlmainmenu')), error('This function cannot be executed from the command line. Call it on the GUI menu'); end
id = mglgetadapteridentifier(MLConfig.SubjectScreenDevice);
if 4318==id.VendorId, MLConfig.RasterThreshold = 0; end  % NVIDIA
varargout{1} = fi(MLConfig.RasterThreshold<0|1<MLConfig.RasterThreshold,0.9,MLConfig.RasterThreshold);

DAQ = MLConfig.DAQ;
Screen = MLConfig.Screen;
MLPath = MLConfig.MLPath;
hFig = [];
hGraph = [];
hTag = struct;
exit_code = 0;
voltage_range = [0 0];
range_manually_set = false;
voltage_threshold = [];
voltage_threshold_prop = 50;
rising_edge = true;
old_threshold = [];
new_threshold = [];
num_trigger = 100;
enable_multishot = 'off';

try
    init();
    dlg_wait();
catch
    % do nothing
end
if ishandle(hFig), close(hFig); end

    function oneshot_sample()
        enable_multishot = 'off';
        [data,present_time,onset_time,trigger_len] = trigger(new_threshold,1,5);
        if ~range_manually_set && ~isempty(data), voltage_range = round([min(data) max(data)]*10)/10; end
        if voltage_range(2)==voltage_range(1), messagebox('No signal detected!!! Cannot perform tuning!!!','e'); return, end
        voltage_threshold = voltage_range(1) + (voltage_range(2)-voltage_range(1)) * voltage_threshold_prop/100;
        rising_edge = data(1) < voltage_threshold;
        
        if rising_edge
            rising = find(data<voltage_threshold & voltage_threshold<[data(2:end); data(end)],1);
            falling = find([data(2:end); data(end)]<voltage_threshold & voltage_threshold<data,1,'last');
        else  % falling_edge
            rising = find([data(2:end); data(end)]<voltage_threshold & voltage_threshold<data,1);
            falling = find(data<voltage_threshold & voltage_threshold<[data(2:end); data(end)],1,'last');
        end
        if isempty(rising), messagebox('No response from the photodiode!!! Cannot perform tuning!!!','e'); return, end
        if rising<onset_time
            messagebox('The photodiode signal is not stable!!! Cannot perform tuning!!!','e');
        else
            enable_multishot = 'on';
            messagebox('Oneshot >> Threshold: %d, Latency: %.1f ms, Duration: %.1f ms',new_threshold,rising-onset_time,falling-rising);
        end
        
        figure_init();
        draw(data,onset_time);
        figure_fini(trigger_len,present_time-onset_time);
        drawnow;
    end
    function figure_init()
        axis(hGraph);
        cla;
    end
    function draw(data,align)
        x = (0:length(data)-1)-align;
        plot(x,data);
    end
    function figure_fini(trigger_len,present)
        xlim = [-1.95 4.95] * Screen.FrameLength;
        ylim = voltage_range + [-0.1 0.1].*repmat(voltage_range(2)-voltage_range(1),1,2);
        hold on;
        plot([0 trigger_len],repmat(voltage_range(1),1,2),'k','linewidth',4);
        plot([present present],ylim,'r:','linewidth',1.5);
        plot([0 0],ylim,'k:','linewidth',1.5);
        plot(xlim,[1 1].*voltage_threshold,'k:','linewidth',1.5);
        set(hGraph,'xlim',xlim,'ylim',ylim);
        xlabel('Time from frame start (msec)');
        ylabel('Volts');
        title('Photodiode response');
        hold off;
    end

    function [data,present_time,onset_time,trigger_len] = trigger(threshold,prepadding_frame,postpadding_frame)
        data = []; onset_time = 0; trigger_len = 0;
        
        start(DAQ); mglwait4vblank(true); mglwait4vblank(false); flushmarker(DAQ); tic; flushdata(DAQ);
        
        mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[true false]); mglrendergraphic;
        for m=1:prepadding_frame, mglwait4vblank(true); mglwait4vblank(false); end
        
        if 0==threshold
            mglwait4vblank(true);
        else
            mdqmex(1,210,1);  % wait4flip
        end
        present_time = 1000*toc;
        mdqmex(9,2);  % present
        if 0==threshold, mglwait4vblank(false); else, mglwait4vblank(true); mglwait4vblank(false); end
        onset_time = 1000*toc;
        
        mglactivategraphic([Screen.PhotodiodeWhite Screen.PhotodiodeBlack],[false true]); mglrendergraphic;
        if 0==threshold
            mglwait4vblank(true);
        else
            mdqmex(1,210,1);  % wait4flip
        end
        mdqmex(9,2);  % present
        if 0==threshold, mglwait4vblank(false); else, mglwait4vblank(true); mglwait4vblank(false); end
        trigger_len = 1000*toc - onset_time;
        
        for m=1:postpadding_frame, mglwait4vblank(true); mglwait4vblank(false); end
        
        backmarker(DAQ); getback(DAQ); data = DAQ.PhotoDiode;
        
        stop(DAQ);
    end

    function update_UI()
        set(hTag.VoltageRange1,'string',voltage_range(1));
        set(hTag.VoltageRange2,'string',voltage_range(2));
        set(hTag.VoltageThreshold,'string',voltage_threshold_prop);
        set(hTag.NumTriggers,'string',num_trigger);
        set(hTag.MultiShotTest,'enable',enable_multishot);
    end
    function UIcallback(hObject,~)
        obj_tag = get(hObject,'tag');
        try
            switch obj_tag
                case 'NewThreshold'
                    val = str2double(get(gcbo,'string'));
                    threshold = raster2threshold(val);
                    if 0 < threshold && threshold < 0.05
                        messagebox(sprintf('Too small a value! Put 0 or a number larger than %d!',threshold2raster(0.05)),'e');
                        set(gcbo,'string',new_threshold);
                    elseif 0<=val && val<=Screen.ScanLine(2)
                        new_threshold = val;
                        mglsetrasterthreshold(raster2threshold(new_threshold));
                    end
                case {'VoltageRange1','VoltageRange2'}
                    val1 = str2double(get(hTag.VoltageRange1,'string'));
                    val2 = str2double(get(hTag.VoltageRange2,'string'));
                    if val1<val2, voltage_range = [val1 val2]; range_manually_set = true; oneshot_sample(); end
                case 'VoltageThreshold'
                    val = str2double(get(gcbo,'string'));
                    if 5<=val && val<=95, voltage_threshold_prop = val; oneshot_sample(); end
                case 'OneShotTest', oneshot_sample();
                case 'NumTriggers'
                    val = round(str2double(get(gcbo,'string')));
                    if 1<val, num_trigger = val; end
                case 'MultiShotTest'
                    set(gcbo,'enable','off');
                    data = cell(num_trigger,1);
                    present_time = NaN(num_trigger,1);
                    onset_time = NaN(num_trigger,1);
                    trigger_len = NaN(num_trigger,1);
                    latency = NaN(num_trigger,1);
                    duration = NaN(num_trigger,1);
                    
                    mglkeepsystemawake(true);
                    for t=1:num_trigger
                        [data{t},present_time(t),onset_time(t),trigger_len(t)] = trigger(new_threshold,1,4);
                        if ~isempty(data)
                            if rising_edge
                                rising = find(data{t}<voltage_threshold & voltage_threshold<[data{t}(2:end); data{t}(end)],1);
                                falling = find([data{t}(2:end); data{t}(end)]<voltage_threshold & voltage_threshold<data{t},1,'last');
                            else  % falling edge
                                rising = find([data{t}(2:end); data{t}(end)]<voltage_threshold & voltage_threshold<data{t},1);
                                falling = find(data{t}<voltage_threshold & voltage_threshold<[data{t}(2:end); data{t}(end)],1,'last');
                            end
                            latency(t) = rising-onset_time(t);
                            duration(t) = falling-rising;
                        end
                    end
                    mglkeepsystemawake(false);
                    
                    figure_init();
                    hold on;
                    for m=1:t, if ~isempty(data{m}), draw(data{m},onset_time(m)); end, end
                    hold off;
                    queueing = present_time-onset_time;
                    figure_fini(mean(trigger_len(~isnan(trigger_len))),mean(queueing(~isnan(queueing))));
                    messagebox('Multishot >> Threshold: %d, Latency: %.1f ms, Duration: %.1f ms',new_threshold,mean(latency(~isnan(latency))),mean(duration(~isnan(duration))),'w');
                    
                case 'DoneButton', exit_code = 1; return;
                case 'CancelButton', exit_code = -1; return;
            end
        catch
            % do nothing
        end
        update_UI();
    end
    function init()
        fig_pos = [0 0 645 400];
        h = findobj('tag','mlmainmenu');
        if isempty(h), screen_pos = GetMonitorPosition(mglgetcommandwindowrect); pos = screen_pos; else, pos = get(h,'position'); screen_pos = GetMonitorPosition(Pos2Rect(pos)); end
        fig_pos(1) = min(max(pos(1) + 0.5 * (pos(3) - fig_pos(3)), screen_pos(1)), sum(screen_pos([1 3])) - fig_pos(3));
        fig_pos(2) = min(max(pos(2) + 0.5 * (pos(4) - fig_pos(4) - 30), screen_pos(2) + 40), sum(screen_pos([2 4])) - fig_pos(4) - 30);
        
        fontsize = 9;
        frame_bgcolor = [0.9255 0.9137 0.8471];
        callbackfunc = @UIcallback;
        
        hFig = figure;
        set(hFig,'tag','mlphotodiodetuner','units','pixels','position',fig_pos,'windowstyle','modal','numbertitle','off','name','MonkeyLogic Photodiode Tuner','menubar','none','resize','off','color',frame_bgcolor);
        set(hFig,'closerequestfcn',@closeDlg);
        
        % create ui
        hGraph = axes('units','pixels','position',[55 190 355 180],'box','on');
        hTag.messagebox = uicontrol('style','listbox','tag','messagebox','string',{'<html><font color="gray">>> End of the messages</font></html>'},'position',[10 10 410 130],'fontsize',fontsize);
        
        create(Screen,MLConfig);
        create_photodiode(Screen,MLConfig);
        default_threshold = threshold2raster(0.9);
        old_threshold = threshold2raster(varargout{1});
        new_threshold = old_threshold;
        
        x0 = 430; bgcolor = frame_bgcolor;
        y0 = fig_pos(4)-40;
        uicontrol('style','pushbutton','position',[x0+145 y0 55 22],'string','Help','fontsize',fontsize,'callback',['web(''' MLPath.DocDirectory 'docs_PhotodiodeTuner.html'',''-browser'')']);
        
        y0 = y0-40;
        uicontrol('style','text','position',[x0+10 y0 190 22],'string','Scanline:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x0+70 y0+4 130 22],'string',sprintf('[%d %d]',Screen.ScanLine),'enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize);
        y0 = y0-25;
        uicontrol('style','text','position',[x0+10 y0 190 22],'string','Default threshold:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x0+120 y0+4 80 22],'string',default_threshold,'enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize);
        y0 = y0-25;
        uicontrol('style','text','position',[x0+10 y0 190 22],'string','Old threshold:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('style','edit','position',[x0+120 y0+4 80 22],'string',old_threshold,'enable','inactive','backgroundcolor',bgcolor,'fontsize',fontsize);
        y0 = y0-25;
        uicontrol('style','text','position',[x0+10 y0 190 22],'string','New threshold:','foregroundcolor',[1 0 0],'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.NewThreshold = uicontrol('style','edit','position',[x0+120 y0+4 80 22],'tag','NewThreshold','string',new_threshold,'fontsize',fontsize,'callback',callbackfunc);
        
        y0 = y0-45;
        uicontrol('style','text','position',[x0+10 y0 190 22],'string','Voltage range:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.VoltageRange1 = uicontrol('style','edit','position',[x0+100 y0+4 30 22],'tag','VoltageRange1','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x0+135 y0 30 22],'string','to','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hTag.VoltageRange2 = uicontrol('style','edit','position',[x0+150 y0+4 30 22],'tag','VoltageRange2','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x0+185 y0 30 22],'string','V','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        y0 = y0-25;
        uicontrol('style','text','position',[x0+10 y0 190 22],'string','Voltage threshold:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.VoltageThreshold = uicontrol('style','edit','position',[x0+120 y0+4 50 22],'string',voltage_threshold_prop,'tag','VoltageThreshold','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x0+175 y0 20 22],'string','%','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        y0 = y0-35;
        uicontrol('style','pushbutton','position',[x0+15 y0+5 185 24],'tag','OneShotTest','string','One-shot test','fontsize',fontsize,'callback',callbackfunc);
        
        y0 = y0-45;
        uicontrol('style','text','position',[x0+10 y0 190 22],'string','# of triggers:','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hTag.NumTriggers = uicontrol('style','edit','position',[x0+90 y0+4 50 22],'tag','NumTriggers','fontsize',fontsize,'callback',callbackfunc);
        uicontrol('style','text','position',[x0+145 y0 50 22],'string','time(s)','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        y0 = y0-35;
        hTag.MultiShotTest = uicontrol('style','pushbutton','position',[x0+15 y0+10 185 24],'tag','MultiShotTest','string','Multi-shot test','fontsize',fontsize,'callback',callbackfunc);
        
        y0 = 15;
        hTag.DoneButton = uicontrol('style','pushbutton','tag','DoneButton','position',[x0+15 y0 90 24],'string','Save','fontsize',fontsize,'callback',callbackfunc);
        hTag.CancelButton = uicontrol('style','pushbutton','tag','CancelButton','position',[x0+110 y0 90 24],'string','Cancel','fontsize',fontsize,'callback',callbackfunc);
        drawnow;
        
        if 4318==id.VendorId  % NVIDIA
            messagebox('This tuner does not work with NVIDIA graphics cards.','e');
            messagebox('You can test different thresholds here but they won''t be used.','e');
        end
        
        for m=1:2, trigger(0,1,5); end  % warming up. do not delete this line.
        oneshot_sample();
        update_UI();
    end
    function dlg_wait()
        kbdflush;
        while 0==exit_code
            if ~ishandle(hFig), exit_code = -1; break, end
            kb = kbdgetkey(); if ~isempty(kb) && 1==kb, exit_code = -1; end
            pause(0.05);
        end
    end
    function closeDlg(~,~)
        if 1==exit_code, varargout{1} = raster2threshold(new_threshold); end
        stop(DAQ);
        destroy(Screen);
        closereq;
    end

    function op = fi(tf,op1,op2)
        if tf, op = op1; else, op = op2; end
    end
    function messagebox(text,varargin)
        if isempty(text), return, end
        nvarargs = length(varargin);
        if 0==nvarargs
            type = 'i';
        else
            nformat = length(regexp(text,'%[0-9\.\-+ #]*[diuoxXfeEgGcs]'));
            text = sprintf(text,varargin{1:nformat});
            if nformat < nvarargs
                type = varargin{end};
            elseif nvarargs == nformat
                type = 'i';
            else
                error('Not enough input arguments');
            end
        end
        fprintf('<<< MonkeyLogic >>> %s\n',text);
        
        switch lower(type(1))
            case 'e',  icon = 'warning.gif'; color = 'red'; %beep;
            case 'w',  icon = 'help_ex.png'; color = 'blue';
            otherwise, icon = 'help_gs.png'; color = 'black';
        end
        icon = fullfile(matlabroot,'toolbox/matlab/icons',icon);
        
        str = get(hTag.messagebox,'string');
        str{end} =  sprintf('<html><img src="file:///%s" height="16" width="16">&nbsp;<font color="%s">%s</font></html>',icon,color,text);
        str{end+1} = '<html><font color="gray">>> End of the messages</font></html>';
        set(hTag.messagebox,'string',str,'value',length(str));
        drawnow;
    end

    function raster = threshold2raster(threshold)
        if 0==threshold, raster = 0; else, raster = Screen.ScanLine(1) + round(threshold * (Screen.ScanLine(2) - Screen.ScanLine(1))); end
    end
    function threshold = raster2threshold(raster)
        if 0==raster, threshold = 0; else, threshold = (raster - Screen.ScanLine(1)) / (Screen.ScanLine(2) - Screen.ScanLine(1)); end
    end
end
