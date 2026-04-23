classdef FixTimeAnalyzer < mladapter
    properties (SetAccess = protected)
        FixTime
    end
    properties (Access = protected)
        ST
    end
    
    methods
        function obj = FixTimeAnalyzer(varargin)
            obj@mladapter(varargin{:});
            obj.ST = get_adapter(obj,'SingleTarget');
            if isempty(obj.ST)
                obj.ST = get_adapter(obj,'SingleButton');
                if isempty(obj.ST)
                    error('SingleTarget or SingleButton is not found in the chain!!!');
                end
            end
        end
        
        function init(obj,p)
            init@mladapter(obj,p);
            obj.FixTime = 0;
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            obj.FixTime = obj.FixTime + sum(obj.ST.In);
        end
    end
end
