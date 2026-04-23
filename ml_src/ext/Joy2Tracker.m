classdef Joy2Tracker < mltracker
    properties
        TracerImage
        TracerShape
        TracerColor
        TracerSize
    end
    properties (SetAccess = protected)
        XYData
        LastSamplePosition
    end
    properties (Access = protected)
        param
    end
    
    methods
        function obj = Joy2Tracker(MLConfig,TaskObject,CalFun,DataSource,Param,varargin)
            obj@mltracker(MLConfig,TaskObject,CalFun,DataSource,varargin{:});
            if 0==DataSource && ~MLConfig.DAQ.joystick2_present, error('Joystick2 not assigned!!!'); end
            obj.Signal = 'Joystick2';
            obj.param = Param;
        end
        function showcursor(obj,val), obj.param.Cursor.ShowJoy2 = [val obj.param.Cursor.ShowJoy2(1)|val]; end

        function set.TracerImage(obj,val), val = obj.validate_path(val); obj.param.Cursor.JoystickCursorImage{2} = val; update_cursor(obj); end %#ok<*MCSUP>
        function set.TracerShape(obj,val), obj.param.Cursor.JoystickCursorShape{2} = val; update_cursor(obj); end
        function set.TracerColor(obj,val), obj.param.Cursor.JoystickCursorColor(2,:) = val; update_cursor(obj); end
        function set.TracerSize(obj,val), obj.param.Cursor.JoystickCursorSize(2) = val; update_cursor(obj); end
        function val = get.TracerImage(obj), val = obj.param.Cursor.JoystickCursorImage{2}; end
        function val = get.TracerShape(obj), val = obj.param.Cursor.JoystickCursorShape{2}; end
        function val = get.TracerColor(obj), val = obj.param.Cursor.JoystickCursorColor(2,:); end
        function val = get.TracerSize(obj), val = obj.param.Cursor.JoystickCursorSize(2); end
        
        function tracker_init(obj,p)
            if 2==obj.DataSource
                if ~p.User.CustomTrackers, update_cursor(obj); end
                mglactivategraphic(obj.Screen.Joystick2Cursor(2),p.Cursor.ShowJoy2(1));
            else
                mglactivategraphic(obj.Screen.Joystick2Cursor,p.Cursor.ShowJoy2);
            end
        end
        function tracker_fini(obj,~)
            mglactivategraphic(obj.Screen.Joystick2Cursor,false);
        end
        function acquire(obj,p)
            switch obj.DataSource
                case 0, data = p.DAQ.Joystick2;          if ~isempty(data), obj.XYData = obj.CalFun.sig2pix(data,p.Joy2Offset); end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                case 1, data = p.DAQ.SimulatedJoystick2; if ~isempty(data), obj.XYData = obj.CalFun.deg2pix(data); end, obj.LastSamplePosition = floor(p.trialtime()-1);
                case 2, data = p.DAQ.Joystick2;          if ~isempty(data), obj.XYData = obj.CalFun.deg2pix(data); end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                otherwise, error('Unknown data source!!!');
            end
            
            obj.Success = ~isempty(obj.XYData);
            if obj.Success, mglsetorigin(obj.Screen.Joystick2Cursor,obj.XYData(end,:)); end
        end
    end
    methods (Access = protected)
        function update_cursor(obj)
            if 2==obj.DataSource
                cursor = [NaN load_cursor(obj.TracerImage,obj.TracerShape,obj.TracerColor,obj.TracerSize,10)];
            else
                cursor = [load_cursor(obj.TracerImage,obj.TracerShape,obj.TracerColor,obj.TracerSize,11) ...
                    load_cursor(obj.TracerImage,obj.TracerShape,obj.TracerColor,obj.TracerSize,10,0)];
            end
            obj.Screen.update_tracers('Joystick2Cursor',cursor);
        end
    end
end
