classdef TwoCorners < mladapter
    properties
        Size = 150
    end
    properties (Access = protected)
        Corners
    end
    
    methods
        function obj = TwoCorners(varargin)
            obj@mladapter(varargin{:});
            
            sz = obj.Tracker.Screen.SubjectScreenFullSize;
            obj.Corners = [0 0 obj.Size obj.Size;
                sz(1)-obj.Size 0 sz(1) obj.Size;
                0 sz(2)-obj.Size obj.Size sz(2);
                sz-obj.Size sz];
        end
        
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            
            data = reshape(obj.Tracker.XYData(end,:),2,[])';
            if isempty(data), return, end
            
            ncorner = size(obj.Corners,1);
            touched = false(1,ncorner);
            for m=1:ncorner
                touched(m) = any(obj.Corners(m,1)<data(:,1) & data(:,1)<obj.Corners(m,3) ...
                    & obj.Corners(m,2)<data(:,2) & data(:,2)<obj.Corners(m,4));
            end
            
            obj.Success = 1<sum(touched);
            continue_ = ~obj.Success;
        end
    end
end
