classdef AnyContinue < mlaggregator
    methods
        function obj = AnyContinue(varargin)
            obj@mlaggregator(varargin{:});
        end
        
        function continue_ = analyze(obj,p)
            obj.Success = false;
            for m=1:length(obj.Adapter)
                obj.Success = obj.Success | obj.Adapter{m}.analyze(p);
            end
            continue_ = obj.Success;
        end
    end
end
