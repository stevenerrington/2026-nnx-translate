classdef AudioSound < mlstimulus
    properties
        Enable
        List
        Looping
        PlayPosition
    end
    properties (SetAccess = protected)
        Duration
        SoundID
    end
    properties (Access = protected)
        Filepath
    end
    properties (Hidden)
        PlaybackPosition
        Source  % For backward compatibility, keep the Source property but use List
    end
    
    methods
        function obj = AudioSound(varargin)
            obj@mlstimulus(varargin{:});
        end
        function delete(obj), destroy_sound(obj); end
        function val = importnames(obj), val = ['Source'; fieldnames(obj); 'PlaybackPosition']; end

        function set.Enable(obj,val), numchk(obj,val,'Enable'); obj.Enable = val; end
        function set.List(obj,val), if ~iscell(val), val = {val}; end, obj.List = val; create_sound(obj); end

        function set.Looping(obj,val), row = numchk(obj,val,'Looping'); mglsetproperty(obj.SoundID(row),'looping',val(row)); end
        function set.PlayPosition(obj,val), row = numchk(obj,val,'PlayPosition'); mglsetproperty(obj.SoundID(row),'seek',val(row,:)/1000); end
        function val = get.Looping(obj), nid = numel(obj.SoundID); val = false(nid,1); for m=1:nid, val(m) = mglgetproperty(obj.SoundID(m),'looping'); end, end
        function val = get.PlayPosition(obj), nid = numel(obj.SoundID); val = NaN(nid,1); for m=1:nid, val(m) = mglgetproperty(obj.SoundID(m),'currentposition')*1000; end, end

        function val = get.Duration(obj), nobj = numel(obj.SoundID); val = NaN(nobj,1); for m=1:nobj, val(m) = mglgetproperty(obj.SoundID(m),'duration'); end, val = val * 1000; end

        function set.PlaybackPosition(obj,val), obj.PlayPosition = val; end %#ok<*MCSUP> 
        function set.Source(obj,val), obj.List = val; end
        function val = get.PlaybackPosition(obj), val = obj.PlayPosition; end
        function val = get.Source(obj), val = obj.List; end

        function init(obj,p)
            init@mlstimulus(obj,p);
            if ~obj.Trigger
                obj.Triggered = true;
                mglactivatesound(obj.SoundID,obj.Enable);
            end
        end
        function fini(obj,p)
            fini@mlstimulus(obj,p);
            mglactivatesound(obj.SoundID,false);
            p.stimfile(obj.Filepath);
        end
        function continue_ = analyze(obj,p)
            analyze@mlstimulus(obj,p);
            if obj.Triggered
                if 0<p.scene_frame()
                    isplaying = false;
                    for m=1:numel(obj.SoundID), isplaying = isplaying | mglgetproperty(obj.SoundID(m),'isplaying'); end
                    obj.Success = ~isplaying;
                end
            else
                if obj.Adapter.Success
                    obj.Triggered = true;
                    mglactivatesound(obj.SoundID,obj.Enable);
                    p.eventmarker(obj.EventMarker);
                end
            end
            continue_ = ~obj.Success;
        end
    end
    methods (Access = protected)
        function row = numchk(obj,val,prop)
            if isempty(val), row = []; return, end
            sz = size(val); if numel(obj.SoundID)~=sz(1), error('The length of %s doesn''t match the number of sound objects.',prop); end
            old = obj.(prop); if any(size(old)~=sz), row = 1:sz(1); else, row = find(any(old~=val,2))'; end
        end
        function destroy_sound(obj)
            mgldestroysound(obj.SoundID);
            obj.SoundID = [];
        end
        function create_sound(obj)
            destroy_sound(obj);
            obj.Looping = [];  % To ensure new property values are applied to all newly created graphics
            obj.Filepath = [];
            
            [nobj,col] = size(obj.List);
            list = cell(nobj,2);
            list(:,1:col) = obj.List;
            obj.SoundID = NaN(1,nobj);
            
            Looping = false(nobj,1); %#ok<*PROP>
            for m=1:nobj
                if isempty(list{m,1}), continue, end
                switch class(list{m,1})
                    case 'char'
                        err = []; try [y,fs] = eval(list{m,1}); catch err, end
                        if ~isempty(err), obj.Filepath{end+1} = obj.Tracker.validate_path(list{m,1}); [y,fs] = load_waveform({'snd',obj.Filepath{end}}); end
                        if isscalar(y), obj.SoundID(m) = y; else, obj.SoundID(m) = mgladdsound(y,fs); end
                    case 'double'
                        if isscalar(list{m,1})
                            obj.SoundID(m) = list{m,1};
                        else
                            [y,fs] = load_waveform({'snd',list{m,1}(1)/1000,list{m,1}(2)});
                            obj.SoundID(m) = mgladdsound(y,fs);
                        end
                    otherwise, error('Unknown sound source in Row #%d!!!',m);
                end
                if ~isempty(list{m,2}), Looping(m,:) = logical(list{m,2}); end
            end
            obj.Enable = true(nobj,1);
            obj.Looping = Looping;
            
            mglactivatesound(obj.SoundID,false);
        end
    end
end
