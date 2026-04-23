classdef EyeTracker < mltracker
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
        function obj = EyeTracker(MLConfig,TaskObject,CalFun,DataSource,varargin)
            obj@mltracker(MLConfig,TaskObject,CalFun,DataSource,varargin{:});
            if 0==DataSource && ~MLConfig.DAQ.eye_present, error('Eye X & Y are not assigned!!!'); end
            obj.Signal = 'Eye';
        end
        
        function tracker_init(obj,~)
            mglactivategraphic(obj.Screen.EyeTracer,true);
        end
        function tracker_fini(obj,~)
            mglactivategraphic(obj.Screen.EyeTracer,false);
        end
        function acquire(obj,p)
            switch obj.DataSource
                case 0, data = p.DAQ.Eye;          if ~isempty(data), obj.XYData = obj.CalFun.sig2pix(data,p.EyeOffset); end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                case 1, data = getsample(p.Mouse); if ~isempty(data), obj.XYData = obj.CalFun.control2pix(data); end, obj.LastSamplePosition = floor(p.trialtime()-1);
                case 2, data = p.DAQ.Eye;          if ~isempty(data), obj.XYData = obj.CalFun.deg2pix(data); end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                otherwise, error('Unknown data source!!!');
            end
            
            obj.Success = ~isempty(obj.XYData);
            if obj.Success
                if obj.Screen.EyeLineTracer, mglsetproperty(obj.Screen.EyeTracer,'addpoint',obj.XYData); else, mglsetproperty(obj.Screen.EyeTracer,'origin',obj.XYData(end,:)); end
            end
        end
    end
end
