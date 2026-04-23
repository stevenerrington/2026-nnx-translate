function prop = mllabstreaminglayersetup(prop)

nstream = size(prop.Stream,1);
w = 350; h = 120 + nstream*60;
xymouse = get(0, 'PointerLocation');
x = xymouse(1) - w;
y = xymouse(2) - 50;
fontsize = 9;
bgcolor = [.65 .70 .80];
callback = @pop_proc;

hPop = figure; hc = [];
set(hPop,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name','Lab Streaming Layer Setup','color',bgcolor,'windowstyle','modal');

err = [];
try
    x0 = 10; y0 = h-40;
    hdone = uicontrol('parent',hPop,'style','pushbutton','position',[w-160 10 70 25],'tag','done','string','Done','enable','off','fontsize',fontsize,'callback',callback);
    uicontrol('parent',hPop,'style','pushbutton','position',[w-80 10 70 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',callback);
    
    a = uicontrol('parent',hPop,'style','text','position',[(w-300)*0.5 h*0.75 300 25],'string','Searching for streams...','backgroundcolor',bgcolor,'fontsize',12,'fontweight','bold');
    drawnow;
    
    lsl = lsl_resolve_all(lsl_loadlib(),2);
    nlsl = length(lsl);
    lsl_id = cell(nlsl,5);
    lsl_str = cell(nlsl,1);
    for m=1:nlsl
        lsl_id(m,:) = { lsl{m}.name() lsl_get_hostname(lsl{m}.LibHandle,lsl{m}.InfoHandle) lsl{m}.type() lsl{m}.channel_count() lsl{m}.channel_format() };
        lsl_str{m} = sprintf('%s (%s, %s, %d ch, %s)',lsl_id{m,:});
    end
    lsl_str = ['Manually type'; lsl_str];
    
    delete(a);
    
    x = x0; y = y0;
    uicontrol('parent',hPop,'style','text','position',[x y 100 25],'string','Buffer length','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
    hbuf = uicontrol('parent',hPop,'style','edit','position',[x+86 y+5 40 22],'string',prop.BufferLength,'fontsize',fontsize);
    uicontrol('parent',hPop,'style','text','position',[x+130 y 40 25],'string','sec','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
    y = y-40;
    for m=1:nstream
        idx = find(strcmp(lsl_id(:,1),prop.Stream{m,1}),1); idx = fi(isempty(idx),1,idx+1);
        uicontrol('parent',hPop,'style','text','position',[x y 100 25],'string','Stream','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        uicontrol('parent',hPop,'style','text','position',[x+15 y-15 100 25],'string',sprintf('#%d',m),'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        hc(m,1) = uicontrol('parent',hPop,'style','popupmenu','position',[x+50 y+3 280 25],'tag',sprintf('stream%d',m),'string',lsl_str,'value',idx,'fontsize',fontsize,'callback',callback);
        uicontrol('parent',hPop,'style','text','position',[x+50 y-25 100 25],'string','Name','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
        hc(m,2) = uicontrol('parent',hPop,'style','edit','position',[x+86 y-19 120 22],'string',prop.Stream{m,1},'enable',fi(1==idx,'on','off'),'fontsize',fontsize,'horizontalalignment','left','callback',callback);
        hc(m,3) = uicontrol('parent',hPop,'style','pushbutton','position',[x+210 y-19 50 22],'tag',sprintf('clearbtn%d',m),'string','Clear','enable',fi(1==idx,'on','off'),'fontsize',fontsize,'callback',callback);
        hmsg = uicontrol('parent',hPop,'style','text','position',[20 40 300 25],'string','Do not choose the same stream more than once.','visible','off','foregroundcolor',[1 0 0],'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
        y = y-60;
    end
    pop_update();
    
    drawnow; pop_exit = 0; pop_wait();
    if 1==pop_exit
        prop.BufferLength = str2double(get(hbuf,'string'));
        for m=1:nstream, prop.Stream{m} = get(hc(m,2),'string'); end
    end
catch err
    % do nothing
end
if ishandle(hPop), close(hPop); end
if ~isempty(err), rethrow(err); end

    function pop_wait()
        kbdflush;
        while 0==pop_exit
            if ~ishandle(hPop), pop_exit = -1; break, end
            kb = kbdgetkey(); if ~isempty(kb) && 1==kb, pop_exit = -1; end
            pause(0.05);
        end
    end
    function pop_proc(hObject,~)
        obj_tag = get(hObject,'tag');
        switch obj_tag(1:min(length(obj_tag),6))
            case 'done', pop_exit = 1;
            case 'cancel', pop_exit = -1;
            case 'stream'
                no = str2double(regexp(obj_tag,'\d+','match'));
                val = get(gcbo,'value');
                if 1==val
                    set(hc(no,2),'enable','on');
                    set(hc(no,3),'enable','on');
                else
                    set(hc(no,2),'string',lsl_id{val-1,1},'enable','off');
                    set(hc(no,3),'enable','off');
                end
            case 'clearb'
                no = str2double(regexp(obj_tag,'\d+','match'));
                set(hc(no,2),'string','');
        end
        pop_update();
    end
    function pop_update(varargin)
        str = cell(nstream,1);
        for n=1:nstream, str{n} = get(hc(n,2),'string'); end
        str = str(~cellfun(@isempty,str));
        all_unique = size(str,1)==size(unique(str),1);
        set(hmsg,'visible',fi(all_unique,'off','on'));
        set(hdone,'enable',fi(all_unique,'on','off'));
    end
    function op = fi(tf,op1,op2)
        if tf, op = op1; else, op = op2; end
    end
end
