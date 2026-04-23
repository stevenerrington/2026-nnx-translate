classdef OnOffMarker < mladapter
    properties
        OnMarker
        OffMarker
        ChildProperty = 'Success'
    end
    properties (SetAccess = protected)
        State
    end
    
    methods
        function obj = OnOffMarker(varargin)
            obj@mladapter(varargin{:});
        end
        function init(obj,p)
            init@mladapter(obj,p);
            obj.State = obj.Adapter.(obj.ChildProperty);
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            
            if obj.State~=obj.Adapter.(obj.ChildProperty)
                obj.State = obj.Adapter.(obj.ChildProperty);
                if obj.State
                    if ~isempty(obj.OnMarker), p.DAQ.eventmarker(obj.OnMarker); end
                else
                    if ~isempty(obj.OffMarker), p.DAQ.eventmarker(obj.OffMarker); end
                end
            end
        end
    end
end
