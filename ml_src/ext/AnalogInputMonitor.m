classdef AnalogInputMonitor < mladapter
    properties
        Channel = 1                 % General #
        Position = [580 20 200 50]  % [left top width height]
        YLim = [-10 10]             % [ymin ymax]
        Title = ''
        Color = [1 1 0]
        UpdateInterval = 1          % update intervals in frames
    end
    properties (SetAccess = protected)
        GraphicID
    end
    properties (Access = protected)
        AIDev
        AIChan
        Replaying
        ScrPos
        PrevFrame
    end
    properties (Hidden)
        Modulus
    end

    methods
        function obj = AnalogInputMonitor(varargin)
            obj@mladapter(varargin{:});
            obj.Replaying = 2==obj.Tracker.DataSource;
        end
        function delete(obj), mgldestroygraphic(obj.GraphicID); end
        function val = importnames(obj), val = [fieldnames(obj); 'Modulus']; end

        function set.Channel(obj,val)
            obj.AIDev = []; %#ok<*MCSUP>
            if ~isnumeric(val)
                switch val(1)
                    case 'g', signal_type = 'general';
                    case 'h', signal_type = 'highfrequency';
                    otherwise, signal_type = 'voice';
                end
                [obj.AIDev,obj.AIChan] = obj.Tracker.DAQ.get_device(signal_type);
                if isempty(obj.AIDev), error('''%s'' does not exist!',val); end

                n = str2double(regexp(val,'\d+','match'));
                if ~isempty(n)
                    if iscell(obj.AIDev), obj.AIDev = obj.AIDev{n}; end
                    obj.AIChan = obj.AIChan(n);
                end
                if 0==obj.AIChan, error('''%s'' does not exist!',val); end
            end
            obj.Channel = val;
        end
        function set.Modulus(obj,val), obj.UpdateInterval = val; end
        function val = get.Modulus(obj), val = obj.UpdateInterval; end

        function init(obj,p)
            init@mladapter(obj,p);
            if obj.Replaying, return, end

            if max(obj.Position)<=1
                rect = mglgetscreeninfo(2,'Rect');
                sz = rect(3:4) - rect(1:2);
                obj.ScrPos = obj.Position.*sz([1 2 1 2]);
            else
                obj.ScrPos = obj.Position;
            end
            if isempty(obj.GraphicID)
                obj.GraphicID(1) = mgladdbox(obj.Color/2,obj.ScrPos(3:4),12);
                obj.GraphicID(2) = mgladdtext(sprintf('%g',obj.YLim(2)),12);
                obj.GraphicID(3) = mgladdtext(sprintf('%g',obj.YLim(1)),12);
                obj.GraphicID(4) = mgladdtext(obj.Title,12);
                obj.GraphicID(5) = mgladdline(obj.Color,ceil(obj.ScrPos(3)),1,12);
                obj.GraphicID(6) = mgladdline(obj.Color/2,ceil(obj.ScrPos(3)),1,12);
            end
            mglsetorigin(obj.GraphicID(1),obj.ScrPos(1:2) + obj.ScrPos(3:4)/2);
            mglsetproperty(obj.GraphicID(2),'color',obj.Color,'right','middle','origin',obj.ScrPos(1:2)+[-5 0]);
            mglsetproperty(obj.GraphicID(3),'color',obj.Color,'right','middle','origin',obj.ScrPos(1:2)+[-5 obj.ScrPos(4)]);
            mglsetproperty(obj.GraphicID(4),'color',obj.Color,'center','bottom','origin',obj.ScrPos(1:2)+[obj.ScrPos(3)/2 -3]);
            obj.PrevFrame = NaN;
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
        end
        function draw(obj,p)
            draw@mladapter(obj,p);
            if obj.Replaying, return, end

            CurrentFrame = p.scene_frame();
            if obj.PrevFrame==CurrentFrame, return, else, obj.PrevFrame = CurrentFrame; end  % draw only once in one frame
            if 0~=mod(CurrentFrame,obj.UpdateInterval), return, end

            if isnumeric(obj.Channel)
                data = obj.Tracker.DAQ.General{obj.Channel};
            else
                data = getsample(obj.AIDev);
                if ~isempty(obj.AIChan), data = data(obj.AIChan); end
            end
            if isempty(data), return, end
            d = data(end,:);

            x = mglgetproperty(obj.GraphicID(5),'size');
            if obj.ScrPos(3) <= x+1, mglsetproperty(obj.GraphicID(5:6),'clear'); x=0; end

            y = (obj.YLim(2)-max(obj.YLim(1),min(obj.YLim(2),d(1)))) * obj.ScrPos(4) / (obj.YLim(2)-obj.YLim(1));
            mglsetproperty(obj.GraphicID(5),'addpoint',obj.ScrPos(1:2) + [x y]);
            if 1<length(d)
                y = (obj.YLim(2)-max(obj.YLim(1),min(obj.YLim(2),d(2)))) * obj.ScrPos(4) / (obj.YLim(2)-obj.YLim(1));
                mglsetproperty(obj.GraphicID(6),'addpoint',obj.ScrPos(1:2) + [x y]);
            end
        end
    end
end
