if ~exist('eye_','var'), error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
dashboard(1,'Press ''x'' to quit.',[1 0 0]);

% task parameters
fix_window = 3;
fix_wait = 5000;
fix_hold = 800;
view_window_xdeg = 32;
view_window_ydeg = 24;
image_distance_from_center = 7;
view_time = 4000;
view_break = 300;
iti = 3000;
editable('fix_window','fix_wait','fix_hold','view_window_xdeg','view_window_ydeg');
editable('image_distance_from_center','view_time','view_break','iti');

% create scenes
fix1 = SingleTarget(eye_);    % scene 1
fix1.Target = 1;              % TaskObject #1, fixation point
fix1.Threshold = fix_window;
wth1 = WaitThenHold(fix1);
wth1.WaitTime = fix_wait;
wth1.HoldTime = fix_hold;
scene1 = create_scene(wth1,1);

% In the scene 2, three adapter chains are used. The 1st chain checks if
% the eye stays in a view window (i.e., monitor screen). The 2nd and 3rd
% chains analyze the duration of fixation on the left and right images,
% respectively. Concurrent is used to combine them.
fix2 = SingleTarget(eye_);    % 1st chain of scene 2
fix2.Target = 1;
fix2.Threshold = [view_window_xdeg view_window_ydeg];  % in degrees
lh2 = LooseHold(fix2);
lh2.HoldTime = view_time;
lh2.BreakTime = view_break;

fix2a = SingleTarget(eye_);   % 2nd chain of scene 2, fixation on the left image
fix2a.Target = 2;
fix2a.Threshold = TaskObject(2).Size / Screen.PixelsPerDegree;  % image size in degrees
fta2a = FixTimeAnalyzer(fix2a);
pm2a = PropertyMonitor(fta2a);
pm2a.Dashboard = 3;
pm2a.ChildProperty = 'FixTime';
pm2a.Format = 'Left: %d ms';

fix2b = SingleTarget(eye_);   % 3rd chain of scene 2, fixation on the right image
fix2b.Target = 3;
fix2b.Threshold = TaskObject(3).Size / Screen.PixelsPerDegree;
fta2b = FixTimeAnalyzer(fix2b);
pm2b = PropertyMonitor(fta2b);
pm2b.Dashboard = 4;
pm2b.ChildProperty = 'FixTime';
pm2b.Format = 'Right: %d ms';

con2 = Concurrent(lh2);       % Use Concurrent to combine the adapter chains.
con2.add(pm2a);               % Concurrent will run all three chains, but whether to stop the scene or not 
con2.add(pm2b);               % will be determined by lh2 only.

scene2 = create_scene(con2,[2 3]);

% eventcodes
bhv_code(10,'Fixation on',20,'Image on',90,'Reward');

% run the task
error_type = 0;
[~,n,e] = fileparts(TaskObject(2).MoreInfo.Filename);
image1 = [n e];
[~,n,e] = fileparts(TaskObject(3).MoreInfo.Filename);
image2 = [n e];
dashboard(2,sprintf('%s vs %s',image1,image2),[1 1 0]);
dashboard(3,'');
dashboard(4,'');

run_scene(scene1,10);
if wth1.Success
    run_scene(scene2,20);
    if lh2.Success
        goodmonkey(reward_dur,'eventmarker',90);
    else
        error_type = 3;  % break fixation
    end
else
    error_type = 4;  % no fixation
end
idle(50);

trialerror(error_type);
bhv_variable('fix_time',[fta2a.FixTime fta2b.FixTime]);
