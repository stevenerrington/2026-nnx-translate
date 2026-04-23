function hw = daqhwinfo(varargin)

switch nargin
    case 0
        [hw.ToolboxName,hw.ToolboxVersion] = daq.getToolboxInfo;
        v = ver('MATLAB');
        hw.MATLABVersion = [v.Version ' ' v.Release];
        hw.InstalledAdaptors = mdqmex(20,1,1);
    case 1
        switch class(varargin{1})
            case 'char'
                if strcmpi(varargin{1},'all'), hw = mdqmex(20,1); return, end
                hw = mdqmex(20,2,lower(varargin{1}));
            case {'analoginput','analogoutput','digitalio','pointingdevice','eyetracker','videocapture'}
                hw = about(varargin{1});
            otherwise
                error('Unknown device type!!!');
        end
end
