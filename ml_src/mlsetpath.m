function varargout = mlsetpath(varargin)

newline = char(10); %#ok<CHARTEN>

if 0 < nargin, [varargout{1},varargout{2}] = search_file(varargin{:}); return, end

path = {};
selpath = NaN;
hFig = [];
hTag = [];
foldericon = fullfile(matlabroot,'toolbox/matlab/icons','foldericon.gif');

if ispref('NIMH_MonkeyLogic','SearchPath'), path = getpref('NIMH_MonkeyLogic','SearchPath'); end
old_path = path;

init();

    function [filepath,filename] = search_file(varargin)
        filepath = varargin{1}; filename = filepath; if isempty(filepath), return, end
        [p,n,e] = fileparts(filepath); filename = [n e];
        
        if isempty(p) || filesep~=p(1) && (length(p)<2 || ':'~=p(2)), p = [pwd filesep p]; end  % relative path
        if filesep~=p(end), p = [p filesep]; end  % p always ends with filesep
        filepath = [p filename];
        if 2==exist(filepath,'file'), return, end
        
        if 1 < nargin
            for d = varargin{2}  % varargin{2} is a cell of directory names
                if isempty(d{1}), continue, end
                if filesep==d{1}(end), filepath = [d{1} filename]; else, filepath = [d{1} filesep filename]; end
                if 2==exist(filepath,'file'), return, end
            end
        end
        if 2 < nargin  % search through relative paths
            d = fileparts(varargin{3});  % varargin{3} is a full path including the filename
            for m=fliplr(find(filesep==p))  % p always ends with filesep
                filepath = [d filesep p(m+1:end) filename];
                if 2==exist(filepath,'file'), return, end
            end
        end
        if ispref('NIMH_MonkeyLogic','SearchPath')  % accessing pref is slow, so do it only when it is necessary
            for d = getpref('NIMH_MonkeyLogic','SearchPath')  % SearchPath always ends with filesep
                filepath = [d{1} filename];
                if 2==exist(filepath,'file'), return, end
            end
        end
        filepath = '';
    end

    function update_UI()
        if isnan(selpath)
            set(hTag.List,'string',add_foldericon(path));
        else
            set(hTag.List,'string',add_foldericon(path),'value',selpath);
            selpath = NaN;
        end
        val = get(hTag.List,'value');
        npath = length(path);

        enable = fi(isempty(val) || any(1==val),'off','on');
        set(hTag.MoveToTop,'enable',enable);
        set(hTag.MoveUp,'enable',enable);
        enable = fi(isempty(val) || any(npath==val),'off','on');
        set(hTag.MoveDown,'enable',enable);
        set(hTag.MoveToBottom,'enable',enable);
        set(hTag.Remove,'enable',fi(isempty(val),'off','on'));
        enable = fi(length(old_path)==npath && (isempty(path) || all(strcmp(old_path,path))),'off','on');
        set(hTag.Save,'enable',enable);
        set(hTag.Revert,'enable',enable);
    end
    function UIcallback(hObject,~)
        obj_tag = get(hObject,'tag');
        switch obj_tag
            case 'AddFolder', p = uigetdir([],'Add Folder to Path'); if 0~=p, p = add_filesep(p); path = ([p mlsetdiff(path,p)]); selpath = 1; end
            case 'AddWithSubfolders'
                p = uigetdir([],'Add to Path with Subfolders');
                if 0~=p
                    p = cellfun(@add_filesep,regexp(genpath(p),'[^;]+','match'),'uniformoutput',false);
                    path = [p mlsetdiff(path,p)];
                    selpath = 1:length(p);
                end
            case 'MoveToTop', val = get(hTag.List,'value'); idx = 1:length(path); path = path([val mlsetdiff(idx,val)]); selpath = 1:length(val);
            case 'MoveUp', val = get(hTag.List,'value');   idx = 1:length(path); selpath = val-1; idx(selpath) = idx(selpath)+1; idx(val) = idx(val)-1; path = path(idx);
            case 'MoveDown', val = get(hTag.List,'value'); idx = 1:length(path); selpath = val+1; idx(selpath) = idx(selpath)-1; idx(val) = idx(val)+1; path = path(idx);
            case 'MoveToBottom', val = get(hTag.List,'value'); npath = length(path); idx = 1:npath; path = path([mlsetdiff(idx,val) val]); selpath = npath-length(val)+1:npath;
            case 'Remove', val = get(hTag.List,'value'); path(val) = []; selpath = [];
            case 'Save', save_path();
            case 'Close', close(); return
            case 'Revert', path = old_path; selpath = [];
        end
        update_UI();
    end

    function init()
        hFig = findobj('tag','mlsetpath');
        if isempty(hFig)
            fig_pos = [0 0 684 449];
            h = findobj('tag','mlmainmenu');
            if isempty(h), screen_pos = GetMonitorPosition(mglgetcommandwindowrect); pos = screen_pos; else, pos = get(h,'position'); screen_pos = GetMonitorPosition(Pos2Rect(pos)); end
            fig_pos(1) = min(max(pos(1) + 0.5 * (pos(3) - fig_pos(3)), screen_pos(1)), sum(screen_pos([1 3])) - fig_pos(3));
            fig_pos(2) = min(max(pos(2) + 0.5 * (pos(4) - fig_pos(4) - 30), screen_pos(2) + 40), sum(screen_pos([2 4])) - fig_pos(4) - 30);
        else
            fig_pos = get(hFig,'position');
            close(hFig);
        end
        
        fontsize = 10;
        bgcolor = [.65 .70 .80];
        callbackfunc = @UIcallback;

        hFig = figure;
        set(hFig,'tag','mlsetpath','units','pixels','position',fig_pos,'numbertitle','off','name','MonkeyLogic Set Path','menubar','none','color',bgcolor,'closerequestfcn',@closeDlg);
        set(hFig,'sizechangedfcn',@on_resize);
        
        hTag.AddFolder = uicontrol('style','pushbutton','tag','AddFolder','string','Add Folder...','fontsize',fontsize,'callback',callbackfunc);
        hTag.AddWithSubfolders = uicontrol('style','pushbutton','tag','AddWithSubfolders','string','Add with Subfolders...','fontsize',fontsize,'callback',callbackfunc);
        hTag.MoveToTop = uicontrol('style','pushbutton','tag','MoveToTop','string','Move to Top','fontsize',fontsize,'callback',callbackfunc);
        hTag.MoveUp = uicontrol('style','pushbutton','tag','MoveUp','string','Move Up','fontsize',fontsize,'callback',callbackfunc);
        hTag.MoveDown = uicontrol('style','pushbutton','tag','MoveDown','string','Move Down','fontsize',fontsize,'callback',callbackfunc);
        hTag.MoveToBottom = uicontrol('style','pushbutton','tag','MoveToBottom','string','Move to Bottom','fontsize',fontsize,'callback',callbackfunc);
        hTag.Remove = uicontrol('style','pushbutton','tag','Remove','string','Remove','fontsize',fontsize,'callback',callbackfunc);

        hTag.List = uicontrol('style','listbox','tag','List','value',[],'min',0,'max',2,'fontsize',fontsize,'callback',callbackfunc);
        hTag.ListTitle = uicontrol('style','text','string','MonkeyLogic Search Path:','horizontalalignment','left','backgroundcolor',bgcolor,'fontsize',fontsize,'callback',callbackfunc);

        hTag.Frame = uicontrol('style','frame','backgroundcolor',bgcolor,'foregroundcolor',bgcolor); 
        hTag.Save = uicontrol('style','pushbutton','tag','Save','string','Save','fontsize',fontsize,'callback',callbackfunc);
        hTag.Close = uicontrol('style','pushbutton','tag','Close','string','Close','fontsize',fontsize,'callback',callbackfunc);
        hTag.Revert = uicontrol('style','pushbutton','tag','Revert','string','Revert','fontsize',fontsize,'callback',callbackfunc);

        on_resize();
        update_UI();
    end
    function on_resize(varargin)
        if isempty(hTag) || ~isfield(hTag,'List'), return, end
        
        fig_pos = get(hFig,'position');
        x = 20;
        y = fig_pos(4) - 60; set(hTag.AddFolder,'position',[x y 150 22]);
        y = y - 32; set(hTag.AddWithSubfolders,'position',[x y 150 22]);
        
        y = min(fig_pos(4) * 0.538,y-24); set(hTag.MoveToTop,'position',[x y 150 22]);
        y = y - 32; set(hTag.MoveUp,'position',[x y 150 22]);
        y = y - 32; set(hTag.MoveDown,'position',[x y 150 22]);
        y = y - 32; set(hTag.MoveToBottom,'position',[x y 150 22]);
        
        y = min(50, y-24); set(hTag.Remove,'position',[x y 150 22]);

        x = 190; w = max(fig_pos(3) - 203,0); h = max(fig_pos(4) - 110 + 22,20); y = min(fig_pos(4) - h - 38,50);
        set(hTag.List,'position',[x y w h]);
        set(hTag.ListTitle,'position',[x y+h w 18]);

        set(hTag.Frame,'position',[0 0 fig_pos(3) 36]);
        
        y = 14; w = 95;
        x = fig_pos(3) - w*3 - 3; set(hTag.Save,'position',[x y 85 22]);
        x = x + w; set(hTag.Close,'position',[x y 85 22]);
        x = x + w; set(hTag.Revert,'position',[x y 85 22]);
    end
    function closeDlg(varargin)
        if length(old_path)~=length(path) || (~isempty(path) && any(~strcmp(old_path,path)))
            options.Interpreter = 'tex';
            options.Default = 'Yes';
            qstring = ['\fontsize{10}Do you wish to save the current path' newline 'for use in future MonkeyLogic sessions?'];
            answer = questdlg(qstring, 'Save Path','Yes','No',options);
            if strcmp(answer,'Yes'), save_path(); end
        end
        closereq;
    end

    function p = add_filesep(p), if filesep~=p(end), p(end+1) = filesep; end, end
    function p = add_foldericon(p)
        if ischar(p), p = {p}; end
        for m=1:length(p)
            p{m} = sprintf('<html><img src="file:///%s" height="13" width="15">&nbsp;%s</html>',foldericon,p{m});
        end
    end
    function save_path()
        setpref('NIMH_MonkeyLogic','SearchPath',path);
        old_path = path;
    end
    function op = fi(tf,op1,op2)
        if tf, op = op1; else, op = op2; end
    end
end
