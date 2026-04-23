% This is not an NIMH ML task but a MATLAB script to explain how to use MGL
% functions directly.

base_folder = [fileparts(which('monkeylogic')) filesep];
addpath([base_folder 'daqtoolbox']);
addpath([base_folder 'mgl']);

media_root = [getenv('SystemRoot') filesep 'Media' filesep];
test_sound1 = [media_root 'Alarm01.wav'];
if ~exist(test_sound1,'file'), test_sound1 = [media_root 'notify.wav']; end
test_sound2 = [media_root 'Alarm02.wav'];
if ~exist(test_sound2,'file'), test_sound2 = [media_root 'chord.wav']; end

mglaudioengine(1);  % use XAUDIO2
try
    % get the audio device info
    [engine,device,format,deviceAvailable,formatAvailable] = mglaudioengine;
    switch engine
        case 1, engineStr = 'XAUDIO2';
        case 2, engineStr = 'WASAPI_SHARED';
        case 3, engineStr = 'WASAPI_EXCLUSIVE';
    end
    if ~iscell(deviceAvailable), deviceAvailable = {deviceAvailable}; end
    if ~iscell(formatAvailable), formatAvailable = {formatAvailable}; end
    fprintf('Engine: %s, %d device(s) available, %d format(s) available\n',engineStr,length(deviceAvailable),length(formatAvailable));

    % setting audio engine
    mglaudioengine(engine,device,format);  % XAUDIO2 has only one device and one format always
    fprintf('Device: %s\nFormat: %s\n\n',deviceAvailable{device},formatAvailable{format});
    
    % add sounds
    snd1 = mgladdsound(test_sound1);
    snd2 = mgladdsound(test_sound2);
    mglplaysound;
    while mglgetproperty(snd1,'isplaying') || mglgetproperty(snd2,'isplaying'), end
    mglstopsound;  % not necessary since we waited until playback finished above
    
    % destroy sounds
    mgldestroysound([snd1 snd2]);
    
catch err
    if exist('snd1','var'), mgldestroysound(snd1); end
    if exist('snd2','var'), mgldestroysound(snd2); end
    rethrow(err);
end

mglaudioengine(2);  % use WASAPI_SHARED
try
    [engine,device,format,deviceAvailable,formatAvailable] = mglaudioengine;
    switch engine
        case 1, engineStr = 'XAUDIO2';
        case 2, engineStr = 'WASAPI_SHARED';
        case 3, engineStr = 'WASAPI_EXCLUSIVE';
    end
    if ~iscell(deviceAvailable), deviceAvailable = {deviceAvailable}; end
    if ~iscell(formatAvailable), formatAvailable = {formatAvailable}; end
    fprintf('Engine: %s, %d device(s) available, %d format(s) available\n',engineStr,length(deviceAvailable),length(formatAvailable));
    
    % change device and format
%     device = 1;  % change as needed
%     format = 1;  % change as needed
    mglaudioengine(engine,device,format);
    fprintf('Device: %s\nFormat: %s\n\n',deviceAvailable{device},formatAvailable{format});
    
    snd1 = mgladdsound(test_sound1);
    snd2 = mgladdsound(test_sound2);
    mglplaysound;
    while mglgetproperty(snd1,'isplaying') || mglgetproperty(snd2,'isplaying'), end
    mgldestroysound([snd1 snd2]);
    
catch err
    if exist('snd1','var'), mgldestroysound(snd1); end
    if exist('snd2','var'), mgldestroysound(snd2); end
    rethrow(err);
end
