classdef Eye2Tracker < mltracker
    properties (SetAccess = protected)
        XYData
        LastSamplePosition
    end
    properties (Hidden)  % These were settable properties
        TracerShape
        TracerColor
        TracerSize
    end
    
    methods
        function obj = Eye2Tracker(MLConfig,TaskObject,CalFun,DataSource,varargin)
            obj@mltracker(MLConfig,TaskObject,CalFun,DataSource,varargin{:});
            if 0==DataSource && ~MLConfig.DAQ.eye2_present, error('Eye2 X & Y are not assigned!!!'); end
            obj.Signal = 'Eye2';
        end
        
        function tracker_init(obj,~)
            mglactivategraphic(obj.Screen.Eye2Tracer,true);
        end
        function tracker_fini(obj,~)
            mglactivategraphic(obj.Screen.Eye2Tracer,false);
        end
        function acquire(obj,p)
            switch obj.DataSource
                case 0, data = p.DAQ.Eye2;          if ~isempty(data), obj.XYData = obj.CalFun.sig2pix(data,p.Eye2Offset); end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                case 1, data = p.DAQ.SimulatedEye2; if ~isempty(data), obj.XYData = obj.CalFun.deg2pix(data); end, obj.LastSamplePosition = floor(p.trialtime()-1);
                case 2, data = p.DAQ.Eye2;          if ~isempty(data), obj.XYData = obj.CalFun.deg2pix(data); end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                otherwise, error('Unknown data source!!!');
            end
            
            obj.Success = ~isempty(obj.XYData);
            if obj.Success
                if obj.Screen.Eye2LineTracer, mglsetproperty(obj.Screen.Eye2Tracer,'addpoint',obj.XYData); else, mglsetproperty(obj.Screen.Eye2Tracer,'origin',obj.XYData(end,:)); end
            end
        end
    end
end
