classdef NullTracker < mltracker
    properties (SetAccess = protected)
        XYData
        ClickData
        KeyInput
        LastSamplePosition
    end
    methods
        function obj = NullTracker(MLConfig,TaskObject,CalFun,DataSource,varargin)
            obj@mltracker(MLConfig,TaskObject,CalFun,DataSource,varargin{:});
            obj.Signal = 'Null';
        end
    end
end
