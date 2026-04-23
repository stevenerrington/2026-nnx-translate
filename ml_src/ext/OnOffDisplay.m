classdef OnOffDisplay < mladapter
    properties
        Dashboard = 1
        OnMessage = []
        OffMessage = []
        OnColor = [1 1 1]
        OffColor = [1 1 1]
        ChildProperty = 'Success'
    end
    properties (SetAccess = protected)
        State
    end
    
    methods
        function obj = OnOffDisplay(varargin)
            obj@mladapter(varargin{:});
        end
        function init(obj,p)
            init@mladapter(obj,p);
            obj.State = NaN;  % To update the Dashboard in the first frame
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            if obj.State~=obj.Adapter.(obj.ChildProperty)
                obj.State = obj.Adapter.(obj.ChildProperty);
                if obj.State
                    p.dashboard(obj.Dashboard,obj.OnMessage,obj.OnColor);
                else
                    p.dashboard(obj.Dashboard,obj.OffMessage,obj.OffColor);
                end
            end
        end
    end
end
