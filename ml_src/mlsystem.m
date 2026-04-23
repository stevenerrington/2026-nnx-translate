classdef mlsystem < handle
    properties (SetAccess = protected)
        OperatingSystem
        OSVersion
        ComputerName
        UserName
        ProcessorID
        NumberOfProcessors
        ProcessorArchitecture
        NumberOfScreenDevices
        MatlabVersion
    end
    
    methods
        function val = get.OperatingSystem(~), [~,v] = system('ver'); val = strtrim(v); end
        function val = get.OSVersion(obj), val = cellfun(@str2num,regexp(obj.OperatingSystem,'(\d+)','match')); end
        function val = get.ComputerName(~), val = getenv('COMPUTERNAME'); end
        function val = get.UserName(~), val = getenv('USERNAME'); end
        function val = get.ProcessorID(~), val = getenv('PROCESSOR_IDENTIFIER'); end
        function val = get.NumberOfProcessors(~), val = getenv('NUMBER_OF_PROCESSORS'); end
        function val = get.ProcessorArchitecture(~)
            val = getenv('PROCESSOR_ARCHITECTURE');
            if isempty(val), val = getenv('CPU'); end
        end
        function val = get.NumberOfScreenDevices(~)
            try
                val = mglgetadaptercount;
            catch
                val = size(get(0,'MonitorPositions'),1);
            end
        end
        function val = get.MatlabVersion(~), val = ver; end
    end
end
