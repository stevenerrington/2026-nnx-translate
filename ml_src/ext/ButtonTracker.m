classdef ButtonTracker < mltracker
    properties (SetAccess = protected)
        ClickData
        LastSamplePosition

        Invert
        Status
        nButton
        ButtonsAvailable
    end
    properties (Access = protected)
        InvertedButtons
    end
    
    methods
        function obj = ButtonTracker(MLConfig,TaskObject,CalFun,DataSource,varargin)
            obj@mltracker(MLConfig,TaskObject,CalFun,DataSource,varargin{:});
            if 0==DataSource && ~MLConfig.DAQ.button_present, error('No button input is defined!!!'); end

            obj.Signal = 'Button';
            obj.nButton = sum(obj.DAQ.nButton);
            obj.ClickData = cell(1,obj.nButton);
            obj.Invert = false(1,obj.nButton);
            obj.Status = false(1,obj.nButton);
            if 1==DataSource, obj.ButtonsAvailable = 1:obj.nButton; else, obj.ButtonsAvailable = obj.DAQ.buttons_available; end

            mglactivategraphic(obj.Screen.ButtonLabel(obj.ButtonsAvailable),true);
        end
        
        function invert(obj,button)
            validate_button(obj,button);
            obj.Invert(button) = ~obj.Invert(button);
            rebuild_button(obj,button);
            obj.InvertedButtons = find(obj.Invert);
        end
        function threshold(obj,button,val)
            validate_button(obj,button);
            obj.DAQ.button_threshold(button,val);
        end
        function label(obj,button,str)
            validate_button(obj,button);
            for m=button(:)', mglsetproperty(obj.Screen.ButtonLabel(m),'text',str); end
        end

        function acquire(obj,p)
            switch obj.DataSource
                case 0, data = p.DAQ.Button; for m=obj.InvertedButtons, data{m} = ~data{m}; end, obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                case 1, p.DAQ.simulated_input(0); data = num2cell(p.DAQ.SimulatedButton); obj.LastSamplePosition = floor(p.trialtime()-1) * ones(1,obj.nButton);
                case 2, data = p.DAQ.Button; obj.LastSamplePosition = p.DAQ.LastSamplePosition;
                otherwise, error('Unknown data source!!!');
            end
            
            obj.Success = ~isempty(data);
            if obj.Success
                obj.ClickData = data;
                for m=obj.ButtonsAvailable
                    if isempty(data{m}), continue, end
                    obj.Status(m) = data{m}(end);
                end
            end
            mglactivategraphic(obj.Screen.ButtonPressed(obj.ButtonsAvailable),obj.Status(obj.ButtonsAvailable));
            mglactivategraphic(obj.Screen.ButtonReleased(obj.ButtonsAvailable),~obj.Status(obj.ButtonsAvailable));
        end
    end
    
    methods (Access = protected)
        function validate_button(obj,button)
            not_button = find(~ismember(button,obj.ButtonsAvailable),1);
            if ~isempty(not_button), error('Button #%d doesn''t exist',not_button(1)); end
        end
        function rebuild_button(obj,button)
            load('mlimagedata.mat','red_pressed','red_released','green_pressed','green_released');
            for m=button(:)'
                if obj.Invert(m)
                    mglsetproperty(obj.Screen.ButtonPressed(m),'bitmap',mglimresize(red_released,obj.Screen.DPI_ratio));
                    mglsetproperty(obj.Screen.ButtonReleased(m),'bitmap',mglimresize(red_pressed,obj.Screen.DPI_ratio));
                else
                    mglsetproperty(obj.Screen.ButtonPressed(m),'bitmap',mglimresize(green_pressed,obj.Screen.DPI_ratio));
                    mglsetproperty(obj.Screen.ButtonReleased(m),'bitmap',mglimresize(green_released,obj.Screen.DPI_ratio));
                end
            end
        end
    end
end
