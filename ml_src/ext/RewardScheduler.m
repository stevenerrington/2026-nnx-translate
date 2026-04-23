classdef RewardScheduler < mladapter
    properties
        Schedule
        JuiceLine = 1
    end
    properties (SetAccess = protected)
        SuccessFrameCount
        NextRewardFrame
    end
    properties (Access = protected)
        TimeInFrames
    end
    
    methods
        function obj = RewardScheduler(varargin)
            obj@mladapter(varargin{:});
        end
        function set.Schedule(obj,val)
            [a,b] = size(val);
            list = NaN(a,5);
            list(:,1:b) = val;
            obj.Schedule = list;
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            obj.TimeInFrames = ceil(obj.Schedule(:,1:3) / obj.Tracker.Screen.FrameLength);
            obj.NextRewardFrame = obj.TimeInFrames(1,1);
            obj.SuccessFrameCount = 0;
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            if obj.Success
                obj.SuccessFrameCount = obj.SuccessFrameCount + 1;
            else
                obj.SuccessFrameCount = 0; obj.NextRewardFrame = 0;
            end

            ScheduleIndex = find(obj.TimeInFrames(:,1) < obj.SuccessFrameCount,1,'last');
            if ~isempty(ScheduleIndex) && obj.NextRewardFrame < obj.SuccessFrameCount
                min_interval = obj.TimeInFrames(ScheduleIndex,2);
                max_interval = obj.TimeInFrames(ScheduleIndex,3);
                duration = obj.Schedule(ScheduleIndex,4);
                code = obj.Schedule(ScheduleIndex,5);
                
                p.goodmonkey(duration,'juiceline',obj.JuiceLine,'eventmarker',code,'nonblocking',2);
                obj.NextRewardFrame = obj.NextRewardFrame + round(min_interval + rand * (max_interval-min_interval));
            end
        end
    end
end
