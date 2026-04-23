classdef mldaq_playback < handle
    properties
        Eye
        Eye2
        Joystick
        Joystick2
        Button
        General
        Touch
        Mouse
        MouseButton
        KeyInput
        
        nSampleFromMarker
        LastSamplePosition
    end
    properties (SetAccess = protected)  % output
        Stimulation
        TTL

        nJoystick = 2
        nButton
        nGeneral
        nStimulation = 4
        nTTL = 16
        nWebcam = 4
        nKey
        nLSL
    end
    properties (SetAccess = protected, Hidden)
        Map
        ButtonsAvailable
        GeneralAvailble
        TTLInvert
    end
    
    methods
        function obj = mldaq_playback(), end
        function obj = create(obj,MLConfig,AnalogData)
            if ~exist('AnalogData','var'), return, end
            
            obj.Map.Eye = ~isempty(AnalogData.Eye);
            obj.Map.Joystick = ~isempty(AnalogData.Joystick);
            
            label = fieldnames(AnalogData.General);
            obj.nGeneral = length(label);
            obj.Map.General = false(obj.nGeneral,1);
            obj.GeneralAvailble = [];
            for m=1:obj.nGeneral
                obj.Map.General(m) = ~isempty(AnalogData.General.(label{m}));
                if obj.Map.General(m), obj.GeneralAvailble(end+1) = m; end
            end
            
            ao = analogoutput_playback; for m=1:obj.nStimulation, addchannel(ao,m-1,sprintf('Stimulation%d',m)); end
            obj.Stimulation = cell(1,obj.nStimulation); for m=1:obj.nStimulation, if isempty(obj.Stimulation{m}), obj.Stimulation{m} = ao; end, end
            
            dio = digitalio_playback; for m=1:obj.nTTL, addline(dio,m-1,0,'Out',sprintf('TTL%d',m)); end
            obj.TTL = cell(1,obj.nTTL); for m=1:obj.nTTL, if isempty(obj.TTL{m}), obj.TTL{m} = dio; end, end
            obj.TTLInvert = false(1,obj.nTTL);
            for m=1:length(MLConfig.IO)
                switch (MLConfig.IO(m).SignalType(1:3))
                    case 'TTL'
                        no = str2double(regexp(MLConfig.IO(m).SignalType,'\d+','match'));
                        obj.TTLInvert(no) = MLConfig.IO(m).Invert;
                end
            end
            
            % The existence of the following fields is version-dependent
            obj.Map.Eye2 = isfield(AnalogData,'Eye2') && ~isempty(AnalogData.Eye2);
            obj.Map.Joystick2 = isfield(AnalogData,'Joystick2') && ~isempty(AnalogData.Joystick2);
            obj.Map.Touch = isfield(AnalogData,'Touch') && ~isempty(AnalogData.Touch);
            obj.Map.Mouse = isfield(AnalogData,'Mouse') && ~isempty(AnalogData.Mouse);

            if isfield(AnalogData,'Button')
                label = fieldnames(AnalogData.Button);
                obj.nButton = length(label);
                obj.Map.Button = false(obj.nButton,1);
                obj.ButtonsAvailable = [];
                for m=1:obj.nButton
                    obj.Map.Button(m) = ~isempty(AnalogData.Button.(label{m}));
                    if obj.Map.Button(m), obj.ButtonsAvailable(end+1) = m; end
                end
            else
                obj.Map.Button = false;
            end
            if isfield(AnalogData,'KeyInput')
                obj.nKey = size(AnalogData.KeyInput,2);
                obj.Map.KeyInput = ~isempty(AnalogData.KeyInput);
            end
            if isfield(AnalogData,'LSL')
                label = fieldnames(AnalogData.LSL);
                obj.nLSL = length(label);
            end
        end
        function eventmarker(~,~), end
        function goodmonkey(~,~,varargin), end

        function val = eye_present(obj), val = obj.Map.Eye; end
        function val = eye2_present(obj), val = obj.Map.Eye2; end
        function val = joystick_present(obj), val = obj.Map.Joystick; end
        function val = joystick2_present(obj), val = obj.Map.Joystick2; end
        function val = button_present(obj), val = any(obj.Map.Button(:,1)); end
        function val = touch_present(obj), val = obj.Map.Touch; end
        function val = mouse_present(obj), val = obj.Map.Mouse; end
        function val = keyinput_present(obj), val = obj.Map.KeyInput; end  % This method doesn't exist in mldaq.
        function val = usbjoystick_present(~), val = false; end
        function val = usbjoystick2_present(~), val = false; end
        function val = buttons_available(obj), val = obj.ButtonsAvailable; end
        function val = general_available(obj), val = obj.GeneralAvailble; end
        function val = ttl_available(obj), val = 1:obj.nTTL; end
        function val = stimulation_available(obj), val = 1:obj.nStimulation; end
%         function val = reward_present(~), val = false; end
%         function val = strobe_present(~), val = false; end
        function button_threshold(~,~,~), end
%         function val = get_device(~,~), val = []; end

        function val = get.Eye(obj), val = obj.Eye; obj.LastSamplePosition = obj.nSampleFromMarker; end
        function val = get.Eye2(obj), val = obj.Eye2; obj.LastSamplePosition = obj.nSampleFromMarker; end
        function val = get.Joystick(obj), val = obj.Joystick; obj.LastSamplePosition = obj.nSampleFromMarker; end
        function val = get.Joystick2(obj), val = obj.Joystick2; obj.LastSamplePosition = obj.nSampleFromMarker; end
        function val = get.Button(obj), val = obj.Button; obj.LastSamplePosition = repmat(obj.nSampleFromMarker,1,obj.nButton); end
        function val = get.General(obj), val = obj.General; obj.LastSamplePosition = repmat(obj.nSampleFromMarker,1,obj.nGeneral); end
        function val = get.Touch(obj), val = obj.Touch; obj.LastSamplePosition = obj.nSampleFromMarker; end
        function val = get.Mouse(obj), val = obj.Mouse; obj.LastSamplePosition = obj.nSampleFromMarker; end
        function val = get.MouseButton(obj), val = obj.MouseButton; obj.LastSamplePosition = obj.nSampleFromMarker; end
        function val = get.KeyInput(obj), val = obj.KeyInput; obj.LastSamplePosition = obj.nSampleFromMarker; end
        
%         function start(~), end
%         function stop(~), end
%         function val = isrunning(~), val = false; end
%         function flushdata(~), end
%         function flushmarker(~), end
%         function frontmarker(~), end
%         function backmarker(~), end
%         function val = MinSamplesAvailable(~), val = 0; end
%         function getsample(~), end
%         function peekfront(~), end
%         function getback(~), end
%         function getdata(~), end
%         function peekdata(~,~), end
    end        
end
