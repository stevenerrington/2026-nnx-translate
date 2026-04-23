function [y,fs] = load_waveform(stim)

y = []; fs = [];

if ischar(stim), stim = {stim}; end
try
    switch length(stim)
        case 1
            [~,n,e] = fileparts(stim{1});
            w = load(stim{1});
            f = fieldnames(w);
            v = find(strcmpi(f,'y')|strcmpi(f,'waveform'),1);
            if ~isempty(v), y = w.(f{v}); end
            v = find(strcmpi(f,'fs')|strcmpi(f,'freq')|strcmpi(f,'frequency'),1);
            if ~isempty(v), fs = w.(f{v}); end
            if isempty(y) || isempty(fs), error('''%s'' does not contain y and/or fs',[n e]); end
        case 2
            [~,~,e] = fileparts(stim{2});
            switch lower(e)
                case '.wav'
                    if strcmpi(stim{1},'snd')
                        y = mgladdsound(stim{2});  % For exta long wav files, let MGL stream them.
                        fs = mglgetproperty(y,'frequency');
                    else
                        [y,fs] = audioread(stim{2});
                    end
                case '.mat', [y,fs] = load_waveform(stim{2});
                case {'.m4a','.aac','.mp3','.ogg','.mp4','.avi'}, [y,fs] = audioread(stim{2});
            end
        case 3
            fs = 48000;
            t = 0:1/fs:stim{2};
            y = sin(2*pi*stim{3}*t)';
    end
catch err
    error('load_waveform: %s',err.message);
end
