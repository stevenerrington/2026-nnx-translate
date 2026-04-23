classdef TrueAdapter < mladapter
    methods
        function obj = TrueAdapter(varargin)
            obj@mladapter(varargin{:});
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = true;
        end
    end
end
