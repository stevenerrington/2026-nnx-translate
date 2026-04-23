classdef OrAdapter < mlaggregator
    methods
        function obj = OrAdapter(varargin)
            obj@mlaggregator(varargin{:});
        end
        
        function continue_ = analyze(obj,p)
            obj.Success = false;
            for m=1:length(obj.Adapter)
                obj.Adapter{m}.analyze(p);
                obj.Success = obj.Success | obj.Adapter{m}.Success;
            end
            continue_ = ~obj.Success;
        end
    end
end
