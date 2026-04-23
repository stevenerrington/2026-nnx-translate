classdef TouchTracker_v1 < mltracker
    properties (SetAccess = protected)
        XYData
        ClickData
        MouseData
        LastSamplePosition
    end
    properties (Hidden)
        TracerImage
        TracerShape
        TracerColor
        TracerSize
    end
    
    methods
        function obj = TouchTracker_v1(MLConfig,TaskObject,CalFun,DataSource,varargin)
            obj@mltracker(MLConfig,TaskObject,CalFun,DataSource,varargin{:});
            if 0==DataSource && ~MLConfig.DAQ.mouse_present, error('Enable Touch first!!!'); end
            obj.Signal = 'Touch';
        end
        
        function tracker_fini(obj,~)
            mglactivategraphic(obj.Screen.TouchCursor,false);
        end
        function acquire(obj,p)
            switch obj.DataSource
                case 0
                    if ~isempty(p.DAQ.Mouse)
                        obj.XYData = obj.CalFun.subject2pix(p.DAQ.Mouse);
                        obj.MouseData = obj.XYData;
                        obj.ClickData{1} = p.DAQ.MouseButton(:,1);
                        obj.ClickData{2} = p.DAQ.MouseButton(:,2);
                        obj.XYData(~obj.ClickData{1},:) = NaN;
                    end
                    obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                case 1
                    [mouse,button] = getsample(p.Mouse);
                    if ~isempty(mouse)
                        obj.XYData = obj.CalFun.control2pix(mouse);
                        obj.MouseData = obj.XYData;
                        obj.ClickData{1} = button(1);
                        obj.ClickData{2} = button(2);
                        obj.XYData(~obj.ClickData{1},:) = NaN;
                    end
                    obj.LastSamplePosition = floor(p.trialtime());
                case 2
                    if ~isempty(p.DAQ.Mouse)
                        obj.XYData = obj.CalFun.deg2pix(p.DAQ.Mouse);
                        obj.MouseData = obj.XYData;
                        obj.ClickData{1} = p.DAQ.MouseButton(:,1);
                        obj.ClickData{2} = p.DAQ.MouseButton(:,2);
                        obj.XYData(~obj.ClickData{1},:) = NaN;
                    end
                    obj.LastSamplePosition = floor(p.trialtime() - size(obj.ClickData{1},1));
                otherwise, error('Unknown data source!!!');
            end
            
            if ~isempty(obj.XYData)
                if any(isnan(obj.XYData(end,:)))
                    mglactivategraphic(obj.Screen.TouchCursor,false);
                else
                    mglactivategraphic(obj.Screen.TouchCursor(1,2),true);
                    mglsetorigin(obj.Screen.TouchCursor(1,2),obj.XYData(end,:));
                end
                obj.Success = true;
            else
                obj.Success = false;
            end
        end
    end
end
