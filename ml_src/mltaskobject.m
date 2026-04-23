classdef mltaskobject < matlab.mixin.Copyable
    properties (SetAccess = protected)
        ID
        Modality
    end
    properties
        Status
        Position
        Scale
        Angle
        Zorder
    end
    properties (SetAccess = protected)
        Info
        MoreInfo
        Size
    end
    properties (SetAccess = protected, Hidden)
        PixelsPerDegree
        SubjectScreenHalfSize
        DestroyObject = false
    end
    
    methods
        function obj = mltaskobject(taskobj,MLConfig,TrialRecord)
            if ~exist('taskobj','var'), return; end
            if isa(taskobj,'mltaskobject')
                obj = copy(taskobj);
            else
                obj.PixelsPerDegree = MLConfig.PixelsPerDegree;
                obj.SubjectScreenHalfSize = MLConfig.Screen.SubjectScreenHalfSize;
                obj.DestroyObject = true;
                if isempty(obj.SubjectScreenHalfSize), obj.SubjectScreenHalfSize = NaN(1,2); end
                if ~exist('TrialRecord','var') || ~isa(TrialRecord,'mltrialrecord'), TrialRecord = mltrialrecord(MLConfig).new_trial(MLConfig,true); end
                if ischar(taskobj), taskobj = {taskobj}; end
                if iscell(taskobj), taskobj = MLConfig.MLConditions.parse_object(taskobj); end
                
                nobj = length(taskobj);
                obj.ID = NaN(1,nobj);
                obj.Modality = zeros(1,nobj);
                obj.Status = false(1,nobj);
                obj.Position = NaN(nobj,2);
                obj.Scale = ones(nobj,2);
                obj.Angle = zeros(1,nobj);
                obj.Zorder = zeros(1,nobj);
                obj.Info = taskobj;
                obj.MoreInfo = cell(1,nobj);
                obj.Size = zeros(nobj,2);
                
                if isfield(taskobj,'Attribute'), createobj(obj,taskobj,MLConfig,TrialRecord); else, createobj_from_struct(obj,taskobj,MLConfig,TrialRecord); end
                idx = obj.Modality < 4;  % including sounds
                mglsetproperty(obj.ID(idx),'active',obj.Status(idx),'origin',getScreenPosition(obj,obj.Position(idx,:)),'scale',obj.Scale(idx,:),'angle',obj.Angle(idx),'zorder',obj.Zorder(idx));
            end
            TrialRecord.setCurrentConditionStimulusInfo(obj);
        end
        function delete(obj)
            try
                movie = 2==obj.Modality; visual = 1==obj.Modality | movie; sound = 3==obj.Modality;
                if obj.DestroyObject
                    mgldestroygraphic(obj.ID(visual)); mgldestroysound(obj.ID(sound));
                else
                    mglactivategraphic(obj.ID(visual),false); mglsetproperty(obj.ID(movie),'seek',0); mglsetproperty(obj.ID(sound),'active',false,'seek',0);
                end
            catch
                % for suppressing unnecessary error messages
            end
        end
        function val = end(obj,~,~), val = numel(obj.ID); end
        function val = length(obj), val = length(obj.ID); end
%         function val = numel(~), val = 1; end  % return 1 or do not define numel; otherwise, subsasgn will fail
        function val = size(obj), val = size(obj.ID); end
        function val = horzcat(obj,varargin)
            val = copy(obj);
            for m=1:length(varargin)
                val.ID = [val.ID varargin{m}.ID];
                val.Modality = [val.Modality varargin{m}.Modality];
                val.Status = [val.Status varargin{m}.Status];
                val.Position = [val.Position; varargin{m}.Position];
                val.Scale = [val.Scale; varargin{m}.Scale];
                val.Angle = [val.Angle varargin{m}.Angle];
                val.Zorder = [val.Zorder varargin{m}.Zorder];
                val.Info = [val.Info varargin{m}.Info];
                val.MoreInfo = [val.MoreInfo varargin{m}.MoreInfo];
                val.Size = [val.Size; varargin{m}.Size];
            end
        end
        function val = vertcat(obj,varargin), val = horzcat(obj,varargin{:}); end
        
        function obj = subsasgn(obj,s,b)
            if isempty(b), error('Cannot assign an empty matrix'); end
            l = length(s);
            switch s(1).type
                case {'()','{}'}
                    if 1==l
                        error('Not a valid indexing expression');
                    elseif 1<l
                        a = s(2); s(2) = s(1); s(1) = a;
                    end
            end
            switch s(1).subs
                case {'ID','Modality'}, error('Attempt to modify read-only property: ''%s''.',s(1).subs);
                case {'Position','Scale','Size'}
                    if 2<l, s(2).subs{2} = s(3).subs{end}; s(3) = []; end
                    if 1<l && 1==length(s(2).subs), s(2).subs{2} = ':'; end
            end
            obj = builtin('subsasgn',obj,s,b);
            
            if l==1, idx = ':'; else, idx = s(2).subs{1}; end
            switch s(1).subs
                case 'Position', mglsetorigin(obj.ID(idx),getScreenPosition(obj,obj.Position(idx,:)));
                case 'Scale', mglsetproperty(obj.ID(idx),'scale',obj.Scale(idx,:));
                case 'Angle', mglsetproperty(obj.ID(idx),'angle',b);
                case 'Zorder', mglsetproperty(obj.ID(idx),'zorder',b);
            end
        end
        function varargout = subsref(obj,s)
            l = length(s);
            switch s(1).type
                case {'()','{}'}
                    if 1~=length(s(1).subs), error('Not a valid indexing expression'); end  % TaskObject is 1-D
                    if 1==l
                        idx = s(1).subs{1};
                        b = mltaskobject;
                        b.ID = obj.ID(idx);
                        b.Modality = obj.Modality(idx);
                        b.Status = obj.Status(idx);
                        b.Position = obj.Position(idx,:);
                        b.Scale = obj.Scale(idx,:);
                        b.Angle = obj.Angle(idx);
                        b.Zorder = obj.Zorder(idx);
                        b.Info = obj.Info(idx);
                        b.MoreInfo = obj.MoreInfo(idx);
                        b.Size = obj.Size(idx,:);
                        b.PixelsPerDegree = obj.PixelsPerDegree;
                        b.SubjectScreenHalfSize = obj.SubjectScreenHalfSize;
                        varargout{1} = b;
                        return  % early exit
                    elseif 1<l
                        if isempty(s(1).subs{1}), return, end
                        varargout = repmat({[]},1,nargout);
                        a = s(2); s(2) = s(1); s(1) = a;
                    end
            end
            switch s(1).subs
                case {'Position','Scale','Size'}
                    if 3==l, s(2).subs{2} = s(3).subs{end}; s(3) = []; end
                    if 2==l && 1==length(s(2).subs), s(2).subs{2} = ':'; end
                case {'Info','MoreInfo'}
                    idx = NaN;
                    if 3==l
                        if '.'==s(2).type, idx = s(3).subs{1}; s(3) = []; else, idx = s(2).subs{1}; s(2) = []; end
                        l = length(s);
                    end
                    if 2==l 
                        if strcmp(s(2).type,'.')
                            if isnan(idx), idx = 1:numel(obj.(s(1).subs)); end
                            if islogical(idx), idx = find(idx); end
                            if isempty(idx), varargout{1} = []; return, end

                            nid = length(idx); out = cell(1,nid);
                            if iscell(obj.(s(1).subs))
                                for m=1:nid, out{m} = obj.(s(1).subs){idx(m)}.(s(2).subs); end  % MoreInfo
                            else
                                for m=1:nid, out{m} = obj.(s(1).subs)(idx(m)).(s(2).subs); end  % Info
                            end
                            if isnumeric(out{1}) || islogical(out{1})
                                if 1<size(out{1},2), varargout{1} = cell2mat(out'); else, varargout{1} = cell2mat(out); end
                            else
                                varargout{1} = out;
                            end
                            return  % early exit
                        elseif isscalar(s(2).subs{1}) && iscell(obj.(s(1).subs))  % show contents for scalar index
                            s(2).type = '{}';
                        end
                    end
            end
            varargout{1} = builtin('subsref',obj,s);
        end
    end
    
    methods (Access = protected)
        function cp = copyElement(obj)
            cp = copyElement@matlab.mixin.Copyable(obj);
            cp.DestroyObject = false;
        end
        function dest = copyfield(~,dest,src,field)
            if isempty(src), src = struct; end
            if isempty(dest), dest = struct; end
            if ~exist('field','var'), field = fieldnames(src); end
            for m=1:length(field), dest.(field{m}) = src.(field{m}); end
        end
        function val = getScreenPosition(obj,Position)
            n = size(Position,1);
            val = round(Position .* repmat(obj.PixelsPerDegree,n,1)) + repmat(obj.SubjectScreenHalfSize,n,1);
        end
        function createobj_from_struct(obj,taskobj,MLConfig,TrialRecord)
            for m=1:length(taskobj)
                o = taskobj(m);
                switch lower(o.Type)
                    case 'gen'
                        o.Name = MLConfig.MLPath.validate_path(o.Name);
                        func = get_function_handle(o.Name);
                        if isfield(o,'Xpos'), x = o.Xpos; else, x = 0; end
                        if isfield(o,'Ypos'), y = o.Ypos; else, y = 0; end
                        info = [];
                        if 1==nargin(func)
                            switch nargout(func)
                                case 2, [imdata,info] = func(TrialRecord);
                                case 3, [imdata,x,y] = func(TrialRecord);
                                case 4, [imdata,x,y,info] = func(TrialRecord);
                                otherwise, imdata = func(TrialRecord);
                            end
                        else
                            switch nargout(func)
                                case 2, [imdata,info] = func(TrialRecord,MLConfig);
                                case 3, [imdata,x,y] = func(TrialRecord,MLConfig);
                                case 4, [imdata,x,y,info] = func(TrialRecord,MLConfig);
                                otherwise, imdata = func(TrialRecord,MLConfig);
                            end
                        end
                        if ischar(imdata)
                            impath = MLConfig.MLPath.validate_path(imdata); if isempty(impath), error('File from Gen (%s) doesn''t exist',imdata); end, imdata = impath;
                            [~,~,e] = fileparts(imdata);
                            if strcmpi(e,'.gif'), if 1==length(imfinfo(imdata)), e = 'static_gif'; else, e = 'animated_gif'; end, end
                            switch lower(e)
                                case {'.png','.jpg','.jpeg','.bmp','.tif','.tiff','static_gif'}
                                    bits = mglimread(imdata);
                                    if 3==size(bits,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(bits,info.Colorkey); else, obj.ID(m) = mgladdbitmap(bits); end
                                    obj.Modality(m) = 1;
                                    info = copyfield(obj,info,imfinfo(imdata));
                                    info.Size = mglgetproperty(obj.ID(m),'size');
                                case {'.3g2','.3gp','.3gp2','.3gpp','.asf','.wmv','.m4a','.m4v','.mov','.mp4','.avi','.mpg','.mpeg','animated_gif'}
                                    obj.ID(m) = mgladdmovie(imdata);
                                    if isfield(info,'FrameByFrame') && info.FrameByFrame, mglsetproperty(obj.ID(m),'framebyframe'); end
                                    if isfield(info,'Looping'), mglsetproperty(obj.ID(m),'looping',info.Looping); end
                                    obj.Modality(m) = 2;
                                    info.Filename = imdata;
                                    info = copyfield(obj,info,mglgetproperty(obj.ID(m),'info'));
                                case {'.m',''}
                                    try
                                        func = get_function_handle(imdata);
                                        if isfield(info,'Arg'), obj.ID(m) = func(info.Arg); else, obj.ID(m) = func(); end
                                    catch err
                                        if ~TrialRecord.SimulationMode, rethrow(err); else, obj.ID(m) = NaN; end
                                    end
                                    obj.Modality(m) = 3;  % BlackrockLED_taskobj
                                    info.Filename = imdata;
                                    info.Size = [0 0];
                                otherwise
                                    error('Unknown file type from Gen');
                            end
                        else
                            info.Filename = o.Name;
                            if isfield(info,'DoNotPermute')
                                if isfield(info,'TimePerFrame'), TimePerFrame = info.TimePerFrame; else, TimePerFrame = MLConfig.Screen.FrameLength; end
                                obj.ID(m) = mgladdmovie(info.DoNotPermute,TimePerFrame); mdqmex(6,obj.ID(m),'addframe',imdata);
                                if isfield(info,'Looping'), mglsetproperty(obj.ID(m),'looping',info.Looping); end
                                obj.Modality(m) = 2;
                                info = copyfield(obj,info,mglgetproperty(obj.ID(m),'info'));
                            else
                                switch ndims(imdata)
                                    case 2
                                        if isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3]),info.Colorkey); else, obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3])); end
                                        obj.Modality(m) = 1;
                                        info.Size = mglgetproperty(obj.ID(m),'size');
                                    case 3
                                        if 3==size(imdata,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(imdata,info.Colorkey); else, obj.ID(m) = mgladdbitmap(imdata); end
                                        obj.Modality(m) = 1;
                                        info.Size = mglgetproperty(obj.ID(m),'size');
                                    case 4
                                        if isfield(info,'TimePerFrame'), TimePerFrame = info.TimePerFrame; else, TimePerFrame = MLConfig.Screen.FrameLength; end
                                        obj.ID(m) = mgladdmovie(imdata,TimePerFrame);
                                        if isfield(info,'Looping'), mglsetproperty(obj.ID(m),'looping',info.Looping); end
                                        obj.Modality(m) = 2;
                                        info = copyfield(obj,info,mglgetproperty(obj.ID(m),'info'));
                                    otherwise, error('Image type from Gen cannot be determined');
                                end
                            end
                        end
                        obj.Position(m,:) = [x y];
                        obj.MoreInfo{m} = info;
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case {'fix','dot'}
                        [obj.ID(m),filename,obj.Modality(m)] = load_cursor(MLConfig.FixationPointImage,MLConfig.FixationPointShape,MLConfig.FixationPointColor,MLConfig.PixelsPerDegree(1)*MLConfig.FixationPointDeg,3);
                        obj.Position(m,:) = [o.Xpos o.Ypos];
                        if isempty(MLConfig.FixationPointImage)
                            obj.MoreInfo{m}.Filename = '';
                        else
                            if 1==obj.Modality(m)
                                obj.MoreInfo{m} = imfinfo(MLConfig.FixationPointImage);
                                obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                            else
                                obj.MoreInfo{m}.Filename = filename;
                                obj.MoreInfo{m} = copyfield(obj,obj.MoreInfo{m},mglgetproperty(obj.ID(m),'info'));
                            end
                            obj.Size(m,:) = obj.MoreInfo{m}.Size;
                        end
                    case 'pic'
                        o.Name = MLConfig.MLPath.validate_path(o.Name);
                        if isfield(o,'Xsize') && isfield(o,'Ysize'), imdata = mglimresize(mglimread(o.Name),[o.Ysize o.Xsize]); else, imdata = mglimread(o.Name); end
                        if 3==size(imdata,3) && isfield(o,'Colorkey'), obj.ID(m) = mgladdbitmap(imdata,o.Colorkey); else, obj.ID(m) = mgladdbitmap(imdata); end
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [o.Xpos o.Ypos];
                        obj.MoreInfo{m} = imfinfo(o.Name);
                        if 1<length(obj.MoreInfo{m}), obj.MoreInfo{m} = obj.MoreInfo{m}(1); end
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'crc'
                        obj.ID(m) = mgladdbitmap(make_circle(MLConfig.PixelsPerDegree(1)*o.Radius,o.Color,o.FillFlag));
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [o.Xpos o.Ypos];
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'sqr'
                        obj.ID(m) = mgladdbitmap(make_rectangle([o.Xsize o.Ysize]*MLConfig.PixelsPerDegree(1),o.Color,o.FillFlag));
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [o.Xpos o.Ypos];
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'mov'
                        o.Name = MLConfig.MLPath.validate_path(o.Name);
                        obj.ID(m) = mgladdmovie(o.Name);
                        if isfield(o,'Looping') && o.Looping, mglsetproperty(obj.ID(m),'looping',true); end
                        obj.Modality(m) = 2;
                        obj.Position(m,:) = [o.Xpos o.Ypos];
                        obj.MoreInfo{m}.Filename = o.Name;
                        obj.MoreInfo{m} = copyfield(obj,obj.MoreInfo{m},mglgetproperty(obj.ID(m),'info'));
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'snd'
                        if isfield(o,'Name') && ~isempty(o.Name)
                            if strcmpi(o.Name,'sin')
                                [y,fs] = load_waveform({'snd',o.Duration,o.Freq});
                                obj.MoreInfo{m}.Filename = '';
                            else
                                [y,fs] = load_waveform({'snd',MLConfig.MLPath.validate_path(o.Name)});
                                obj.MoreInfo{m}.Filename = o.Name;
                            end
                        else
                            y = o.WaveForm;
                            fs = o.Freq;
                            obj.MoreInfo{m}.Filename = '';
                        end
                        if isscalar(y), obj.ID(m) = y; else, obj.ID(m) = mgladdsound(y,fs); end
                        obj.Modality(m) = 3;
                        obj.MoreInfo{m}.Duration = mglgetproperty(obj.ID(m),'duration');
                        obj.MoreInfo{m}.Frequency = fs;
                    case 'stm'
                        obj.ID(m) = o.OutputPort;
                        obj.Modality(m) = 4;
                        if isfield(o,'Name') && ~isempty(o.Name)
                            [y,fs] = load_waveform({'stm',MLConfig.MLPath.validate_path(o.Name)});
                            obj.MoreInfo{m}.Filename = o.Name;
                        else
                            y = o.WaveForm;
                            fs = o.Freq;
                            obj.MoreInfo{m}.Filename = '';
                        end
                        obj.MoreInfo{m}.Channel = o.OutputPort;
                        obj.MoreInfo{m}.Duration = length(y)/fs;
                        obj.MoreInfo{m}.Frequency = fs;
                        ao = MLConfig.DAQ.Stimulation{o.OutputPort};
                        if isempty(ao)
                            if ~TrialRecord.SimulationMode, error('''Stimulation %d'' is not assigned',o.OutputPort); end
                        else
                            stop(ao);
                            actual_rate = setverify(ao,'SampleRate',fs);
                            if actual_rate~=fs, error('output frequency is %g kHz, instead of %g kHz',actual_rate/1000,fs/1000); end
                            ch = strcmp(ao.Channel.ChannelName,sprintf('Stimulation%d',o.OutputPort));
                            data = zeros(length(y),length(ao.Channel));
                            data(:,ch) = y;
                            if isfield(o,'Retriggering'), ao.RegenerationMode = o.Retriggering; else, ao.RegenerationMode = 0; end
                            putdata(ao,data);
                            start(ao);
                        end
                    case 'ttl'
                        obj.ID(m) = o.OutputPort;
                        obj.Modality(m) = 5;
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Channel = o.OutputPort;
                        if isempty(MLConfig.DAQ.TTL{o.OutputPort}) && ~TrialRecord.SimulationMode, error('''TTL %d'' is not assigned',o.OutputPort); end
                end
            end
        end
        function createobj(obj,taskobj,MLConfig,TrialRecord)
            for m=1:length(taskobj)
                a = taskobj(m).Attribute;
                switch lower(a{1})
                    case 'gen'
                        func = get_function_handle(a{2});
                        if 2<length(a), x = a{3}; y = a{4}; else, x = 0; y = 0; end
                        info = [];
                        if 1==nargin(func)
                            switch nargout(func)
                                case 2, [imdata,info] = func(TrialRecord);
                                case 3, [imdata,x,y] = func(TrialRecord);
                                case 4, [imdata,x,y,info] = func(TrialRecord);
                                otherwise, imdata = func(TrialRecord);
                            end
                        else
                            switch nargout(func)
                                case 2, [imdata,info] = func(TrialRecord,MLConfig);
                                case 3, [imdata,x,y] = func(TrialRecord,MLConfig);
                                case 4, [imdata,x,y,info] = func(TrialRecord,MLConfig);
                                otherwise, imdata = func(TrialRecord,MLConfig);
                            end
                        end
                        if ischar(imdata)
                            impath = MLConfig.MLPath.validate_path(imdata); if isempty(impath), error('File from Gen (%s) doesn''t exist',imdata); end, imdata = impath;
                            [~,~,e] = fileparts(imdata);
                            if strcmpi(e,'.gif'), if 1==length(imfinfo(imdata)), e = 'static_gif'; else, e = 'animated_gif'; end, end
                            switch lower(e)
                                case {'.png','.jpg','.jpeg','.bmp','.tif','.tiff','static_gif'}
                                    bits = mglimread(imdata);
                                    if 3==size(bits,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(bits,info.Colorkey); else, obj.ID(m) = mgladdbitmap(bits); end
                                    obj.Modality(m) = 1;
                                    info = copyfield(obj,info,imfinfo(imdata));
                                    info.Size = mglgetproperty(obj.ID(m),'size');
                                case {'.3g2','.3gp','.3gp2','.3gpp','.asf','.wmv','.m4a','.m4v','.mov','.mp4','.avi','.mpg','.mpeg','animated_gif'}
                                    obj.ID(m) = mgladdmovie(imdata);
                                    if isfield(info,'FrameByFrame') && info.FrameByFrame, mglsetproperty(obj.ID(m),'framebyframe'); end
                                    if isfield(info,'Looping'), mglsetproperty(obj.ID(m),'looping',info.Looping); end
                                    obj.Modality(m) = 2;
                                    info.Filename = imdata;
                                    info = copyfield(obj,info,mglgetproperty(obj.ID(m),'info'));
                                case {'.m',''}
                                    try
                                        func = get_function_handle(imdata);
                                        if isfield(info,'Arg'), obj.ID(m) = func(info.Arg); else, obj.ID(m) = func(); end
                                    catch err
                                        if ~TrialRecord.SimulationMode, rethrow(err); else, obj.ID(m) = NaN; end
                                    end
                                    obj.Modality(m) = 3;  % BlackrockLED_taskobj
                                    info.Filename = imdata;
                                    info.Size = [0 0];
                                otherwise
                                    error('Unknown file type from Gen');
                            end
                        else
                            info.Filename = '';
                            if isfield(info,'DoNotPermute')
                                if isfield(info,'TimePerFrame'), TimePerFrame = info.TimePerFrame; else, TimePerFrame = MLConfig.Screen.FrameLength; end
                                obj.ID(m) = mgladdmovie(info.DoNotPermute,TimePerFrame); mdqmex(6,obj.ID(m),'addframe',imdata);
                                if isfield(info,'Looping'), mglsetproperty(obj.ID(m),'looping',info.Looping); end
                                obj.Modality(m) = 2;
                                info = copyfield(obj,info,mglgetproperty(obj.ID(m),'info'));
                            else
                                switch ndims(imdata)
                                    case 2
                                        if isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3]),info.Colorkey); else, obj.ID(m) = mgladdbitmap(repmat(imdata,[1 1 3])); end
                                        obj.Modality(m) = 1;
                                        info.Size = mglgetproperty(obj.ID(m),'size');
                                    case 3
                                        if 3==size(imdata,3) && isfield(info,'Colorkey'), obj.ID(m) = mgladdbitmap(imdata,info.Colorkey); else, obj.ID(m) = mgladdbitmap(imdata); end
                                        obj.Modality(m) = 1;
                                        info.Size = mglgetproperty(obj.ID(m),'size');
                                    case 4
                                        if isfield(info,'TimePerFrame'), TimePerFrame = info.TimePerFrame; else, TimePerFrame = MLConfig.Screen.FrameLength; end
                                        obj.ID(m) = mgladdmovie(imdata,TimePerFrame);
                                        if isfield(info,'Looping'), mglsetproperty(obj.ID(m),'looping',info.Looping); end
                                        obj.Modality(m) = 2;
                                        info = copyfield(obj,info,mglgetproperty(obj.ID(m),'info'));
                                    otherwise, error('Image type from Gen cannot be determined');
                                end
                            end
                        end
                        obj.Position(m,:) = [x y];
                        obj.MoreInfo{m} = info;
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case {'fix','dot'}
                        [obj.ID(m),filename,obj.Modality(m)] = load_cursor(MLConfig.FixationPointImage,MLConfig.FixationPointShape,MLConfig.FixationPointColor,MLConfig.PixelsPerDegree(1)*MLConfig.FixationPointDeg,3);
                        obj.Position(m,:) = [a{2:3}];
                        if isempty(MLConfig.FixationPointImage)
                            obj.MoreInfo{m}.Filename = '';
                        else
                            if 1==obj.Modality(m)
                                obj.MoreInfo{m} = imfinfo(MLConfig.FixationPointImage);
                                obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                            else
                                obj.MoreInfo{m}.Filename = filename;
                                obj.MoreInfo{m} = copyfield(obj,obj.MoreInfo{m},mglgetproperty(obj.ID(m),'info'));
                            end
                            obj.Size(m,:) = obj.MoreInfo{m}.Size;
                        end
                    case 'pic'
                        if 5<length(a), imdata = mglimresize(mglimread(a{2}),[a{6} a{5}]); else, imdata = mglimread(a{2}); end
                        if 3==size(imdata,3) && 3==length(a{end}), obj.ID(m) = mgladdbitmap(imdata,a{end}); else, obj.ID(m) = mgladdbitmap(imdata); end
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [a{3:4}];
                        obj.MoreInfo{m} = imfinfo(a{2});
                        if 1<length(obj.MoreInfo{m}), obj.MoreInfo{m} = obj.MoreInfo{m}(1); end
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'crc'
                        obj.ID(m) = mgladdbitmap(make_circle(MLConfig.PixelsPerDegree(1)*a{2},a{3},a{4}));
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [a{5:6}];
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'sqr'
                        obj.ID(m) = mgladdbitmap(make_rectangle(MLConfig.PixelsPerDegree(1)*a{2},a{3},a{4}));
                        obj.Modality(m) = 1;
                        obj.Position(m,:) = [a{5:6}];
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Size = mglgetproperty(obj.ID(m),'size');
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'mov'
                        obj.ID(m) = mgladdmovie(a{2});
                        if 4<length(a) && a{5}, mglsetproperty(obj.ID(m),'looping',true); end
                        obj.Modality(m) = 2;
                        obj.Position(m,:) = [a{3:4}];
                        obj.MoreInfo{m}.Filename = a{2};
                        obj.MoreInfo{m} = copyfield(obj,obj.MoreInfo{m},mglgetproperty(obj.ID(m),'info'));
                        obj.Size(m,:) = obj.MoreInfo{m}.Size;
                    case 'snd'
                        [y,fs] = load_waveform(a);
                        if isscalar(y), obj.ID(m) = y; else, obj.ID(m) = mgladdsound(y,fs); end
                        obj.Modality(m) = 3;
                        if 2==length(a)
                            obj.MoreInfo{m}.Filename = a{2};
                        else
                            obj.MoreInfo{m}.Filename = '';
                        end
                        obj.MoreInfo{m}.Duration = mglgetproperty(obj.ID(m),'duration');
                        obj.MoreInfo{m}.Frequency = fs;
                    case 'stm'
                        obj.ID(m) = a{2};
                        obj.Modality(m) = 4;
                        [y,fs] = load_waveform({'stm',a{3}});
                        obj.MoreInfo{m}.Filename = a{3};
                        obj.MoreInfo{m}.Channel = a{2};
                        obj.MoreInfo{m}.Duration = length(y)/fs;
                        obj.MoreInfo{m}.Frequency = fs;
                        o = MLConfig.DAQ.Stimulation{a{2}};
                        if isempty(o)
                            if ~TrialRecord.SimulationMode, error('''Stimulation %d'' is not assigned',a{2}); end
                        else
                            stop(o);
                            actual_rate = setverify(o,'SampleRate',fs);
                            if actual_rate~=fs, error('output frequency is %g kHz, instead of %g kHz',actual_rate/1000,fs/1000); end
                            ch = strcmp(o.Channel.ChannelName,sprintf('Stimulation%d',a{2}));
                            data = zeros(length(y),length(o.Channel));
                            data(:,ch) = y;
                            o.RegenerationMode = a{4};
                            putdata(o,data);
                            start(o);
                        end
                    case 'ttl'
                        obj.ID(m) = a{2};
                        obj.Modality(m) = 5;
                        obj.MoreInfo{m}.Filename = '';
                        obj.MoreInfo{m}.Channel = a{2};
                        if isempty(MLConfig.DAQ.TTL{a{2}}) && ~TrialRecord.SimulationMode, error('''TTL %d'' is not assigned',a{2}); end
                end
            end
        end
    end
end
