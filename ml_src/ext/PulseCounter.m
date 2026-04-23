classdef PulseCounter < mladapter
    properties
        Button
        DummyPulse
    end
    properties (SetAccess = protected)
        Count
        Time
    end
    properties (Access = protected)
        LastData
    end
    
    methods
        function obj = PulseCounter(varargin)
            obj@mladapter(varargin{:});
            if ~strcmp(obj.Tracker.Signal,'Button'), error('PulseCounter needs ButtonTracker.'); end
            obj.Button = obj.Tracker.ButtonsAvailable(1);
            obj.DummyPulse = 0;
        end
        function set.Button(obj,button)
            if ~isscalar(button), error('Please assign a single button.'); end
            if ~ismember(button,obj.Tracker.ButtonsAvailable), error('Button #%d doesn''t exist.',button); end %#ok<*MCSUP>
            obj.Button = button;
        end
        function init(obj,p)
            init@mladapter(obj,p);
            obj.Count = 0;
            obj.Time = [];
            obj.LastData = [];
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            
            data = obj.Tracker.ClickData{obj.Button};
            if isempty(data), continue_ = true; return, end
            
            rising = find(1==diff([obj.LastData; data]));
            if ~isempty(rising), obj.Time = obj.Tracker.LastSamplePosition(obj.Button) + rising; end
            
            obj.Count = obj.Count + length(rising);
            obj.Success = obj.DummyPulse < obj.Count;
            continue_ = ~obj.Success;
            obj.LastData = data(end);
        end
    end
end