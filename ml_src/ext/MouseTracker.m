classdef MouseTracker < mltracker
    properties (SetAccess = protected)
        XYData
        ClickData
        KeyInput
        LastSamplePosition
        ButtonsAvailable
    end
    properties (Access = protected)
        CursorOffset
        param
    end
    
    methods
        function obj = MouseTracker(MLConfig,TaskObject,CalFun,DataSource,Param,varargin)
            obj@mltracker(MLConfig,TaskObject,CalFun,DataSource,varargin{:});
            if 0==DataSource && ~MLConfig.DAQ.mouse_present, error('Enable Mouse first!!!'); end
            obj.Signal = 'Mouse';
            obj.ClickData = cell(1,2);
            obj.ButtonsAvailable = 1:2;
            sz = floor(0.5*obj.Screen.MouseCursorSize);
            obj.CursorOffset = [sz; sz; -10 0; 20 0];
            obj.param = Param;
        end
        function showcursor(obj,val), obj.param.Cursor.ShowMouse = val; end
        function setCursorPos(obj,xy_deg,y_deg)
            if isscalar(xy_deg), xy_deg = [xy_deg y_deg]; end
            xy_pix = obj.CalFun.deg2pix(xy_deg);
            if 0==obj.DataSource, xy = obj.CalFun.pix2subject(xy_pix); else, xy = obj.CalFun.pix2control(xy_pix); end
            mglsetcursorpos(xy);
        end
       
        function tracker_init(obj,p)
            if 2==obj.DataSource
                mglactivategraphic(obj.Screen.MouseCursor(2),p.Cursor.ShowMouse);  % replay
            else
                mglactivategraphic(obj.Screen.MouseCursor(1:2),[p.Cursor.ShowMouse ~p.SimulationMode]);
            end
        end
        function tracker_fini(obj,~)
            mglactivategraphic(obj.Screen.MouseCursor,false);
        end
        function acquire(obj,p)
            button = [];
            switch obj.DataSource
                case 0
                    data = p.DAQ.Mouse;
                    if ~isempty(data)
                        obj.XYData = obj.CalFun.subject2pix(data);
                        button = p.DAQ.MouseButton;
                        obj.KeyInput = p.DAQ.KeyInput;
                    end
                    obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                case 1
                    [data,button] = getsample(p.Mouse);
                    if ~isempty(data)
                        obj.XYData = obj.CalFun.control2pix(data);
                        if 2<size(button,2), obj.KeyInput = button(:,3:end); end
                    end
                    obj.LastSamplePosition = floor(p.trialtime()-1);
                case 2
                    data = p.DAQ.Mouse;
                    if ~isempty(data)
                        obj.XYData = obj.CalFun.deg2pix(data);
                        button = p.DAQ.MouseButton;
                        obj.KeyInput = p.DAQ.KeyInput;
                    end                    
                    obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                otherwise, error('Unknown data source!!!');
            end
            
            obj.Success = ~isempty(button);
            if obj.Success
                obj.ClickData{1} = button(:,1);
                obj.ClickData{2} = button(:,2);
                xy = obj.XYData(end,1:2);
                mglsetorigin(obj.Screen.MouseCursor,[xy; xy; xy; xy] + obj.CursorOffset);
                if ~p.SimulationMode, mglactivategraphic(obj.Screen.MouseCursor(3:4),button(end,1:2)); end
            end
        end
    end
end
