classdef mltrialrecord < handle
    properties (SetAccess = protected)
        CurrentTrialNumber = 0
        CurrentTrialWithinBlock = 0
        CurrentCondition = 0
        CurrentBlock = 0
        CurrentBlockCount = 0
        CurrentConditionInfo
        CurrentConditionStimulusInfo = []
        ConditionsPlayed = []
        ConditionsThisBlock = []
        BlocksPlayed = []
        BlockCount = []
        BlockOrder = []
        BlocksSelected = []
        TrialErrors = []
        ReactionTimes = []
        LastTrialAnalogData
        LastTrialCodes
        Editable = []
        DataFile = []
    end
    properties
        SimulationMode = false
        BlockChange = true
        Pause = true
        Quit = false
        NextBlock = []
        NextCondition = []
        User = []
        DrawTimeLine = true
        MarkSkippedFrames = false
        DiscardSkippedFrames = true
        HotkeyLocked = false
        BehaviorSummary = false
    end
    properties (Hidden)
        TestTrial = false
        TaskInfo = []
        InterTrialInterval
        InterTrialIntervalTimer
    end
    properties (SetAccess = protected, Hidden)
        ErrorLogic
        CondLogic
        BlockLogic
        NumberOfTrialsToRunInThisBlock
        CountOnlyCorrectTrials
        TotalNumberOfTrialsToRun
        TotalNumberOfBlocksToRun
        MLConditions
        CondSelectFunction
        BlockSelectFunction
        BlockChangeFunction

        CompletedTrialsInThisBlock = 0
        BlocksAvailable = []
    end
    properties (Constant, Hidden)
        MLConfigFields = {'ErrorLogic','CondLogic','BlockLogic','NumberOfTrialsToRunInThisBlock','CountOnlyCorrectTrials',...
            'TotalNumberOfTrialsToRun','TotalNumberOfBlocksToRun','MLConditions'};
    end
    
    methods
        function obj = mltrialrecord(MLConfig)
            obj.TaskInfo.Stimuli = {};
            if exist('MLConfig','var') && isa(MLConfig,'mlconfig')
                for m=obj.MLConfigFields, obj.(m{1}) = MLConfig.(m{1}); end
                obj.BlocksSelected = MLConfig.BlocksToRun;
                obj.CondSelectFunction = get_function_handle(MLConfig.CondSelectFunction);
                obj.BlockSelectFunction = get_function_handle(MLConfig.BlockSelectFunction);
                obj.BlockChangeFunction = get_function_handle(MLConfig.BlockChangeFunction);
                if ~isempty(MLConfig.FirstBlockToRun), obj.NextBlock = MLConfig.FirstBlockToRun; end
            end
        end
        function set.NextBlock(obj,val)
            obj.NextBlock = val;
            if ~isempty(val) && obj.MLConditions.isuserloopfile(), obj.BlockChange = obj.BlockChange | val ~= obj.CurrentBlock; end %#ok<*MCSUP>
        end
        
        function obj = new_trial(obj,MLConfig,varargin)
            do_not_call_user_scripts = 2<nargin;
            obj.CurrentTrialNumber = obj.CurrentTrialNumber + 1;
            obj.CurrentTrialWithinBlock = obj.CurrentTrialWithinBlock + 1;

            if obj.MLConditions.isconditionsfile()  % conditions file

                get_new_condition = true;
                if ~isempty(obj.TrialErrors) && 0~=obj.TrialErrors(end)
                    switch obj.ErrorLogic
                        case 1  % ignore
                        case 2  % repeat immediately
                            get_new_condition = false;
                        case 3  % repeat delayed
                            switch obj.CondLogic
                                case 2
                                    get_new_condition = false;
                                    if ~isempty(obj.ConditionsThisBlock)
                                        CurrentCondition = obj.CurrentCondition; %#ok<*PROPLC> 
                                        idx = ceil(rand*length(obj.ConditionsThisBlock)); obj.CurrentCondition = obj.ConditionsThisBlock(idx); obj.ConditionsThisBlock(idx) = [];
                                        obj.ConditionsThisBlock = sort([obj.ConditionsThisBlock CurrentCondition]);
                                    end
                            end
                    end
                end
                
                for n=1:2
                    if ~isempty(obj.NextBlock) || obj.BlockChange
                        if obj.TotalNumberOfBlocksToRun<=obj.CurrentBlockCount, obj.NextBlock = -1; return, end  % early quit when TotalNumberOfBlocksToRun is reached
                        if isempty(obj.BlocksAvailable), obj.BlocksAvailable = obj.BlocksSelected; end
                        if ~isempty(obj.NextBlock)
                            if isempty(find(obj.BlocksSelected==obj.NextBlock,1)), error('Block #%d is not available',obj.NextBlock); end
                            obj.CurrentBlock = obj.NextBlock;
                            obj.NextBlock = [];
                            obj.BlocksAvailable(find(obj.BlocksAvailable==obj.CurrentBlock,1)) = [];
                        else
                            switch obj.BlockLogic
                                case 1  % random with replacement
                                    obj.CurrentBlock = obj.BlocksSelected(ceil(rand*length(obj.BlocksSelected)));
                                case 2  % random without replacement
                                    NextBlock = obj.CurrentBlock; %#ok<*PROP>
                                    while obj.CurrentBlock == NextBlock
                                        nblocks_available = length(obj.BlocksAvailable);
                                        idx = ceil(rand*nblocks_available);
                                        NextBlock = obj.BlocksAvailable(idx);
                                        if 1==nblocks_available, break, end
                                    end
                                    obj.CurrentBlock = NextBlock;
                                    obj.BlocksAvailable(idx) = [];
                                case 3  % increasing
                                    obj.CurrentBlock = obj.BlocksAvailable(1);
                                    obj.BlocksAvailable(1) = [];
                                case 4  % decreasing
                                    obj.CurrentBlock = obj.BlocksAvailable(end);
                                    obj.BlocksAvailable(end) = [];
                                case 5  % user-defined
                                    if do_not_call_user_scripts
                                        obj.CurrentBlock = obj.BlocksSelected(1);
                                    else
                                        if isempty(obj.BlockSelectFunction), error('No block selection function is defined'); end
                                        if 1<nargin(obj.BlockSelectFunction), obj.CurrentBlock = obj.BlockSelectFunction(obj,MLConfig); else, obj.CurrentBlock = obj.BlockSelectFunction(obj); end
                                        if obj.CurrentBlock<0  % quit the task
                                            obj.NextBlock = -1; return
                                        elseif isempty(find(obj.BlocksSelected==obj.CurrentBlock,1))
                                            error('Block #%d is not available',obj.CurrentBlock);
                                        end
                                    end
                            end
                        end
                        obj.BlockChange = false;

                        obj.CurrentTrialWithinBlock = 1;
                        obj.CurrentBlockCount = obj.CurrentBlockCount + 1;
                        obj.BlockOrder(end+1) = obj.CurrentBlock;
                        obj.CompletedTrialsInThisBlock = 0;
                        obj.ConditionsThisBlock = [];

                        get_new_condition = true;
                    end

                    if get_new_condition
                        if isempty(obj.ConditionsThisBlock)
                            for m=1:length(obj.MLConditions.Conditions)
                                if all(obj.CurrentBlock~=obj.MLConditions.Conditions(m).Block), continue, end
                                obj.ConditionsThisBlock = [obj.ConditionsThisBlock repmat(obj.MLConditions.Conditions(m).Condition,1,obj.MLConditions.Conditions(m).Frequency)];
                            end
                            if isempty(obj.ConditionsThisBlock), error('No condition is available for Block #%d',obj.CurrentBlock); end
                        end
                        switch obj.CondLogic
                            case 1  % random with replacement
                                obj.CurrentCondition = obj.ConditionsThisBlock(ceil(rand*length(obj.ConditionsThisBlock)));
                            case 2  % random without replacement
                                idx = ceil(rand*length(obj.ConditionsThisBlock));
                                obj.CurrentCondition = obj.ConditionsThisBlock(idx);
                                obj.ConditionsThisBlock(idx) = [];
                            case 3  % increasing
                                obj.CurrentCondition = obj.ConditionsThisBlock(1);
                                obj.ConditionsThisBlock(1) = [];
                            case 4  % decreasing
                                obj.CurrentCondition = obj.ConditionsThisBlock(end);
                                obj.ConditionsThisBlock(end) = [];
                            case 5  % user-defined
                                if do_not_call_user_scripts
                                    obj.CurrentCondition = obj.ConditionsThisBlock(1);
                                else
                                    if isempty(obj.CondSelectFunction), error('No condition selection function is defined'); end
                                    if 1<nargin(obj.CondSelectFunction), obj.CurrentCondition = obj.CondSelectFunction(obj,MLConfig); else, obj.CurrentCondition = obj.CondSelectFunction(obj); end
                                    if obj.CurrentCondition<0  % change the block
                                        obj.BlockChange = true;
                                    elseif isempty(find(obj.ConditionsThisBlock==obj.CurrentCondition,1))
                                        error('Condition #%d doesn''t exist',obj.CurrentCondition);
                                    end
                                end
                        end
                    end
                    if 0<obj.CurrentCondition, break, end
                end                
                obj.CurrentConditionInfo = obj.MLConditions.Conditions(obj.CurrentCondition).Info;
                
            else  % userloop file
                
                if obj.BlockChange
                    obj.CurrentTrialWithinBlock = 1;
                    if isempty(obj.NextBlock), obj.CurrentBlock = obj.CurrentBlock + 1; else, obj.CurrentBlock = obj.NextBlock; obj.NextBlock = []; end
                    obj.CurrentBlockCount = obj.CurrentBlockCount + 1;
                    obj.BlockOrder(end+1) = obj.CurrentBlock;
                    obj.CompletedTrialsInThisBlock = 0;
                    obj.BlockChange = false;
                end
                if isempty(obj.NextCondition), obj.CurrentCondition = 1; else, obj.CurrentCondition = obj.NextCondition; obj.NextCondition = []; end
                
            end
        end
        function update_trial_result(obj,trialdata,MLConfig)
            obj.ConditionsPlayed(end+1) = obj.CurrentCondition;
            obj.BlocksPlayed(end+1) = obj.CurrentBlock;
            obj.BlockCount(end+1) = obj.CurrentBlockCount;
            obj.TrialErrors(end+1) = trialdata.TrialError;
            if isempty(trialdata.ReactionTime), trialdata.ReactionTime = NaN; end
            obj.ReactionTimes(end+1) = trialdata.ReactionTime;
            obj.LastTrialAnalogData = trialdata.AnalogData;
            obj.LastTrialCodes = trialdata.BehavioralCodes;
            block_idx = find(obj.CurrentBlock==obj.MLConditions.UIVars.BlockList,1);
            if obj.CountOnlyCorrectTrials(block_idx)
                if 0==obj.TrialErrors(end), obj.CompletedTrialsInThisBlock = obj.CompletedTrialsInThisBlock + 1; end
            else
                obj.CompletedTrialsInThisBlock = obj.CompletedTrialsInThisBlock + 1;
            end
            if obj.NumberOfTrialsToRunInThisBlock(block_idx)<=obj.CompletedTrialsInThisBlock, obj.BlockChange = true; end
            if ~isempty(obj.BlockChangeFunction)
                if 1<nargin(obj.BlockChangeFunction), val = obj.BlockChangeFunction(obj,MLConfig); else, val = obj.BlockChangeFunction(obj); end
                if val<0      % -1 indicates the task has been completed
                    obj.Quit = true; return
                elseif 0<val  % if not zero, change the block
                    obj.BlockChange = true;  % if BlockChangeFunction and BlockSelectionFunction are the same, the value indicates the next block number.
                    if 5==obj.BlockLogic && ~isempty(obj.BlockSelectFunction) && strcmp(func2str(obj.BlockSelectFunction),func2str(obj.BlockChangeFunction)), obj.NextBlock = val; end
                end
            end
            if obj.BlockChange && obj.TotalNumberOfBlocksToRun<=obj.CurrentBlockCount, obj.Pause = true; end
            if obj.TotalNumberOfTrialsToRun<=obj.CurrentTrialNumber, obj.Pause = true; end
        end
        function export_to_file(obj,fout,varname)
            if ~exist('varname','var'), varname = 'TrialRecord'; end
            try
                dest = [];
                field = [properties(obj); 'TaskInfo'];
                for m=1:length(field), dest.(field{m}) = obj.(field{m}); end
                if ~isopen(fout), open(fout,fout.filename,'a'); end
                fout.write(dest,varname);
            catch err
                close(fout);
                rethrow(err);
            end
        end
    end
    
    methods (Hidden)
		function next_block(obj,val), obj.NextBlock = val; end  % deprecated
        function next_condition(obj,val), obj.NextCondition = val; end  % deprecated
        function setCurrentConditionInfo(obj,val), obj.CurrentConditionInfo = val; end
        function setCurrentConditionStimulusInfo(obj,val), obj.CurrentConditionStimulusInfo = val; end
        function setEditable(obj,val), obj.Editable = val; end
        function setDataFile(obj,val), obj.DataFile = val; end
        function setErrorLogic(obj,val), if 0<val && val<4, obj.ErrorLogic = val; end, end
    end
end
