classdef FrameMarker < mladapter
    properties
        FrameEvent
    end
    properties (Access = protected)
        Frame
        Event
    end
    
    methods
        function obj = FrameMarker(varargin)
            obj@mladapter(varargin{:});
        end
        
        function set.FrameEvent(obj,val)
            if 2~=size(val,2)
                error('FrameEvent should be an n-by-2 cell or matrix ([frameNum event])!!!');
            end
            obj.FrameEvent = val;
            if iscell(val)
                obj.Frame = cell2mat(val(:,1)); %#ok<*MCSUP>
                obj.Event = val(:,2);
            else
                obj.Frame = val(:,1);
                obj.Event = num2cell(val(:,2));
            end
        end
        
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);
            obj.Success = obj.Adapter.Success;
            row = find(obj.Frame==p.scene_frame()+1,1);
            if ~isempty(row), p.eventmarker(obj.Event{row}); end
        end
    end
end
