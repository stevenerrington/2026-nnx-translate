classdef BlackrockLED < mlstimulus
    properties
        MaxIntensity  % 0 to 1
    end
    properties (SetAccess = protected)
        ID
        Temperature
    end
    
    methods
        function obj = BlackrockLED(varargin)
            obj@mlstimulus(varargin{:});
            try
                obj.ID = BlackrockLED_init;
            catch err
                if 0==obj.Tracker.DataSource, rethrow(err); else, obj.ID = NaN; end
            end
            mglactivatesound(obj.ID,false);

            obj.MaxIntensity = 0.5;
        end
        function delete(obj), mgldestroysound(obj.ID); end

        function set.MaxIntensity(obj,val), BlackrockLED_setmax(obj.ID,val); obj.MaxIntensity = val; end %#ok<*MCSUP>
        function val = get.Temperature(obj), val = BlackrockLED_temp(obj.ID); end

        function setmax(obj,intensity), obj.MaxIntensity = intensity; end
        function load(obj,intensity,duration), BlackrockLED_load(obj.ID,intensity,duration); end
        function temperature = temp(obj,ver), temperature = BlackrockLED_temp(obj.ID,ver); end

        function init(obj,p)
            init@mlstimulus(obj,p);
            if ~obj.Trigger
                obj.Triggered = true;
                mglactivatesound(obj.ID,true);
            end
        end
        function fini(obj,p)
            fini@mlstimulus(obj,p);
            mglactivatesound(obj.ID,false);
        end
        function continue_ = analyze(obj,p)
            analyze@mlstimulus(obj,p);
            if obj.Triggered
                if 0<p.scene_frame()
                    isplaying = mglgetproperty(obj.ID,'isplaying');
                    obj.Success = isempty(isplaying) | ~isplaying;
                end
            else
                if obj.Adapter.Success
                    obj.Triggered = true;
                    mglactivatesound(obj.ID,true);
                    p.eventmarker(obj.EventMarker);
                end
            end
            continue_ = ~obj.Success;
        end
    end
end
