function prop = mleyetrackersetup(prop,id)

old_prop = prop;
tracker = id{1};
eyeid = id{2};
nparam = 10;

w = 385 ; h = 550;
pos = get(gcf,'position') + get(findobj('tag','EyeTrackerSetup'),'position'); xymouse = pos(1:2);
x = xymouse(1) - w;
y = xymouse(2) - 150;
fontsize = 9;
bgcolor = [.65 .70 .80];
callback = @pop_proc;

hPop = figure; hc = struct;
set(hPop,'units','pixels','position',[x y w h],'menubar','none','numbertitle','off','name',tracker,'color',bgcolor,'windowstyle','modal');

err = [];
try
    x0 = 50; y0 = h-10;
    uicontrol('parent',hPop,'style','pushbutton','position',[w-160 10 70 25],'tag','done','string','Done','fontsize',fontsize,'callback',callback);
    uicontrol('parent',hPop,'style','pushbutton','position',[w-80 10 70 25],'tag','cancel','string','Cancel','fontsize',fontsize,'callback',callback);
    switch eyeid
        case 'myeye'
            x = x0 - 20; y = y0 - 30;
            hc.Binocular(1) = uicontrol('parent',hPop,'style','text','position',[x y 100 25],'string','Binocular','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Binocular(2) = uicontrol('parent',hPop,'style','checkbox','position',[x+70 y+5 22 22],'value',0<prop.MyEyeTracker.Source(1),'backgroundcolor',bgcolor,'fontsize',fontsize);
            y = y - 30;
            hc.NumExtra(1) = uicontrol('parent',hPop,'style','text','position',[x y 100 25],'string','# of Extra','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.NumExtra(2) = uicontrol('parent',hPop,'style','popupmenu','position',[x+70 y+3 40 25],'string',0:10,'value',prop.MyEyeTracker.Source(2)+1,'fontsize',fontsize);
            y = y - 30;
            hc.Protocol(1) = uicontrol('parent',hPop,'style','text','position',[x y 200 25],'string','Protocol','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Protocol(2) = uicontrol('parent',hPop,'style','popupmenu','position',[x+70 y+3 60 25],'string',{'UDP','TCP'},'value',strcmp(prop.MyEyeTracker.Protocol,'TCP')+1,'fontsize',fontsize,'callback',callback);
            hc.Test(1) = uicontrol('parent',hPop,'style','pushbutton','position',[x+210 y+4 120 25],'string','Connection Test','fontsize',fontsize,'callback',@test_eyetracker_connection);
            y = y - 30;
            hc.IP_address(1) = uicontrol('parent',hPop,'style','text','position',[x y 200 25],'string','IP address','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.IP_address(2) = uicontrol('parent',hPop,'style','edit','position',[x+70 y+5 130 25],'string',prop.MyEyeTracker.IP_address,'fontsize',fontsize);
            hc.Test(2) = uicontrol('parent',hPop,'style','text','position',[x+210 y 120 25],'string','','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
            y = y - 30;
            hc.Port(1) = uicontrol('parent',hPop,'style','text','position',[x y 200 25],'string','Port','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Port(2) = uicontrol('parent',hPop,'style','edit','position',[x+70 y+5 80 25],'string',prop.MyEyeTracker.Port,'fontsize',fontsize);
            y = y - 40;
            hc.Note(1) = uicontrol('parent',hPop,'style','text','position',[x y 400 22],'string','This adapter is for interfacing custom eye trackers via Ethernet.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(2) = uicontrol('parent',hPop,'style','text','position',[x y-20 400 22],'string','To be connected with NIMH ML, eye trackers should provide','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(3) = uicontrol('parent',hPop,'style','text','position',[x y-40 400 22],'string','either a UDP client or a TCP server that sends eye measures','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(4) = uicontrol('parent',hPop,'style','text','position',[x y-60 400 22],'string','in comma-separated values (CSV) like this:','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(5) = uicontrol('parent',hPop,'style','text','position',[x y-80 400 22],'string','"eye1_X,eye1_Y,eye2_X,eye2_Y,extra1,extra2,extra3,..."','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');
            hc.Note(6) = uicontrol('parent',hPop,'style','text','position',[x y-100 400 22],'string','X & Y values should be in a range of -10 to 10 approximately.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(7) = uicontrol('parent',hPop,'style','text','position',[x y-120 400 22],'string','For monocular input, put 0s in eye2_X and eye2_Y.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(8) = uicontrol('parent',hPop,'style','text','position',[x y-140 400 22],'string','The total length of the CSV string must not exceed 512 bytes.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');

        case {'viewpoint','vpx2'}
            viewpoint_eye = {'Eye A','Eye B'};
            viewpoint_source = {'None', ...
                'X Gaze Point','X Gaze Point Smoothed','X Gaze Point Corrected','X Gaze Angle','X Gaze Angle Smoothed','X Gaze Angle Corrected','X Pupil Size','X Velocity', ...
                'Y Gaze Point','Y Gaze Point Smoothed','Y Gaze Point Corrected','Y Gaze Angle','Y Gaze Angle Smoothed','Y Gaze Angle Corrected','Y Pupil Size','Y Velocity', ...
                'Pupil Angle','Pupil Aspect Ratio','Total Velocity','Torsion','Drift','Fixation Time','Data Quality'};

            hc.IP_address(1) = uicontrol('parent',hPop,'style','text','position',[x0-5 y0-30 200 25],'string','IP address','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.IP_address(2) = uicontrol('parent',hPop,'style','edit','position',[x0+65 y0-25 130 25],'string',prop.ViewPoint.IP_address,'fontsize',fontsize);
            hc.Port(1) = uicontrol('parent',hPop,'style','text','position',[x0-5 y0-60 200 25],'string','Port','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Port(2) = uicontrol('parent',hPop,'style','edit','position',[x0+65 y0-55 130 25],'string',prop.ViewPoint.Port,'fontsize',fontsize);
            x1 = x0; y1 = y0-90;
            hc.Source(1,1) = uicontrol('parent',hPop,'style','text','position',[x1 y1 60 22],'string','Eye','backgroundcolor',bgcolor,'fontsize',fontsize);
            hc.Source(1,2) = uicontrol('parent',hPop,'style','text','position',[x1+65 y1 170 22],'string','Source','backgroundcolor',bgcolor,'fontsize',fontsize);
            hc.Source(1,3) = uicontrol('parent',hPop,'style','text','position',[x1+235 y1 50 22],'string','Offset','backgroundcolor',bgcolor,'fontsize',fontsize);
            hc.Source(1,4) = uicontrol('parent',hPop,'style','text','position',[x1+280 y1 50 22],'string','Gain','backgroundcolor',bgcolor,'fontsize',fontsize);
            for m=1:nparam
                if 3==m || 5==m, y1 = y1 - 5; end
                for n=1:4
                    x2 = x1; y2 = y1 - 30*m + 10;
                    switch n
                        case 1
                            switch m
                                case 1, uicontrol('parent',hPop,'style','text','position',[x2-50 y2-5 40 22],'string','#1','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                                case 3, uicontrol('parent',hPop,'style','text','position',[x2-50 y2-5 40 22],'string','#2','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                                case 5, uicontrol('parent',hPop,'style','text','position',[x2-50 y2-5 40 22],'string','Extra','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                            end
                            hc.Source(m+1,n) = uicontrol('parent',hPop,'style','popupmenu','position',[x2 y2 60 22],'string',viewpoint_eye,'fontsize',fontsize,'enable',fi(2==m||4==m,'off','on'),'callback',fi(1==m||3==m,callback,[]));
                        case 2
                            switch m
                                case 1, items = viewpoint_source(2:4);
                                case 2, items = viewpoint_source(10:12);
                                case 3, items = viewpoint_source(1:4);
                                case 4, items = viewpoint_source([1 10:12]);
                                otherwise, items = viewpoint_source;
                            end
                            hc.Source(m+1,n) = uicontrol('parent',hPop,'style','popupmenu','position',[x2+65 y2 170 22],'string',items,'fontsize',fontsize,'enable',fi(2==m||4==m,'off','on'),'callback',callback);
                        case 3, hc.Source(m+1,n) = uicontrol('parent',hPop,'style','edit','position',[x2+240 y2-1 40 24],'fontsize',fontsize);
                        case 4, hc.Source(m+1,n) = uicontrol('parent',hPop,'style','edit','position',[x2+285 y2-1 40 24],'fontsize',fontsize);
                    end
                end
            end
            hc.Note(1) = uicontrol('parent',hPop,'style','text','position',[x2 y2-30 400 22],'string','Note 1. Output = (Raw - Offset) * Gain','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(2) = uicontrol('parent',hPop,'style','text','position',[x2 y2-50 400 22],'string','Note 2. To invert output, put a negative gain.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Test(1) = uicontrol('parent',hPop,'style','pushbutton','position',[x0+205 y0-26 120 25],'string','Connection Test','fontsize',fontsize,'callback',@test_eyetracker_connection);
            hc.Test(2) = uicontrol('parent',hPop,'style','text','position',[x0+205 y0-60 120 25],'string','','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
            for m=1:nparam
                for n=1:4
                    switch n
                        case 1, set(hc.Source(m+1,n),'value',prop.ViewPoint.Source(m,n)+1);
                        case 2
                            switch m
                                case 1, val = prop.ViewPoint.Source(m,n)-1;
                                case 2, val = prop.ViewPoint.Source(m,n)-9;
                                case 4, val = [1 zeros(1,8) 2 3 4]; val = val(prop.ViewPoint.Source(m,n));
                                otherwise, val = prop.ViewPoint.Source(m,n);
                            end
                            set(hc.Source(m+1,n),'value',val);
                        case {3,4}, set(hc.Source(m+1,n),'string',prop.ViewPoint.Source(m,n));
                    end
                end
            end

        case 'eyelink'
            eyelink_eye = {'Left','Right','Auto'};
            eyelink_source = {'None','X Raw','X Head Referenced','X Gaze','Y Raw','Y Head Referenced','Y Gaze','Pupil Size'};

            hc.IP_address(1) = uicontrol('parent',hPop,'style','text','position',[x0-5 y0-30 200 25],'string','IP address','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.IP_address(2) = uicontrol('parent',hPop,'style','edit','position',[x0+65 y0-25 130 25],'string',prop.EyeLink.IP_address,'fontsize',fontsize);
            hc.Filter(1) = uicontrol('parent',hPop,'style','text','position',[x0-5 y0-60 200 25],'string','Filter','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Filter(2) = uicontrol('parent',hPop,'style','popupmenu','position',[x0+65 y0-55 130 25],'string',{'Off','Standard','Extra'},'value',prop.EyeLink.Filter+1,'fontsize',fontsize);
            hc.PupilSize(1) = uicontrol('parent',hPop,'style','text','position',[x0-5 y0-90 200 25],'string','Pupil Size','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.PupilSize(2) = uicontrol('parent',hPop,'style','popupmenu','position',[x0+65 y0-85 130 25],'string',{'Area','Diameter'},'value',prop.EyeLink.PupilSize,'fontsize',fontsize);
            x1 = x0; y1 = y0-120;
            hc.Source(1,1) = uicontrol('parent',hPop,'style','text','position',[x1 y1 60 22],'string','Eye','backgroundcolor',bgcolor,'fontsize',fontsize);
            hc.Source(1,2) = uicontrol('parent',hPop,'style','text','position',[x1+65 y1 150 22],'string','Source','backgroundcolor',bgcolor,'fontsize',fontsize);
            hc.Source(1,3) = uicontrol('parent',hPop,'style','text','position',[x1+215 y1 60 22],'string','Offset','backgroundcolor',bgcolor,'fontsize',fontsize);
            hc.Source(1,4) = uicontrol('parent',hPop,'style','text','position',[x1+270 y1 60 22],'string','Gain','backgroundcolor',bgcolor,'fontsize',fontsize);
            for m=1:nparam
                if 3==m || 5==m, y1 = y1 - 5; end
                for n=1:4
                    x2 = x1; y2 = y1 - 30*m + 10;
                    switch n
                        case 1
                            switch m
                                case 1, uicontrol('parent',hPop,'style','text','position',[x2-50 y2-5 40 22],'string','#1','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                                case 3, uicontrol('parent',hPop,'style','text','position',[x2-50 y2-5 40 22],'string','#2','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                                case 5, uicontrol('parent',hPop,'style','text','position',[x2-50 y2-5 40 22],'string','Extra','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                            end
                            hc.Source(m+1,n) = uicontrol('parent',hPop,'style','popupmenu','position',[x2 y2 60 22],'string',eyelink_eye,'fontsize',fontsize,'enable',fi(2==m||4==m,'off','on'),'callback',fi(1==m||3==m,callback,[]));
                        case 2
                            switch m
                                case 1, items = eyelink_source(2); enable = 'off';
                                case 2, items = eyelink_source(5); enable = 'off';
                                case 3, items = eyelink_source(1:2); enable = 'on';
                                case 4, items = eyelink_source([1 5]); enable = 'off';
                                otherwise, items = eyelink_source; enable = 'on';
                            end
                            hc.Source(m+1,n) = uicontrol('parent',hPop,'style','popupmenu','position',[x2+65 y2 150 22],'string',items,'fontsize',fontsize,'enable',enable,'callback',callback);
                        case 3, hc.Source(m+1,n) = uicontrol('parent',hPop,'style','edit','position',[x2+220 y2-1 50 24],'fontsize',fontsize);
                        case 4, hc.Source(m+1,n) = uicontrol('parent',hPop,'style','edit','position',[x2+275 y2-1 50 24],'fontsize',fontsize);
                    end
                end
            end
            hc.Note(1) = uicontrol('parent',hPop,'style','text','position',[x2 y2-30 400 22],'string','Note 1. In the binocular setting, ''Auto'' will be the Left eye.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(2) = uicontrol('parent',hPop,'style','text','position',[x2 y2-50 400 22],'string','Note 2. Output = (Raw - Offset) * Gain','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(3) = uicontrol('parent',hPop,'style','text','position',[x2 y2-70 400 22],'string','Note 3. To invert output, put a negative gain.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Test(1) = uicontrol('parent',hPop,'style','pushbutton','position',[x0+205 y0-26 120 25],'string','Connection Test','fontsize',fontsize,'callback',@test_eyetracker_connection);
            hc.Test(2) = uicontrol('parent',hPop,'style','text','position',[x0+205 y0-60 120 25],'string','','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
            for m=1:nparam
                for n=1:4
                    switch n
                        case 1, set(hc.Source(m+1,n),'value',prop.EyeLink.Source(m,n)+1);
                        case 2
                            switch m
                                case 1, val = prop.EyeLink.Source(m,n)-1;
                                case 2, val = prop.EyeLink.Source(m,n)-4;
                                case 4, val = [1 0 0 0 2]; val = val(prop.EyeLink.Source(m,n));
                                otherwise, val = prop.EyeLink.Source(m,n);
                            end
                            set(hc.Source(m+1,n),'value',val);
                        case {3,4}, set(hc.Source(m+1,n),'string',prop.EyeLink.Source(m,n));
                    end
                end
            end

        case 'iscan'
            iscan_source = {'.Pupil.H1........','.Pupil.V1........','.Pupil.H2........','.Pupil.V2........','As chosen in DQW'};
            niscan_source = length(iscan_source);

            hc.IP_address(1) = uicontrol('parent',hPop,'style','text','position',[x0-5 y0-30 200 25],'string','IP address','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left','visible','off');
            hc.IP_address(2) = uicontrol('parent',hPop,'style','edit','position',[x0+65 y0-25 130 25],'string',prop.ISCAN.IP_address,'fontsize',fontsize,'visible','off');
            hc.Port(1) = uicontrol('parent',hPop,'style','text','position',[x0-5 y0-30 200 25],'string','Port','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Port(2) = uicontrol('parent',hPop,'style','edit','position',[x0+65 y0-25 130 25],'string',prop.ISCAN.Port,'fontsize',fontsize);
            hc.Binocular(1) = uicontrol('parent',hPop,'style','text','position',[x0-5 y0-60 200 25],'string','Binocular','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Binocular(2) = uicontrol('parent',hPop,'style','checkbox','position',[x0+70 y0-50 15 15],'tag','Binocular','value',prop.ISCAN.Binocular,'callback',callback);
            x1 = x0; y1 = y0-90;
            uicontrol('parent',hPop,'style','text','position',[x1-45 y1+7 45 22],'string','Param','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','center');
            uicontrol('parent',hPop,'style','text','position',[x1-45 y1-7 45 22],'string','bank','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','center');
            uicontrol('parent',hPop,'style','text','position',[x1+5 y1 55 22],'string','Channel','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','center');
            uicontrol('parent',hPop,'style','text','position',[x1+65 y1 150 22],'string','Source','backgroundcolor',bgcolor,'fontsize',fontsize);
            uicontrol('parent',hPop,'style','text','position',[x1+215 y1 60 22],'string','Offset','backgroundcolor',bgcolor,'fontsize',fontsize);
            uicontrol('parent',hPop,'style','text','position',[x1+270 y1 60 22],'string','Gain','backgroundcolor',bgcolor,'fontsize',fontsize);
            for m=1:nparam
                for n=1:3
                    x2 = x1; y2 = y1 - 30*m + 10;
                    switch n
                        case 1
                            switch m
                                case 1, uicontrol('parent',hPop,'style','text','position',[x2-45 y2-5 45 22],'string','#1','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
                                case 7, uicontrol('parent',hPop,'style','text','position',[x2-45 y2-5 45 22],'string','#2','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
                            end
                            uicontrol('parent',hPop,'style','text','position',[x2+5 y2-5 45 22],'string',sprintf('#%d',mod(m-1,6)+1),'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
                            hc.Source(m,n) = uicontrol('parent',hPop,'style','popupmenu','position',[x2+65 y2 150 22],'string',{'None',iscan_source{fi(m<niscan_source,m,niscan_source)}},'fontsize',fontsize,'enable',fi(m<3,'off','on'),'callback',callback);
                        case 2, hc.Source(m,n) = uicontrol('parent',hPop,'style','edit','position',[x2+220 y2-1 50 24],'fontsize',fontsize);
                        case 3, hc.Source(m,n) = uicontrol('parent',hPop,'style','edit','position',[x2+275 y2-1 50 24],'fontsize',fontsize);
                    end
                end
            end
            x2 = 10;
            hc.Note(1) = uicontrol('parent',hPop,'style','text','position',[x2 y2-30 400 22],'string','1. The ISCAN system doesn''t allow ML to choose which parameters','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(2) = uicontrol('parent',hPop,'style','text','position',[x2 y2-50 400 22],'string','     to record. It is your responsibility to set Channel #1 & #2 of DQW','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(3) = uicontrol('parent',hPop,'style','text','position',[x2 y2-70 400 22],'string','     to be Horz and Vert positions, respectively, as shown above.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(4) = uicontrol('parent',hPop,'style','text','position',[x2 y2-90 400 22],'string','2. Output = (Raw - Offset) * Gain','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Test(1) = uicontrol('parent',hPop,'style','pushbutton','position',[x0+205 y0-26 120 25],'string','Connection Test','fontsize',fontsize,'callback',@test_eyetracker_connection);
            hc.Test(2) = uicontrol('parent',hPop,'style','text','position',[x0+205 y0-60 120 25],'string','','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
            if ~prop.ISCAN.Binocular, set(hc.Source(3,1),'string',{'None',iscan_source{end}}); set(hc.Source(4,1),'string',{'None',iscan_source{end}}); end
            for m=1:nparam
                for n=1:3
                    switch n
                        case 1, set(hc.Source(m,n),'value',prop.ISCAN.Source(m,n));
                        case {2,3}, set(hc.Source(m,n),'string',prop.ISCAN.Source(m,n));
                    end
                end
            end

        case 'tomrs'
            tomrs_CameraProfile = {'Default','High Resolution','High Speed'};
            tomrs_source = {'None','Pupil-X','Pupil-Y','Pupil Major Semi-Axis','Pupil Minor Semi-Axis','Pupil-Ellipse-Fit-Angle','Corneal Reflection-X','Corneal Reflection-Y','Gaze-X','Gaze-Y'};

            hc.IP_address(1) = uicontrol('parent',hPop,'style','text','position',[x0-25 y0-30 200 25],'string','IP address','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.IP_address(2) = uicontrol('parent',hPop,'style','edit','position',[x0+65 y0-25 130 25],'string',prop.TOMrs.IP_address,'fontsize',fontsize);
            hc.Port(1) = uicontrol('parent',hPop,'style','text','position',[x0-25 y0-60 200 25],'string','Port','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Port(2) = uicontrol('parent',hPop,'style','edit','position',[x0+65 y0-55 130 25],'string',prop.TOMrs.Port,'fontsize',fontsize);
            hc.CameraProfile(1) = uicontrol('parent',hPop,'style','text','position',[x0-25 y0-90 200 25],'string','Camera Profile','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.CameraProfile(2) = uicontrol('parent',hPop,'style','popupmenu','position',[x0+65 y0-85 130 25],'string',tomrs_CameraProfile,'value',find(strcmp(tomrs_CameraProfile,prop.TOMrs.CameraProfile)),'fontsize',fontsize);
            x1 = x0; y1 = y0-120;
            hc.Source(1,1) = uicontrol('parent',hPop,'style','text','position',[x1+65 y1 150 22],'string','Source','backgroundcolor',bgcolor,'fontsize',fontsize);
            hc.Source(1,2) = uicontrol('parent',hPop,'style','text','position',[x1+215 y1 60 22],'string','Offset','backgroundcolor',bgcolor,'fontsize',fontsize);
            hc.Source(1,3) = uicontrol('parent',hPop,'style','text','position',[x1+270 y1 60 22],'string','Gain','backgroundcolor',bgcolor,'fontsize',fontsize);
            for m=1:nparam
                for n=1:3
                    x2 = x1; y2 = y1 - 30*m + 10;
                    switch n
                        case 1
                            switch m
                                case 1, uicontrol('parent',hPop,'style','text','position',[x2-25 y2-5 45 22],'string','Eye X','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
                                case 2, uicontrol('parent',hPop,'style','text','position',[x2-25 y2-5 45 22],'string','Eye Y','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
                                case 3, uicontrol('parent',hPop,'style','text','position',[x2-25 y2-5 45 22],'string','Extra','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
                            end
                            switch m
                                case 1, items = tomrs_source([2 7 9]); enable = 'on';
                                case 2, items = tomrs_source([3 8 10]); enable = 'off';
                                otherwise, items = tomrs_source; enable = 'on';
                            end
                            hc.Source(m,n) = uicontrol('parent',hPop,'style','popupmenu','position',[x2+65 y2 150 22],'string',items,'fontsize',fontsize,'enable',enable,'callback',callback);
                        case 2, hc.Source(m,n) = uicontrol('parent',hPop,'style','edit','position',[x2+220 y2-1 50 24],'fontsize',fontsize);
                        case 3, hc.Source(m,n) = uicontrol('parent',hPop,'style','edit','position',[x2+275 y2-1 50 24],'fontsize',fontsize);
                    end
                end
            end
            x2 = x2-25;
            hc.Note(1) = uicontrol('parent',hPop,'style','text','position',[x2 y2-30 400 22],'string','Note 1. Output = (Raw - Offset) * Gain','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Note(2) = uicontrol('parent',hPop,'style','text','position',[x2 y2-50 400 22],'string','Note 2. To invert output, put a negative gain.','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Test(1) = uicontrol('parent',hPop,'style','pushbutton','position',[x0+205 y0-26 120 25],'string','Connection Test','fontsize',fontsize,'callback',@test_eyetracker_connection);
            hc.Test(2) = uicontrol('parent',hPop,'style','text','position',[x0+205 y0-60 120 25],'string','','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
            for m=1:nparam
                for n=1:3
                    switch n
                        case 1
                            switch m
                                case 1, val = [0 1 0 0 0 0 2 0 3 0]; val = val(prop.TOMrs.Source(m,n));
                                case 2, val = [0 0 1 0 0 0 0 2 0 3]; val = val(prop.TOMrs.Source(m,n));
                                otherwise, val = prop.TOMrs.Source(m,n);
                            end
                            set(hc.Source(m,n),'value',val);
                        case {2,3}, set(hc.Source(m,n),'string',prop.TOMrs.Source(m,n));
                    end
                end
            end

        case 'tobii'
            try
                hc.Tobii = daqhwinfo('tobii');
            catch
                error('No Tobii Pro eye tracker detected!!! Is it turned on? If so, refresh the device list and try again.');
            end
            tobii_source = {'None','Left Eye X','Left Eye Y','Left Eye Pupil','Left Eye Validity','Left Eye Openness','Right Eye X','Right Eye Y','Right Eye Pupil','Right Eye Validity','Right Eye Openness','External Signal'};
            tobii_dev_idx = find(strcmp(hc.Tobii.BoardNames,prop.Tobii.SerialNumber),1); if isempty(tobii_dev_idx), tobii_dev_idx = 1; end
            hc.CalibrationDataFile = prop.Tobii.CalibrationDataFile;

            x1 = 20; y1 = y0-40;
            hc.SerialNum(1) = uicontrol('parent',hPop,'style','text','position',[x1 y1 200 25],'string','Serial Number','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.SerialNum(2) = uicontrol('parent',hPop,'style','popupmenu','position',[x1+90 y1+3 150 25],'string',hc.Tobii.BoardNames,'value',tobii_dev_idx,'fontsize',fontsize,'callback',@update_eyetracker_info);
            y1 = y1-30;
            hc.Frequency(1) = uicontrol('parent',hPop,'style','text','position',[x1 y1 200 25],'string','Gaze Output Frequency','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.Frequency(2) = uicontrol('parent',hPop,'style','popupmenu','position',[x1+150 y1+3 90 25],'string',num2cell(prop.Tobii.GazeOutputFrequency),'value',1,'fontsize',fontsize);
            y1 = y1-30;
            hc.TrackingMode(1) = uicontrol('parent',hPop,'style','text','position',[x1 y1 200 25],'string','Eye Tracking Mode','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.TrackingMode(2) = uicontrol('parent',hPop,'style','popupmenu','position',[x1+150 y1+3 90 25],'string',{prop.Tobii.EyeTrackingMode},'value',1,'fontsize',fontsize);
            y1 = y1-30;
            hc.CalibrationData(1) = uicontrol('parent',hPop,'style','text','position',[x1 y1 100 22],'string','Tobii Calibration','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            hc.CalibrationData(2) = uicontrol('parent',hPop,'style','text','position',[x1+30 y1-20 100 22],'string','Data','backgroundcolor',bgcolor,'fontsize',fontsize,'horizontalalignment','left');
            uicontrol('parent',hPop,'style','pushbutton','position',[x1+100 y1+1 225 25],'tag','export','string','Export from eye tracker to file','fontsize',fontsize,'callback',callback);
            uicontrol('parent',hPop,'style','pushbutton','position',[x1+100 y1-29 90 25],'tag','import','string','File to import','fontsize',fontsize,'callback',callback);
            if isempty(hc.CalibrationDataFile), str = 'No file selected'; else, [~,n,e] = fileparts(hc.CalibrationDataFile); str = [n e]; end
            hc.CalibrationData(3) = uicontrol('parent',hPop,'style','text','position',[x1+200 y1-31 250 22],'string',str,'backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','left');

            update_eyetracker_info();

            y1 = y1-60;
            uicontrol('parent',hPop,'style','text','position',[x1+65 y1 150 22],'string','Source','backgroundcolor',bgcolor,'fontsize',fontsize);
            uicontrol('parent',hPop,'style','text','position',[x1+215 y1 60 22],'string','Offset','backgroundcolor',bgcolor,'fontsize',fontsize);
            uicontrol('parent',hPop,'style','text','position',[x1+270 y1 60 22],'string','Gain','backgroundcolor',bgcolor,'fontsize',fontsize);
            for m=1:nparam
                if 3==m || 5==m, y1 = y1 - 5; end
                for n=1:4
                    x2 = x1; y2 = y1 - 30*m + 10;
                    switch n
                        case 1
                            switch m
                                case 1, items = tobii_source([2 7]); enable = 'on';
                                case 2, items = tobii_source([3 8]); enable = 'off';
                                case 3, items = tobii_source([1 2 7]); enable = 'on';
                                case 4, items = tobii_source([1 3 8]); enable = 'off';
                                otherwise, items = tobii_source; enable = 'on';
                            end
                            hc.Source(m,n) = uicontrol('parent',hPop,'style','popupmenu','position',[x2+65 y2 150 22],'string',items,'fontsize',fontsize,'enable',enable,'callback',callback);
                        case 2, hc.Source(m,n) = uicontrol('parent',hPop,'style','edit','position',[x2+220 y2-1 50 24],'fontsize',fontsize);
                        case 3, hc.Source(m,n) = uicontrol('parent',hPop,'style','edit','position',[x2+275 y2-1 50 24],'fontsize',fontsize);
                        case 4
                            switch m
                                case 1, uicontrol('parent',hPop,'style','text','position',[x2 y2-3 50 22],'string','Eye #1','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                                case 3, uicontrol('parent',hPop,'style','text','position',[x2 y2-3 50 22],'string','Eye #2','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                                case 5, uicontrol('parent',hPop,'style','text','position',[x2 y2-3 50 22],'string','Extra','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','right');
                            end
                    end
                end
            end
            hc.Test(1) = uicontrol('parent',hPop,'style','pushbutton','position',[x0+220 y0-36 100 25],'string','Connection Test','fontsize',fontsize,'callback',@test_eyetracker_connection);
            hc.Test(2) = uicontrol('parent',hPop,'style','text','position',[x0+220 y0-70 100 25],'string','','backgroundcolor',bgcolor,'fontsize',fontsize,'fontweight','bold','horizontalalignment','center');
            for m=1:nparam
                for n=1:3
                    switch n
                        case 1
                            switch m
                                case 1, val = [0 1 0 0 0 0 2 0]; val = val(prop.Tobii.Source(m,n));
                                case 2, val = [0 0 1 0 0 0 0 2]; val = val(prop.Tobii.Source(m,n));
                                case 3, val = [1 0 2 0 0 0 3 0]; val = val(prop.Tobii.Source(m,n));
                                case 4, val = [1 0 2 0 0 0 0 3]; val = val(prop.Tobii.Source(m,n));
                                otherwise, val = prop.Tobii.Source(m,n);
                            end
                            set(hc.Source(m,n),'value',val);
                        case {2,3}, set(hc.Source(m,n),'string',prop.Tobii.Source(m,n));
                    end
                end
            end
    end
    eyetracker_menu_enable();

    pop_exit = 0; pop_wait();
    if 1==pop_exit
        switch eyeid
            case 'myeye'
                prop.MyEyeTracker.Source(1) = get(hc.Binocular(2),'value');
                prop.MyEyeTracker.Source(2) = get(hc.NumExtra(2),'value')-1;
                prop.MyEyeTracker.Protocol = fi(1==get(hc.Protocol(2),'value'),'UDP','TCP');
                prop.MyEyeTracker.IP_address = get(hc.IP_address(2),'string');
                prop.MyEyeTracker.Port = get(hc.Port(2),'string');
            case {'viewpoint','vpx2'}
                prop.ViewPoint.IP_address = get(hc.IP_address(2),'string');
                prop.ViewPoint.Port = get(hc.Port(2),'string');
                for m=1:nparam
                    for n=1:4
                        switch n
                            case 1, prop.ViewPoint.Source(m,n) = get(hc.Source(m+1,n),'value')-1;
                            case 2
                                switch m
                                    case 1, val = 2:4;
                                    case 2, val = 10:12;
                                    case 4, val = [1 10:12];
                                    otherwise, val = 1:length(viewpoint_source);
                                end
                                prop.ViewPoint.Source(m,n) = val(get(hc.Source(m+1,n),'value'));
                            otherwise, prop.ViewPoint.Source(m,n) = str2double(get(hc.Source(m+1,n),'string'));
                        end
                    end
                end
            case 'eyelink'
                prop.EyeLink.IP_address = get(hc.IP_address(2),'string');
                prop.EyeLink.Filter = get(hc.Filter(2),'value')-1;
                prop.EyeLink.PupilSize = get(hc.PupilSize(2),'value');
                for m=1:nparam
                    for n=1:4
                        switch n
                            case 1, prop.EyeLink.Source(m,n) = get(hc.Source(m+1,n),'value')-1;
                            case 2
                                switch m
                                    case 1, val = 2;
                                    case 2, val = 5;
                                    case 4, val = [1 5];
                                    otherwise, val = 1:length(eyelink_source);
                                end
                                prop.EyeLink.Source(m,n) = val(get(hc.Source(m+1,n),'value'));
                            otherwise, prop.EyeLink.Source(m,n) = str2double(get(hc.Source(m+1,n),'string'));
                        end
                    end
                end
            case 'iscan'
                prop.ISCAN.IP_address = get(hc.IP_address(2),'string');
                prop.ISCAN.Port = get(hc.Port(2),'string');
                prop.ISCAN.Binocular = get(hc.Binocular(2),'value');
                for m=1:nparam
                    for n=1:3
                        switch n
                            case 1, prop.ISCAN.Source(m,n) = get(hc.Source(m,n),'value');
                            otherwise, prop.ISCAN.Source(m,n) = str2double(get(hc.Source(m,n),'string'));
                        end
                    end
                end
            case 'tomrs'
                prop.TOMrs.IP_address = get(hc.IP_address(2),'string');
                prop.TOMrs.Port = get(hc.Port(2),'string');
                prop.TOMrs.CameraProfile = tomrs_CameraProfile{get(hc.CameraProfile(2),'value')};
                for m=1:nparam
                    for n=1:3
                        switch n
                            case 1
                                switch m
                                    case 1, val = [2 7 9]; prop.TOMrs.Source(m,n) = val(get(hc.Source(m,n),'value'));
                                    case 2, val = [3 8 10]; prop.TOMrs.Source(m,n) = val(get(hc.Source(m,n),'value'));
                                    otherwise, prop.TOMrs.Source(m,n) = get(hc.Source(m,n),'value');
                                end
                            otherwise, prop.TOMrs.Source(m,n) = str2double(get(hc.Source(m,n),'string'));
                        end
                    end
                end
            case 'tobii'
                prop.Tobii.SerialNumber = get_listbox_item(hc.SerialNum(2));
                prop.Tobii.GazeOutputFrequency = str2double(get_listbox_item(hc.Frequency(2)));
                prop.Tobii.EyeTrackingMode = get_listbox_item(hc.TrackingMode(2));
                prop.Tobii.CalibrationDataFile = hc.CalibrationDataFile;
                for m=1:nparam
                    for n=1:3
                        switch n
                            case 1
                                switch m
                                    case 1, val = [2 7]; prop.Tobii.Source(m,n) = val(get(hc.Source(m,n),'value'));
                                    case 2, val = [3 8]; prop.Tobii.Source(m,n) = val(get(hc.Source(m,n),'value'));
                                    case 3, val = [1 2 7]; prop.Tobii.Source(m,n) = val(get(hc.Source(m,n),'value'));
                                    case 4, val = [1 3 8]; prop.Tobii.Source(m,n) = val(get(hc.Source(m,n),'value'));
                                    otherwise, prop.Tobii.Source(m,n) = get(hc.Source(m,n),'value');
                                end
                            otherwise, prop.Tobii.Source(m,n) = str2double(get(hc.Source(m,n),'string'));
                        end
                    end
                end
        end
    else
        prop = old_prop;
    end
catch err
    % do nothing
end
if ishandle(hPop), close(hPop); end
if ~isempty(err), rethrow(err); end

    function update_eyetracker_info(varargin)
        switch eyeid
            case 'tobii'
                frequency = get_listbox_item(hc.Frequency(2));
                tracking_mode = get_listbox_item(hc.TrackingMode(2));
                eye = eyetracker(eyeid,hc.Tobii.InstalledBoardIds{get(hc.SerialNum(2),'value')});
                info = daqhwinfo(eye);
                set(hc.Frequency(2),'string',num2cell(info.GazeOutputFrequencies));
                set(hc.TrackingMode(2),'string',info.EyeTrackingModes);
                set_listbox_item(hc.Frequency(2),frequency);
                set_listbox_item(hc.TrackingMode(2),tracking_mode);
        end
    end
    function test_eyetracker_connection(varargin)
        set(hc.Test(1),'enable','off');
        set(hc.Test(2),'string','');
        drawnow;
        eye = eyetracker(eyeid);
        try eye.IP_address = get(hc.IP_address(2),'string'); catch, end
        switch eyeid
            case 'myeye'
                eye.setProperty('Port',get(hc.Port(2),'string'));
                eye.setProperty('Protocol',fi(1==get(hc.Protocol(2),'value'),'UDP','TCP'));
                source = [0 0];
            case {'viewpoint','vpx2'}
                eye.setProperty('Port',get(hc.Port(2),'string'));
                source = [0 2 0.5 20];
            case 'eyelink'
                source = [2 2 0 -0.0005];
            case 'iscan'
                eye.setProperty('Port',str2double(get(hc.Port(2),'string')));
                source = [2 0 0.02];
            case 'tomrs'
                eye.setProperty('Port',get(hc.Port(2),'string'));
                eye.setProperty('CameraProfile',tomrs_CameraProfile{get(hc.CameraProfile(2),'value')});
                source = [2 0 1];
            case 'tobii'
                eye.setProperty('GazeOutputFrequency',str2double(get_listbox_item(hc.Frequency(2))));
                eye.setProperty('EyeTrackingMode',get_listbox_item(hc.TrackingMode(2)));
                source = [2 0 1];
            otherwise, error('Unknown TCP/IP eye tracker type!!!');
        end
        switch eyeid
            case 'myeye'
                try
                    eye.Source = source;
                    if 1==get(hc.Protocol(2),'value')
                        tic;
                        while toc<2
                            packet_count = eye.getProperty('PacketCount');
                            connected = 0<packet_count;
                            set(hc.Test(2),'string',sprintf('%d',packet_count),'foregroundcolor',fi(connected,[0 1 0],[1 0 0]));
                            drawnow;
                        end
                    else
                        connected = eye.Connected;
                    end
                catch
                    connected = false;
                end
            case {'viewpoint','vpx2','eyelink','tomrs'}
                try eye.Source = source; connected = eye.Connected; catch, connected = false; end
            case {'iscan','tobii'}
                try
                    eye.Source = source;
                    tic;
                    while toc<2
                        packet_count = eye.getProperty('PacketCount');
                        connected = 0<packet_count;
                        set(hc.Test(2),'string',sprintf('%d',packet_count),'foregroundcolor',fi(connected,[0 1 0],[1 0 0]));
                        drawnow;
                    end
                catch
                    connected = false;
                end
        end
        set(hc.Test(2),'string',fi(connected,'Connected!!!','Failed!!!'),'foregroundcolor',fi(connected,[0 1 0],[1 0 0]));
        delete(eye);
        set(hc.Test(1),'enable','on');
    end
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
        switch obj_tag
            case 'done', pop_exit = 1;
            case 'cancel', pop_exit = -1;
            otherwise
                switch eyeid
                    case {'viewpoint','vpx2','eyelink'}
                        set(hc.Source(3,1),'value',get(hc.Source(2,1),'value'));
                        set(hc.Source(3,2),'value',get(hc.Source(2,2),'value'));
                        set(hc.Source(5,1),'value',get(hc.Source(4,1),'value'));
                        set(hc.Source(5,2),'value',get(hc.Source(4,2),'value'));
                    case 'iscan'
                        if get(hc.Binocular(2),'value')~=prop.ISCAN.Binocular
                            prop.ISCAN.Binocular = get(hc.Binocular(2),'value');
                            if prop.ISCAN.Binocular
                                for a=nparam:-1:5
                                    for b=1:3
                                        switch b
                                            case 1, set(hc.Source(a,b),'string',get(hc.Source(a-2,b),'string'),'value',get(hc.Source(a-2,b),'value'));
                                            case {2,3}, set(hc.Source(a,b),'string',get(hc.Source(a-2,b),'string'));
                                        end
                                    end
                                end
                                for a=3:4
                                    for b=1:3
                                        switch b
                                            case 1, set(hc.Source(a,b),'string',{'None',iscan_source{fi(a<niscan_source,a,niscan_source)}},'value',2,'enable','off');
                                            case {2,3}, set(hc.Source(a,b),'string',get(hc.Source(a-2,b),'string'),'enable','on');
                                        end
                                    end
                                end
                            else
                                for a=3:6
                                    for b=1:3
                                        switch b
                                            case 1, set(hc.Source(a,b),'string',get(hc.Source(a+2,b),'string'),'value',get(hc.Source(a+2,b),'value'));
                                            case {2,3}, set(hc.Source(a,b),'string',get(hc.Source(a+2,b),'string'));
                                        end
                                    end
                                end
                                for a=7:nparam
                                    set(hc.Source(a,1),'string',{'None',iscan_source{fi(a<niscan_source,a,niscan_source)}},'value',1);
                                    set(hc.Source(a,2),'string',0);
                                    set(hc.Source(a,3),'string',1);
                                end
                            end
                        end
                    case 'tomrs'
                        set(hc.Source(2,1),'value',get(hc.Source(1,1),'value'));
                    case 'tobii'
                        switch obj_tag
                            case 'export'
                                mode = get_listbox_item(hc.TrackingMode(2));
                                [file,path] = uiputfile({'*.tobii','Tobii Calibration Data (*.tobii)'},'',sprintf('*.%s.tobii',mode));
                                if ischar(file)
                                    eye = eyetracker(eyeid,hc.Tobii.InstalledBoardIds{get(hc.SerialNum(2),'value')});
                                    eye.setProperty('EyeTrackingMode',mode);
                                    calib_data = uint8(eye.getProperty('CalibrationData'));
                                    fid = fopen([path file],'wb');
                                    fwrite(fid,calib_data,'uint8');
                                    fclose(fid);
                                end
                            case 'import'
                                [file,path] = uigetfile({'*.tobii','Tobii Calibration Data (*.tobii)'});
                                if ischar(file)
                                    hc.CalibrationDataFile = [path file];
                                    set(hc.CalibrationData(3),'string',file);
                                else
                                    hc.CalibrationDataFile = '';
                                    set(hc.CalibrationData(3),'string','No file selected');
                                end
                            otherwise
                                if 1<get(hc.Source(3,1),'value'), set(hc.Source(3,1),'value',2-get(hc.Source(1,1),'value')+2); end
                                set(hc.Source(2,1),'value',get(hc.Source(1,1),'value'));
                                set(hc.Source(4,1),'value',get(hc.Source(3,1),'value'));
                        end
                end
                eyetracker_menu_enable();
        end
    end
    function eyetracker_menu_enable()
        switch eyeid
            case 'myeye'
                set(hc.IP_address,'enable',fi(1==get(hc.Protocol(2),'value'),'off','on'));
            case {'viewpoint','vpx2','eyelink'}
                set(hc.Source(4:5,3:4),'enable',fi(1==get(hc.Source(4,2),'value'),'off','on'));
                set(hc.Source(6,3:4),'enable',fi(1==get(hc.Source(6,2),'value'),'off','on'));
                for a=7:nparam+1
                    if 1==get(hc.Source(a-1,2),'value')
                        set(hc.Source(a,2),'value',1);
                        set(hc.Source(a,1:4),'enable','off');
                    else
                        set(hc.Source(a,1:2),'enable','on');
                        set(hc.Source(a,3:4),'enable',fi(1==get(hc.Source(a,2),'value'),'off','on'));
                    end
                end
            case 'iscan'
                for a=fi(prop.ISCAN.Binocular,5:nparam,3:nparam)
                    if 1==get(hc.Source(a-1,1),'value')
                        set(hc.Source(a,1),'value',1);
                        set(hc.Source(a,1:3),'enable','off');
                    else
                        set(hc.Source(a,1),'enable','on');
                        set(hc.Source(a,2:3),'enable',fi(1==get(hc.Source(a,1),'value'),'off','on'));
                    end
                end
            case 'tomrs'
                set(hc.Source(3,2:3),'enable',fi(1==get(hc.Source(3,1),'value'),'off','on'));
                for a=4:nparam
                    if 1==get(hc.Source(a-1,1),'value')
                        set(hc.Source(a,1),'value',1);
                        set(hc.Source(a,1:3),'enable','off');
                    else
                        set(hc.Source(a,1),'enable','on');
                        set(hc.Source(a,2:3),'enable',fi(1==get(hc.Source(a,1),'value'),'off','on'));
                    end
                end
            case 'tobii'
                set(hc.Source(3:4,2:3),'enable',fi(1==get(hc.Source(3,1),'value'),'off','on'));
                for a=6:nparam
                    if 1==get(hc.Source(a-1,1),'value')
                        set(hc.Source(a,1),'value',1);
                        set(hc.Source(a,1:3),'enable','off');
                    else
                        set(hc.Source(a,1),'enable','on');
                        set(hc.Source(a,2:3),'enable',fi(1==get(hc.Source(a,1),'value'),'off','on'));
                    end
                end
        end
    end
    function op = fi(tf,op1,op2)
        if tf, op = op1; else, op = op2; end
    end
    function str = set_listbox_item(h,item,varargin)
        items = get(h,'string');
        val = find(strcmpi(items,item),1);
        if isempty(val), val = 1; end
        set(h,'value',val,varargin{:});
        str = items{val};
    end
    function str = get_listbox_item(h)
        items = get(h,'string');
        val = get(h,'value');
        str = items{val};
    end
end
