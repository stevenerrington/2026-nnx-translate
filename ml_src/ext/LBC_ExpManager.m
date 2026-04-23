classdef LBC_ExpManager < mlaggregator
    properties (SetAccess = protected)
        PropFixation
    end
    properties (Access = protected)
        ImageChanger
        RewardScheduler
        PulseCounter
        FixAnalyzer
    end
    
    methods
        function obj = LBC_ExpManager(varargin)
            obj@mlaggregator(varargin{:});
        end
        
        function init(obj,p)
            init@mlaggregator(obj,p);
            obj.ImageChanger = get_adapter(obj,'LBC_ImageChanger');
            obj.RewardScheduler = get_adapter(obj,'LBC_RewardScheduler');
            obj.PulseCounter = get_adapter(obj,'PulseCounter');
            obj.FixAnalyzer = get_adapter(obj,'LBC_FixAnalyzer');
        end
        function continue_ = analyze(obj,p)
            continue_ = obj.ImageChanger.analyze(p);
            obj.Success = obj.ImageChanger.Success;
            obj.RewardScheduler.analyze(p);
            obj.PropFixation = obj.RewardScheduler.TotalFixFrame / obj.RewardScheduler.TotalElapsedFrame;
        end
        function draw(obj,p)
            draw@mlaggregator(obj,p);

            elapsed_sec = floor(obj.ImageChanger.ElapsedFrame / obj.Tracker.Screen.RefreshRate);
            elapsed_minutes = floor(elapsed_sec/60);
            elapsed_hours = floor(elapsed_minutes/60);
            elapsed_sec = rem(elapsed_sec,60);
            time_string = sprintf('Elapsed time: %02d:%02d:%02d',elapsed_hours,elapsed_minutes,elapsed_sec);
            if ~isempty(obj.PulseCounter), time_string = [time_string sprintf(', TR pulse: %d',obj.PulseCounter.Count)]; end
            p.dashboard(1,time_string);

%             p.dashboard(2,sprintf('Current image: %s',obj.ImageChanger.CurrentImageName));
            
%             if isempty(obj.RewardScheduler.CurrentSchedule), schedule_str = ''; else, schedule_str = sprintf('#%d (%.1f to %.1f s)',obj.RewardScheduler.CurrentSchedule,obj.RewardScheduler.Schedule(obj.RewardScheduler.CurrentSchedule,2:3)/1000); end
%             p.dashboard(3,sprintf('Reward schedule: %s',schedule_str));
			
%             fix_string = sprintf('Fixation: %.1f%% (= %d / %d)',obj.PropFixation*100,obj.RewardScheduler.TotalFixFrame,obj.RewardScheduler.TotalElapsedFrame);
            fix_string = sprintf('Fixation: %.1f%%',obj.PropFixation*100);
%             if ~isempty(obj.FixAnalyzer), fix_string = [fix_string sprintf(', Break: %d',obj.FixAnalyzer.BreakCount)]; end
%             p.dashboard(4,fix_string);
            p.dashboard(2,fix_string);
            
%             current_fix = obj.RewardScheduler.CurrentFixFrame / obj.Tracker.Screen.RefreshRate;
%             next_reward = (obj.RewardScheduler.NextRewardFrame - obj.RewardScheduler.CurrentFixFrame) / obj.Tracker.Screen.RefreshRate;
%             p.dashboard(5,sprintf('Current fix: %.1f s, To next reward: %.1f s',current_fix,next_reward));
        end
    end
end
