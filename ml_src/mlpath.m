classdef mlpath < matlab.mixin.Copyable
    properties
        BaseDirectory
        ConditionsFile
        DataFile
    end
    properties (Dependent)
        ExperimentDirectory
        RunTimeDirectory
        DocDirectory
        ConfigurationFile
        BehavioralCodesFile
        AlertFunction
        RewardFunction
    end
    properties (Constant, Hidden)
        BehavioralCodesFileName = 'codes.txt';
        AlertFunctionName = 'alert_function.m';
        RewardFunctionName = 'reward_function.m';
        DefaultConfigPath = [getenv('LocalAppData') filesep 'NIMH_MonkeyLogic' filesep 'monkeylogic_cfg2.mat'];
    end
    
    methods (Access = protected)
        function cp = copyElement(obj)
            cp = copyElement@matlab.mixin.Copyable(obj);
        end
    end
    
    methods
        function obj = mlpath(BaseDirectory)
            if ~exist('BaseDirectory','var'), BaseDirectory = ''; end
            obj.BaseDirectory = BaseDirectory;
            obj.ConditionsFile = '';
            obj.DataFile = '';
        end
        
        function set.BaseDirectory(obj,val)
            if exist(val,'dir')
                if filesep~=val(end), val(end+1) = filesep; end
            elseif 2==exist(val,'file')
                p = fileparts(val);
                if isempty(p), val = fileparts(which(val)); else, val = p; end
                val = [val filesep];
            else
                val = [fileparts(mfilename('fullpath')) filesep];
            end
            if 2~=exist([val 'monkeylogic.m'],'file'), error('mlpath:fileNotFound','''monkeylogic.m'' is not found in ''%s''',val); end
            obj.BaseDirectory = val;
        end
        function set.ConditionsFile(obj,val)
            if 2~=exist(val,'file'), obj.ConditionsFile = ''; return, end
            if isempty(fileparts(val)), val = which(val); end
            obj.ConditionsFile = val;
        end
        function set.DataFile(obj,val)
            [~,n,e] = fileparts(val);
            obj.DataFile = [n e];
        end
        
        function val = get.ExperimentDirectory(obj)
            if isempty(obj.ConditionsFile), val = ''; else, val = [fileparts(obj.ConditionsFile) filesep]; end
        end
        function val = get.RunTimeDirectory(~)
            val = tempdir;
        end
        function val = get.DocDirectory(obj)
            if isempty(obj.BaseDirectory), val = ''; else, val = [obj.BaseDirectory 'doc' filesep]; end
        end
        function val = get.ConfigurationFile(obj)
            if ~isempty(obj.ConditionsFile)
                [p,n] = fileparts(obj.ConditionsFile);
                if ~isempty(p), p = [p filesep]; end
                val = [p n '_cfg2.mat'];
            elseif ~isempty(obj.BaseDirectory)
                localappdata = [getenv('LocalAppData') filesep 'NIMH_MonkeyLogic' filesep];
                val = [localappdata 'monkeylogic_cfg2.mat'];
                old_cfg = [tempdir 'monkeylogic_cfg2.mat'];
                try
                    if ~exist(localappdata,'dir'), mkdir(localappdata); end
                    if ~exist(val,'file') && exist(old_cfg,'file'), movefile(old_cfg,val); end
                catch
                    val = old_cfg;
                end
            else
                val = '';
            end
        end
        function val = get.BehavioralCodesFile(obj)
            val = validate_path(obj,obj.BehavioralCodesFileName);
        end
        function val = get.AlertFunction(obj)
            val = validate_path(obj,obj.AlertFunctionName);
        end
        function val = get.RewardFunction(obj)
            val = validate_path(obj,obj.RewardFunctionName);
        end
        function filepath = validate_path(obj,filepath)
            filepath = mlsetpath(filepath,{obj.ExperimentDirectory,obj.BaseDirectory,[obj.BaseDirectory 'mgl']});
        end
    end
end
