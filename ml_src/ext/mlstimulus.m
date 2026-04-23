classdef mlstimulus < mladapter
    properties
        Trigger = false
        EventMarker = []
    end
    properties (Access = protected)
        Triggered
    end

    methods
        function obj = mlstimulus(varargin)
            obj@mladapter(varargin{:});
        end

        function init(obj,p)
            init@mladapter(obj,p);
            obj.Triggered = false;
        end
    end
end
