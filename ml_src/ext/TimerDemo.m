classdef TimerDemo < mladapter
    properties (SetAccess = protected)
        ElapsedFrame
        EndFrame
    end
    properties (Access = protected)
        PieID
        RefreshRate
    end
    
    methods
        function obj = TimerDemo(varargin)
            obj@mladapter(varargin{:});
            Screen = obj.Tracker.Screen;
            x0 = Screen.Xsize / 2 + 300;
            y0 = Screen.Ysize / 3;
            color = [163 73 164; 63 72 204; 0 162 232; 34 177 76; 255 242 0; 255 127 39; 237 28 36];
            bgcolor = Screen.BackgroundColor;
            for m=1:7
                x = x0 - (m-1)*100;
                obj.PieID(2,m) = mgladdcircle([bgcolor; bgcolor],50);
                obj.PieID(1,m) = mgladdpie([color(m,:); color(m,:)],100,90,0);
                mglsetorigin(obj.PieID(:,m),[x y0; x y0]);
            end
            mglactivategraphic(obj.PieID,false);
            
            obj.RefreshRate = round(Screen.RefreshRate);
        end
        function delete(obj), mgldestroygraphic(obj.PieID); end

        function init(obj,p)
            init@mladapter(obj,p);
            obj.ElapsedFrame = 0;
            obj.EndFrame = obj.RefreshRate * 4;
        end
        function fini(obj,p)
            fini@mladapter(obj,p);
            mglactivategraphic(obj.PieID,false);
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            
            if obj.Adapter.Success
                obj.ElapsedFrame = obj.ElapsedFrame + 1;
                obj.EndFrame = p.scene_frame() + obj.RefreshRate * 4;
            end
            obj.Success = obj.RefreshRate * 7 <= obj.ElapsedFrame;
            continue_ = ~obj.Success && p.scene_frame() < obj.EndFrame;
        end
        function draw(obj,p)
            draw@mladapter(obj,p);
            
            if 0 < obj.ElapsedFrame
                annulus = mod(floor((obj.ElapsedFrame-1) / obj.RefreshRate),7) + 1;
                angle = -rem(obj.ElapsedFrame,obj.RefreshRate) / obj.RefreshRate * 360;
                if 0==angle, angle = -360; end
                mglactivategraphic(obj.PieID(:,annulus),true);
                mglsetproperty(obj.PieID(1,annulus),'centerangle',angle);
            end
        end
    end
end
