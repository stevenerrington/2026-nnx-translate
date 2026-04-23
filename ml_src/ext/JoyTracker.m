classdef JoyTracker < mltracker
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
        function obj = JoyTracker(MLConfig,TaskObject,CalFun,DataSource,Param,varargin)
            obj@mltracker(MLConfig,TaskObject,CalFun,DataSource,varargin{:});
            if 0==DataSource && ~MLConfig.DAQ.joystick_present, error('Joystick not assigned!!!'); end
            obj.Signal = 'Joystick';
            obj.param = Param;
        end
        function showcursor(obj,val), obj.param.Cursor.ShowJoy = [val obj.param.Cursor.ShowJoy(1)|val]; end

        function set.TracerImage(obj,val), val = obj.validate_path(val); obj.param.Cursor.JoystickCursorImage{1} = val; update_cursor(obj); end %#ok<*MCSUP>
        function set.TracerShape(obj,val), obj.param.Cursor.JoystickCursorShape{1} = val; update_cursor(obj); end
        function set.TracerColor(obj,val), obj.param.Cursor.JoystickCursorColor(1,:) = val; update_cursor(obj); end
        function set.TracerSize(obj,val), obj.param.Cursor.JoystickCursorSize(1) = val; update_cursor(obj); end
        function val = get.TracerImage(obj), val = obj.param.Cursor.JoystickCursorImage{1}; end
        function val = get.TracerShape(obj), val = obj.param.Cursor.JoystickCursorShape{1}; end
        function val = get.TracerColor(obj), val = obj.param.Cursor.JoystickCursorColor(1,:); end
        function val = get.TracerSize(obj), val = obj.param.Cursor.JoystickCursorSize(1); end
        
        function tracker_init(obj,p)
            if 2==obj.DataSource
                if ~p.User.CustomTrackers, update_cursor(obj); end
                mglactivategraphic(obj.Screen.JoystickCursor(2),p.Cursor.ShowJoy(1));
            else
                mglactivategraphic(obj.Screen.JoystickCursor,p.Cursor.ShowJoy);
            end
        end
        function tracker_fini(obj,~)
            mglactivategraphic(obj.Screen.JoystickCursor,false);
        end
        function acquire(obj,p)
            switch obj.DataSource
                case 0, data = p.DAQ.Joystick;          if ~isempty(data), obj.XYData = obj.CalFun.sig2pix(data,p.JoyOffset); end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                case 1, data = p.DAQ.SimulatedJoystick; if ~isempty(data), obj.XYData = obj.CalFun.deg2pix(data); end, obj.LastSamplePosition = floor(p.trialtime()-1);
                case 2, data = p.DAQ.Joystick;          if ~isempty(data), obj.XYData = obj.CalFun.deg2pix(data); end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                otherwise, error('Unknown data source!!!');
            end
            
            obj.Success = ~isempty(obj.XYData);
            if obj.Success, mglsetorigin(obj.Screen.JoystickCursor,obj.XYData(end,:)); end
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
            obj.Screen.update_tracers('JoystickCursor',cursor);
        end
    end
end
