function view_latency(signal,time,config,filename)
% time (based on the CPU timer; in milliseconds)
% col 4 : recording start time at which all previously collected samples are dumped
% col 7 : play command issuance time
% (col4 - col3) : time taken to dump the samples.
% (col6 - col5) : time taken to send out TTL
% (col7 - col6) : time taken to get the sample count
% (col8 - col7) : time taken to excute the play command

% latency (based on the recorded samples except col 2; in milliseconds)
% col 1: time of play command issuance (calculated from the sample count)
% col 2: time of play command issuance (measured by the CPU timer)
% col 3: time of play command issuance (calculated from the recorded TTL)
% col 4: length of the TTL (~100 ms)
% col 5: sound onset time
% col 6: length of the recorded sound (~100 ms)
% col 7: peak count (should be 100)

if ~exist('signal','var')
    [filename,filepath] = uigetfile({'*.mat','Latency data (*.mat)'});
    if isnumeric(filename), error('No file selected!'); end
    load([filepath filename],'signal','time','latency','config');
end
if ischar(signal)
    [~,filename] = fileparts(signal);
    load(signal,'signal','time','latency','config');
end

hTag = [];
fontsize = 10;
callback = @UIcallback;
win = [0.0439 0.2494 0.7066 1.0000 0.7066 0.2494 0.0439];
win = win / sum(win);

init();
% quantile(time(6:end,3),0:0.25:1)
% mean(time(6:end,:))

    function draw()
        no = get(hTag.TrialNo(2),'value');
        axis(hTag.Axis); cla;
        data = signal{no};
        if isempty(data), return, end

        fs = 48000;
        if isfield(config,'fs'), fs = config.fs; end
        if isfield(config,'info'), fs = config.info.fs; end

        data(:,1) = conv(data(:,1),win,'same');
        dv1 = [0; diff(data(:,1))];                         % 1st derivative
        dv2 = [0; diff(dv1)];                               % 2nd derivative

        max_snd = max(data(:,1));
        ub = 0.05 * max_snd;
        peak = find(1==diff(ub<dv1));                       % find points where voltage increased more than 5%

        % remove irregular peaks before and after the sound
        peak_interval = diff(peak);
        cr = 1.5 * median(peak_interval);
        while cr < peak_interval(1), peak(1) = []; peak_interval(1) = []; end
        while cr < peak_interval(end), peak(end) = []; peak_interval(end) = []; end

        first = find(signal{no}(1:peak(1),1)<ub,1,'last');  % find where the first peak began
        last = peak(end)+find(dv2(peak(end):end)<=0,1);   % find where the last peak ended
        sot = first * 1000 / fs;                            % sound onset time
        duration = (last-first-1) * 1000 / fs;

        peak(last<=peak) = [];
        peak(end) = [];
        peakcount = length(peak);

        x = (1:length(data)) * 1000 / fs;
        plot(x,signal{no}); hold on;
        set(gca,'XLim',[0 150]);
        plot(x(peak),signal{no}(peak,1),'rx');
        plot([first last] * 1000 / fs,[0 0],'k-','linewidth',2);
        legend('Sound','Peak','Duration','AutoUpdate','off');

        text(sot,0.2,sprintf('Latency: %.2f ms',sot),'color',[0 0 0],'fontweight','bold');
        text(sot+duration*0.5,max_snd+0.2,sprintf('Duration: %.2f ms',duration),'color',[0 0 0],'fontweight','bold','horizontalalignment','center');
        text(sot+duration,0.2,sprintf('Peak %d',peakcount),'color',[0 0 0],'fontweight','bold','horizontalalignment','right');

        title(sprintf('Trial %d',no));
    end
    function UIcallback(hObject,~)
        obj_tag = get(hObject,'tag');
        switch obj_tag
            case 'Load'
                [filename,filepath] = uigetfile({'*.mat','Latency data (*.mat)'});
                if ~isnumeric(filename)
                    load([filepath filename],'signal','time','latency','config');
                    set(hTag.Figure,'name',filename);
                    set(hTag.TrialNo(2),'string',1:length(signal),'value',1);
                    draw();
                end
            case 'TrialNo', draw();
        end
    end
     function init()
        hTag.Figure = figure;

        set(hTag.Figure,'tag','view_latency','units','pixels','numbertitle','off','name',filename);
        set(hTag.Figure,'sizechangedfcn',@on_resize);

        hTag.TrialNo(1) = uicontrol('style','text','string','Trial #','HorizontalAlignment','center','fontsize',fontsize);
        hTag.TrialNo(2) = uicontrol('style','listbox','tag','TrialNo','string',1:length(signal),'value',1,'fontsize',fontsize,'callback',callback);

        hTag.Axis = gca;
        set(hTag.Axis,'units','pixels');

        hTag.Load = uicontrol('style','pushbutton','tag','Load','string','Load','fontsize',fontsize,'callback',callback);

        on_resize();
        draw();
    end

    function on_resize(varargin)
        fig_pos = get(hTag.Figure,'position');
        w = 60; x = fig_pos(3)-20-w;
        y = fig_pos(4) - 40;
        set(hTag.TrialNo(1),'position',[x y w 22]);
        
        h = max(y-60,20);
        set(hTag.TrialNo(2),'position',[x 60 w h]);
        set(hTag.Axis,'outerposition',[20 20 fig_pos(3)-w-60 fig_pos(4)-40]);
        set(hTag.Load,'position',[fig_pos(3)-w-20 20 w 25]);
    end
end