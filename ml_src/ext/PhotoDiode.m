classdef PhotoDiode < mladapter
    properties
        Mode = 'Frame'
    end
    properties (Access = protected)
        Replaying
        IsFrameMode = true
    end
    methods
        function obj = PhotoDiode(varargin)
            obj@mladapter(varargin{:});
            obj.Replaying = 2==obj.Tracker.DataSource;
            if ~obj.Replaying && (isempty(obj.Tracker.Screen.PhotodiodeWhite) || isempty(obj.Tracker.Screen.PhotodiodeBlack))
                error('Photodiode trigger is not set on the main menu!!!');
            end
        end
        function init(obj,p)
            init@mladapter(obj,p);
            obj.IsFrameMode = strcmpi(obj.Mode,'frame');
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
        end
        function draw(obj,p)
            draw@mladapter(obj,p);
            if ~obj.Replaying
                toggle = 0 < p.scene_frame();
                if ~obj.IsFrameMode, toggle = toggle && ~isempty(p.EventMarker); end
                
                if toggle
                    p.PhotoDiodeStatus = ~p.PhotoDiodeStatus;
                    mglactivategraphic([p.Screen.PhotodiodeWhite p.Screen.PhotodiodeBlack],[p.PhotoDiodeStatus ~p.PhotoDiodeStatus]);
                end
            end
        end
    end
end
