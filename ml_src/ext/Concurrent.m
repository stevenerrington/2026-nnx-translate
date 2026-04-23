classdef Concurrent < mlaggregator
    methods
        function obj = Concurrent(varargin)
            obj@mlaggregator(varargin{:});
        end
        
        function continue_ = analyze(obj,p)
            continue_ = obj.Adapter{1}.analyze(p);
            obj.Success = obj.Adapter{1}.Success;
            for m=2:length(obj.Adapter), obj.Adapter{m}.analyze(p); end
        end
    end
end
