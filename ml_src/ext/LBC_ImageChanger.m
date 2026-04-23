classdef LBC_ImageChanger < mladapter
    properties
        ImageList
    end
    properties (SetAccess = protected)
        ElapsedFrame
%         CurrentImageName
    end
    properties (Access = protected)
        StartFrame
        ImageID
        ImageSchedule
        CurrentImageNum
        PrevImageNum
    end
    
    methods
        function obj = LBC_ImageChanger(varargin)
            obj@mladapter(varargin{:});
        end
        function delete(obj), destroy_graphic(obj); end

        function init(obj,p)
            init@mladapter(obj,p);
            create_graphic(obj);
            obj.ImageSchedule = ceil(cumsum([obj.ImageList{:,3}]) / obj.Tracker.Screen.FrameLength);
            obj.ElapsedFrame = 0;
            obj.CurrentImageNum = 0;
            obj.PrevImageNum = 0;
            obj.StartFrame = [];
        end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);
            if obj.Adapter.Success
                if isempty(obj.StartFrame), obj.StartFrame = p.scene_frame(); end
                obj.ElapsedFrame = p.scene_frame() - obj.StartFrame;
                if 0 < obj.ElapsedFrame, obj.CurrentImageNum = find(obj.ElapsedFrame<=obj.ImageSchedule,1); end
            end
            obj.Success = isempty(obj.CurrentImageNum);
            continue_ = ~obj.Success;
        end
        function draw(obj,p)
            draw@mladapter(obj,p);
            if isempty(obj.CurrentImageNum)  % This means that we presented all the images, so turn them off.
                deactivate_all(obj);
            elseif obj.PrevImageNum ~= obj.CurrentImageNum
                if 0<obj.PrevImageNum, mglactivategraphic(obj.ImageID{obj.PrevImageNum},false); end
                obj.PrevImageNum = obj.CurrentImageNum;
                
                selected_id = obj.ImageID{obj.CurrentImageNum};
                if ~isempty(selected_id)
                    selected_pos = obj.ImageList{obj.CurrentImageNum,2};
                    if 1<numel(selected_id) && 1==size(selected_pos,1), selected_pos = repmat(selected_pos,numel(selected_id),1); end
                    mglactivategraphic(selected_id,true);
                    mglsetorigin(selected_id,obj.Tracker.CalFun.deg2pix(selected_pos));
                end
                selected_marker = obj.ImageList{obj.CurrentImageNum,4};
                p.eventmarker(selected_marker);
%                 switch class(obj.ImageList{obj.CurrentImageNum,1})
%                     case 'double'
%                         imglist = obj.ImageList{obj.CurrentImageNum,1};
%                         switch length(imglist)
%                             case 0, obj.CurrentImageName = '';
%                             case 1, obj.CurrentImageName = sprintf('Image %d',imglist);
%                             case 2, obj.CurrentImageName = ['Image ' sprintf('%d, ',imglist(1:end-1)) sprintf('%d',imglist(end))];
%                         end
%                     case 'char'
%                         obj.CurrentImageName = obj.ImageList{obj.CurrentImageNum,1};
%                     case 'cell'
%                         obj.CurrentImageName = sprintf('%s ',obj.ImageList{obj.CurrentImageNum,1}{:});
%                 end
            end
        end
    end
    
    methods (Access = protected)
        function create_graphic(obj)
            destroy_graphic(obj);
            nrow = size(obj.ImageList,1);
            obj.ImageID = cell(nrow,1);
            for m=1:nrow
                if isempty(obj.ImageList{m,1}), continue, end
                switch class(obj.ImageList{m,1})
                    case 'double'
                        obj.ImageID{m} = obj.ImageList{m,1};
                    case 'char'
                        [~,~,e] = fileparts(obj.ImageList{m,1});
                        switch lower(e)
                            case {'.avi','.mpg','.mpeg'}, obj.ImageID{m} = mgladdmovie(obj.ImageList{m,1});
                            otherwise, obj.ImageID{m} = mgladdbitmap(mglimread(obj.ImageList{m,1}));
                        end
                    case 'cell'
                        nimage = numel(obj.ImageList{m,1});
                        obj.ImageID{m} = NaN(1,nimage);
                        for n=1:nimage
                            [~,~,e] = fileparts(obj.ImageList{m,1}{n});
                            switch lower(e)
                                case {'.avi','.mpg','.mpeg'}, obj.ImageID{m} = mgladdmovie(obj.ImageList{m,1}{n});
                                otherwise, obj.ImageID{m}(n) = mgladdbitmap(mglimread(obj.ImageList{m,1}{n}));
                            end
                        end
                end
            end
            deactivate_all(obj);
        end
        function destroy_graphic(obj)
            if isempty(obj.ImageID), return, end
            for m=1:size(obj.ImageList,1)
                switch class(obj.ImageList{m,1})
                    case {'char','cell'}, mgldestroygraphic(obj.ImageID{m});
                end
            end
            obj.ImageID = [];
        end
        function deactivate_all(obj)
            for m=1:size(obj.ImageList,1), mglactivategraphic(obj.ImageID{m},false); end
        end
    end
end
