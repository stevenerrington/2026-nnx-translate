classdef analogoutput_playback < dynamicprops
    properties
        BufferingConfig = [64 2] % unused
        Channel
        EventLog
        InitialTriggerTime = [0 0 0 0 0 0]
        Name
        RepeatOutput = 0
        Running = false
        SampleRate = 1000
        SamplesAvailable = 0
        SamplesOutput = 0
        Sending = false
        TriggersExecuted = 0
        TriggerType = 'immediate'
    end
    properties (Constant)
        Type = 'Analog Output';
    end
    properties
        WaveformsQueued = 0
        ManualTriggerWFOutput = 'All'
        ManualTriggerNextWF = []
        RegenerationMode = 0
    end
    properties (SetAccess = protected, Hidden)
        hwInfo;
    end
    properties (Access = protected)
        nSample = 0
        Tic
        AdaptorName;
        DeviceID;
        TaskID;
    end
    properties (Access = protected, Constant)
        TriggerTypeSet = {'Immediate','Manual'};
        ManualTriggerWFOutputSet = {'All','One','Chosen'};
        RegenerationModeSet = {'On','Off'};
        SubsystemType = 2;  % 1: AI, 2: AO, 3: DIO
    end
    
    methods
        function obj = analogoutput_playback(adaptor,DeviceID)
            if ~exist('adaptor','var'), adaptor = 'simulated'; end
            if ~exist('DeviceID','var'), DeviceID = 'Device'; end
            obj.Name = [adaptor DeviceID '-AO'];
        end
        function delete(~), end
        function info = about(~), info = []; end
        function chans = addchannel(obj,hwch,varargin)
            if 1 < length(obj), error('OBJ must be a 1-by-1 analog input or analog output object.'); end
            if obj.isrunning(), error('A channel cannot be added while OBJ is running.'); end
            if 1==nargin, error('Not enough input arguments.  HWCH must be defined with hardware IDs.'); end

            hwch = hwch(:)';
            nchan = length(hwch);
            
            switch nargin
                case 2
                    a = length(obj.Channel) + 1;
                    b = a + nchan - 1;
                    index = a:b;
                    names = cell(1,nchan);
                case 3
                    if isnumeric(varargin{1})
                        index = varargin{1}(:)';
                        names = cell(1,nchan);
                    else
                        a = length(obj.Channel) + 1;
                        b = a + nchan - 1;
                        index = a:b;
                        names = varargin{1}; if ~iscell(names), names = varargin(1); end
                    end
                case 4
                    index = varargin{1};
                    names = varargin{2}; if ~iscell(names), names = varargin(2); end
                otherwise
                    error('Too many input arguments.');
            end
            if nchan~=length(index), error('The length of HWCH must equal the length of INDEX.'); end
            if 1==length(names), names(1,2:nchan) = names(1); end
            if nchan~=length(names), error('Invalid number of NAMES provided for the number of hardware IDs specified in HWCH.'); end
            
            if isempty(obj.Channel)
                if 1~=index(1), error('Invalid INDEX provided.  The Channel array cannot contain gaps.'); end
            else
                HwChannel = obj.Channel.HwChannel;
                Index = obj.Channel.Index;
                if iscell(HwChannel), HwChannel = cell2mat(HwChannel); end
                if iscell(Index), Index = cell2mat(Index); end
                for m=1:nchan
                    if any(HwChannel==hwch(m)), error('A hardware channel with the same name is already in the task.'); end
                    if length(Index)+1 < index(m), error('Invalid INDEX provided.  The Channel array cannot contain gaps.'); end
                    Index = [Index(1:index(m)-1); index(m); Index(index(m):end)];
                    HwChannel = [HwChannel(1:index(m)-1); hwch(m); HwChannel(index(m):end)];
                end
            end
            
            chans(nchan,1) = aochannel_playback;
            for m=1:nchan
                chans(m).Parent = obj;
                chans(m).ChannelName = names{m};
                chans(m).HwChannel = hwch(m);
                chans(m).Index = index(m);
                
                obj.Channel = [obj.Channel(1:chans(m).Index-1); chans(m); obj.Channel(chans(m).Index:end)];
                if ~isempty(chans(m).ChannelName)
                    if ~isprop(obj,chans(m).ChannelName), addprop(obj,chans(m).ChannelName); end
                    obj.(chans(m).ChannelName) = [obj.(chans(m).ChannelName); chans(m)];
                end
            end
            for m=1:length(obj.Channel), obj.Channel(m).Index = m; end
        end
        function start(obj)
            for m=1:length(obj)
                obj(m).Running = true;
                if strcmp(obj(m).TriggerType,'Immediate')
                    obj(m).TriggersExecuted = 0;
                    trigger(obj(m));
                end
            end
        end
        function stop(obj,~)
            obj.WaveformsQueued = 0;
            obj.Running = false;
            obj.Sending = false;
            obj.nSample = 0;
        end
        function tf = isrunning(obj)
            nobj = length(obj);
            tf = false(1,nobj);
            for m=1:nobj, tf(m) = obj(m).Running; end
         end
        function tf = issending(obj)
            nobj = length(obj);
            tf = false(1,nobj);
            for m=1:nobj, tf(m) = obj(m).Sending; end
        end
        function trigger(obj)
            for m=1:length(obj)
                if ~obj(m).Sending
                    obj(m).TriggersExecuted = obj(m).TriggersExecuted + 1;
                    obj(m).Sending = true;
                    obj(m).Tic = tic;
                end
            end
        end
        function wait(obj,waittime)
            for m=1:length(obj)
                aoTimer = tic;
                while toc(aoTimer) < waittime
                    if ~isrunning(obj(m)), break; end
                end
                if isrunning(obj(m)), error('WAIT reached its timeout before OBJ stopped running.'); end
            end
        end
        
        function putdata(obj,data)
            obj.nSample = size(data,1);
            obj.WaveformsQueued = obj.WaveformsQueued + 1;
        end
        function putsample(~,~), end
        function varargout = showdaqevents(~,~), varargout = cell(1,nargout); end
        function register(~,~), end
        
        function val = get.Running(obj)
            if ~isempty(obj.Tic), obj.Running = obj.Sending|obj.RegenerationMode; end
            val = obj.Running;
        end
        function val = get.Sending(obj)
            if isempty(obj.Tic)
                obj.Sending = false;
            else
                duration = obj.nSample * (obj.RepeatOutput + 1) / obj.SampleRate;
                if duration < toc(obj.Tic), obj.Sending = false; obj.Tic = []; end
            end
            val = obj.Sending;
        end

        function out = set(obj,varargin)
            switch nargin
                case 1
                    out = [];
                    fields = properties(obj(1));
                    for m=1:length(fields)
                        propset = [fields{m} 'Set'];
                        if isprop(obj(1),propset), out.(fields{m}) = obj(1).(propset); else, out.(fields{m}) = {}; end
                    end
                    return;
                case 2
                    if ~isscalar(obj), error('Object array must be a scalar when using SET to retrieve information.'); end
                    fields = varargin(1);
                    vals = {{}};
                case 3
                    if iscell(varargin{1})
                        fields = varargin{1};
                        vals = varargin{2};
                        [a,b] = size(vals);
                        if length(obj) ~= a || length(fields) ~= b, error('Size mismatch in Param Cell / Value Cell pair.'); end
                    else
                        fields = varargin(1);
                        vals = varargin(2);
                    end
                otherwise
                    if 0~=mod(nargin-1,2), error('Invalid parameter/value pair arguments.'); end
                    fields = varargin(1:2:end);
                    vals = varargin(2:2:end);
            end
            for m=1:length(obj)
                proplist = properties(obj(m));
                for n=1:length(fields)
                    field = fields{n};
                    if ~ischar(field), error('Invalid input argument type to ''set''.  Type ''help set'' for options.'); end
                    if 1==size(vals,1), val = vals{1,n}; else, val = vals{m,n}; end
                    
                    idx = strncmpi(proplist,field,length(field));
                    if 1~=sum(idx), error('The property, ''%s'', does not exist.',field); end
                    prop = proplist{idx};
                    
                    if ~isempty(val)
                        obj(m).(prop) = val;
                    else
                        propset = [prop 'Set'];
                        if isprop(obj(m),propset)
                            out = obj(m).(propset)(:);
                        else
                            fprintf('The ''%s'' property does not have a fixed set of property values.\n',prop);
                        end
                    end
                end
            end
        end
        function out = get(obj,fields)
            if ischar(fields), fields = {fields}; end
            out = cell(length(obj),length(fields));
            for m=1:length(obj)
                proplist = properties(obj(m));
                for n=1:length(fields)
                    field = fields{n};
                    idx = strncmpi(proplist,field,length(field));
                    if 1~=sum(idx), error('The property, ''%s'', does not exist.',field); end
                    prop = proplist{idx};
                    out{m,n} = obj(m).(prop);
                end
            end
            if isscalar(out), out = out{1}; end
        end
    end
end
