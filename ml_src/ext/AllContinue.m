classdef AllContinue < mlaggregator
    methods
        function obj = AllContinue(varargin)
            obj@mlaggregator(varargin{:});
        end
        
        function continue_ = analyze(obj,p)
            obj.Success = true;
            for m=1:length(obj.Adapter)
                obj.Success = obj.Success & obj.Adapter{m}.analyze(p);
            end
            continue_ = obj.Success;
        end
    end
end
