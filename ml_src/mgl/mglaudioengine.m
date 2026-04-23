function varargout = mglaudioengine(engine,device,format)
%mglaudioengine(engine,device,format)
%[engine,device,format,deviceName,formatString] = mglaudioengine
%   engine - 1 (XAudio2), 2 (WASAPI Shared), 3 (WASAPI Exclusive)
%   device - 1-based, device number selected from deviceName
%   format - 1-based, format number chosen from formatString

if ~exist('engine','var') || isempty(engine), engine = 0; end
if ~exist('device','var') || isempty(device), device = 0; end
if ~exist('format','var') || isempty(format), format = 0; end
mdqmex(11,14,engine,device,format);

[engine,device,format,deviceName,formatString,info] = mdqmex(11,14);
if 0 == nargout
    switch engine
        case 1, varargout{1} = 'XAUDIO2';
        case 2, varargout{1} = 'WASAPI_SHARED';
        case 3, varargout{1} = 'WASAPI_EXCLUSIVE';
    end
end
if 0<nargout, varargout{1} = engine; end
if 1<nargout, varargout{2} = device; end
if 2<nargout, varargout{3} = format; end
if 3<nargout, varargout{4} = deviceName; end
if 4<nargout, varargout{5} = formatString; end
if 5<nargout, varargout{6} = info; end
