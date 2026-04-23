classdef MyMultiTarget < mladapter
    properties
        Target = [0 0]  % [x1 y1; x2 y2; ...]
        HoldTime = 800  % in milliseconds
        Threshold = 3   % in degrees
    end
    properties (SetAccess = protected)
        Order           % visit order
        Time            % visit time (approximate)
    end
    properties (Access = protected)
        EndTime         % timer for visit confirmation
    end
    
    methods
        function obj = MyMultiTarget(varargin)
            obj@mladapter(varargin{:});
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            obj.Order = [];
            obj.Time = [];
            obj.EndTime = zeros(length(obj.Target),1);
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            
            eye_pos = obj.Tracker.CalFun.pix2deg(obj.Tracker.XYData(end,:));  % XYData is in pixels, so convert it to degrees
            distance = sum((obj.Target - repmat(eye_pos,size(obj.Target,1),1)).^2,2);
            in = distance < obj.Threshold*obj.Threshold;
            
            t = p.trialtime();
            obj.EndTime(0==obj.EndTime & in) = t + obj.HoldTime;  % newly picked stimulus
            obj.EndTime(t<obj.EndTime & ~in) = 0;                 % previously picked but fixation broken

            selected = find(obj.EndTime<t & in);                  % visit confirmed
            obj.EndTime(selected) = NaN;                          % mark not to track further
            obj.Order = [obj.Order; selected];                    % make a record
            obj.Time = [obj.Time; repmat(t,length(selected),1)];

            obj.Success = any(isnan(obj.EndTime));                % success if any target is chosen
            continue_ = true;
        end
    end
end
