classdef SingleButton < mladapter
    properties
        Button
    end
    properties (Hidden)
        TouchMode = false
    end
    properties (SetAccess = protected)
        In
        Time
    end
    properties (Access = protected)
        LastData
        LastStateChange
    end
    
    methods
        function obj = SingleButton(varargin)
            obj@mladapter(varargin{:});
            obj.Button = obj.Tracker.ButtonsAvailable(1);
        end
        function val = fieldnames(obj), val = [fieldnames@mladapter(obj); 'TouchMode']; end
        
        function set.Button(obj,val)
            if ~isscalar(val), error('Please assign a single button'); end
            if ~ismember(val,obj.Tracker.ButtonsAvailable), error('Button #%d doesn''t exist',val); end %#ok<*MCSUP>
            obj.Button = val;
            switch obj.Tracker.DataSource
                case 0, obj.TouchMode = obj.Tracker.DAQ.isdigitalbutton(val);
                case 1, obj.TouchMode = true;
            end
        end
        function init(obj,p)
            init@mladapter(obj,p);
            if isempty(obj.Button), error('No button is assigned'); end
            obj.Time = [];
            obj.LastData = [];
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            
            obj.In = obj.Tracker.ClickData{obj.Button};
            if isempty(obj.In), continue_ = true; return, end
            idx = length(obj.Tracker.LastSamplePosition);
            if obj.Button < idx, idx = obj.Button; end
            
            if isempty(obj.LastData)
                obj.LastData = obj.In(1);
                obj.LastStateChange = obj.Tracker.LastSamplePosition(idx);
            end
            c = diff([obj.LastData; obj.In]);  % 0: no change, 1: down, -1: up
            obj.LastData = obj.In(end);
            
            d = find(0~=c,1,'last');  % empty when there is no state change
            if ~isempty(d), obj.LastStateChange = obj.Tracker.LastSamplePosition(idx) + d; end

            if obj.TouchMode  % update status immediately
                obj.Success = obj.LastData;
                obj.Time = obj.LastStateChange;
            else
                if isempty(d)  % update status after the signal becomes stable
                    obj.Success = obj.LastData;
                    obj.Time = obj.LastStateChange;
                end
            end
            continue_ = ~obj.Success;
        end
    end
end