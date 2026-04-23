function id = mgladdsound(varargin)
%id = mgladdsound(filepath)
%id = mgladdsound(y,fs)
%   filepath - wav
%   y - n-by-channel sound data, between 0 and 1
%   fs - sample rate

engine = mglaudioengine;

try
    switch nargin
        case 1
            filename = varargin{1};
            switch engine
                case {2,3}, id = mdqmex(2,11,filename);  % wasapi
                otherwise,  id = mdqmex(2,10,filename);  % xaudio2
            end
        case 2
            y = varargin{1};
            fs = varargin{2};
            [~,I] = max(size(y));
            if 1==I, y = y'; end
            switch engine
                case {2,3}, id = mdqmex(2,11,cast(y,'single'),fs);  % wasapi
                otherwise,  id = mdqmex(2,10,cast(y,'single'),fs);  % xaudio2
            end
    end
catch err
    if 3==engine
        error('Check if you tried to create multiple sound objects. WASAPI Exclusive allows only one sound at a time.');
    else
        rethrow(err);
    end
end