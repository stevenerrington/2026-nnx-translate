classdef PropertyMonitor < mladapter
    properties
        Dashboard = 1
        Color = [1 1 1]
        ChildProperty = 'Success'
        Format = '';
        UpdateInterval = 30          % update intervals in frames
    end
    
    methods
        function obj = PropertyMonitor(varargin)
            obj@mladapter(varargin{:});
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            if 0~=mod(p.scene_frame(),obj.UpdateInterval) || 2==obj.Tracker.DataSource, return, end

            str = '';
            if iscell(obj.Format)
                str = sprintf(obj.Format{1},eval(obj.Format{2}));
            else
                val = obj.Adapter.(obj.ChildProperty);
                if isempty(obj.Format)
                    switch class(val)
                        case 'char', str = [' ' val];
                        case 'logical'
                            if isscalar(val)
                                if val, str = ' true'; else, str = ' false'; end
                            else
                                str = sprintf(' %d',val);
                            end
                        case 'cell'
                            for m=1:length(val)
                                if 1<m, str = [str ',']; end %#ok<*AGROW>
                                switch class(val{m})
                                    case 'char', str = [str ' ' val{m}];
                                    otherwise, str = [str sprintf(' %d',val)];
                                end
                            end
                        otherwise, str = sprintf(' %d',val);
                    end
                    str =  [obj.ChildProperty ':' str];
                else
                    str = sprintf(obj.Format,val);
                end
            end
            p.dashboard(obj.Dashboard,str,obj.Color);
        end
    end
end
