classdef OnOffGraphic < mlaggregator
    properties
        OnGraphic
        OffGraphic
        ChildProperty = 'Success'
    end
    properties (Hidden)
        OnAdapter
        OffAdapter
    end
    properties (Access = protected)
        State
        OnGraphicID
        OffGraphicID
    end
    
    methods
        function obj = OnOffGraphic(varargin)
            obj@mlaggregator(varargin{:});
        end
        function val = fieldnames(obj), val = [fieldnames@mlaggregator(obj); 'OnAdapter'; 'OffAdapter']; end

        function set.OnGraphic(obj,val)
            if isobject(val)
                if isempty(obj.OnAdapter), obj.OnAdapter = length(obj.Adapter) + 1; end %#ok<*MCSUP>
                obj.Adapter{obj.OnAdapter} = val;
                obj.OnGraphic = 1:length(val.GraphicID);
            else
                obj.OnGraphic = val;
            end
        end
        function setOnGraphic(obj,val,idx)
            obj.OnGraphic = val;
            if isobject(val) && exist('idx','var'), obj.OnGraphic = idx; end
        end
        function set.OffGraphic(obj,val)
            if isobject(val)
                if isempty(obj.OffAdapter), obj.OffAdapter = length(obj.Adapter) + 1; end
                obj.Adapter{obj.OffAdapter} = val;
                obj.OffGraphic = 1:length(val.GraphicID);
            else
                obj.OffGraphic = val;
            end
        end
        function setOffGraphic(obj,val,idx)
            obj.OffGraphic = val;
            if isobject(val) && exist('idx','var'), obj.OffGraphic = idx; end
        end
        
        function init(obj,p)
            obj.Adapter{1}.init(p);
            obj.State = NaN;  % To update the graphics in the first frame
            if isempty(obj.OnGraphic)
                obj.OnGraphicID = [];
            else
                if isempty(obj.OnAdapter)
                    obj.OnGraphicID = obj.Tracker.TaskObject.ID(obj.OnGraphic);
                else
                    obj.OnGraphicID = obj.Adapter{obj.OnAdapter}.GraphicID(obj.OnGraphic);
                end
            end
            if isempty(obj.OffGraphic)
                obj.OffGraphicID = [];
            else
                if isempty(obj.OffAdapter)
                    obj.OffGraphicID = obj.Tracker.TaskObject.ID(obj.OffGraphic);
                else
                    obj.OffGraphicID = obj.Adapter{obj.OffAdapter}.GraphicID(obj.OffGraphic);
                end
            end
        end
        function fini(obj,p)
            obj.Adapter{1}.fini(p);
            mglactivategraphic(obj.OnGraphicID,false);
            mglactivategraphic(obj.OffGraphicID,false);
        end
        function continue_ = analyze(obj,p)
            continue_ = obj.Adapter{1}.analyze(p);
            obj.Success = obj.Adapter{1}.Success;
            
            if obj.State~=obj.Adapter{1}.(obj.ChildProperty)
                obj.State = obj.Adapter{1}.(obj.ChildProperty);
                if obj.State
                    mglactivategraphic(obj.OnGraphicID,true);
                    mglactivategraphic(obj.OffGraphicID,false);
                else
                    mglactivategraphic(obj.OnGraphicID,false);
                    mglactivategraphic(obj.OffGraphicID,true);
                end
            end
        end
        function draw(obj,p), obj.Adapter{1}.draw(p); end
    end
end
