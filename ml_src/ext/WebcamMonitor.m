classdef WebcamMonitor < mladapter
    properties
        CamNumber = 1               % Webcam #
        Position = [0.6 0 0.4 0.4]  % [left top width height]
        UpdateInterval = 2          % update intervals in frames
        Screen = 2
    end
    properties (SetAccess = protected)
        GraphicID
    end
    properties (Access = protected)
        Replaying
        ScrPos
    end

    methods
        function obj = WebcamMonitor(varargin)
            obj@mladapter(varargin{:});
            obj.Replaying = 2==obj.Tracker.DataSource;
        end
        function delete(obj), mgldestroygraphic(obj.GraphicID); end

        function set.Screen(obj,val)
            if 1~=val && 2~=val, error('The Screen property must be 1 (subject screen) or 2 (control screen).'); end
            mgldestroygraphic(obj.GraphicID); obj.GraphicID = []; %#ok<MCSUP>
            obj.Screen = val;
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            if obj.Replaying, return, end
            if max(obj.Position)<=1
                rect = mglgetscreeninfo(obj.Screen,'Rect');
                sz = rect(3:4) - rect(1:2);
                obj.ScrPos = obj.Position.*sz([1 2 1 2]);
            else
                obj.ScrPos = obj.Position;
            end
            if isempty(obj.GraphicID), obj.GraphicID = mgladdbitmap([0 0],obj.Screen+2); end
            mglsetproperty(obj.GraphicID,'active',true,'origin',obj.ScrPos(1:2) + obj.ScrPos(3:4)/2);
        end
        function fini(obj,~)
            mglactivategraphic(obj.GraphicID,false);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            if obj.Replaying, return, end
            if 0~=mod(p.scene_frame(),obj.UpdateInterval), return, end
            if isempty(obj.Tracker.DAQ.Webcam{obj.CamNumber}), return, end

            bitmap = getsample(obj.Tracker.DAQ.Webcam{obj.CamNumber});
            if isempty(bitmap.Frame), return, end

            scale = [obj.ScrPos(3)/bitmap.Size(1) obj.ScrPos(4)/bitmap.Size(2)];
            mglsetproperty(obj.GraphicID,'bitmap',decodeframe(bitmap),'scale',scale);
        end
    end
end
