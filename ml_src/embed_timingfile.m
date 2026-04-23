function runtime_script = embed_timingfile(MLConfig,timingfile,trialholder)

newline = char(10); %#ok<CHARTEN>
search_path = {MLConfig.MLPath.ExperimentDirectory,MLConfig.MLPath.BaseDirectory};

% process the timing file
timing_code = fileread(timingfile);
userfunc = '';
if verLessThan('matlab','9.1')
    userfunc_startpoint = strfind(timing_code,[newline 'function ']);
    if ~isempty(userfunc_startpoint)
        userfunc = [timing_code(userfunc_startpoint:end) newline];
        timing_code = timing_code(1:userfunc_startpoint);
    end
end
lastwarn('');  % clear last warning to catch errors in the timing file
timing_code = regexp(tree2str(mtree(timing_code)),'[^\n]+\n|[^\n]+$','match')';
timing_trimmed = strtrim(timing_code);

% if the timing script has a syntax error
[msgstr,msgid] = lastwarn;
if strcmp(msgid,'MATLAB:mtree:tree2str:errtree'), error(regexprep(msgstr,'argument',timingfile)); end

% include
m = find(strncmp(timing_trimmed,'include',7),1);
while ~isempty(m)
    code_to_include = eval(timing_code{m});
    timing_code = [timing_code(1:m-1); code_to_include; timing_code(m+1:end)];
    timing_trimmed = [timing_trimmed(1:m-1); strtrim(code_to_include); timing_trimmed(m+1:end)];
    m = find(strncmp(timing_trimmed,'include',7),1);
end

% abort_trial or return
timing_code(strncmp(timing_trimmed,'abort_trial',11)|strncmp(timing_trimmed,'return',6)) = {'end_trial; return'};

% editable
MLEditable = struct;
MLEditable.editable = struct;  % this is the field where the types of variables will be set.
MLEditable.reward_dur = MLConfig.RewardFuncArgs.Duration;
MLEditable.editable.reward_dur = '';
editable_definition = find(strncmp(timing_trimmed,'editable',8));
for m=editable_definition'
    [varname,types] = eval(timing_code{m});
    for n=1:length(varname)
        MLEditable.(varname{n}) = [];
        MLEditable.editable.(varname{n}) = types{n};
    end
end
if ~isempty(editable_definition), timing_code(editable_definition) = {''}; end

vars = mlsetdiff(fieldnames(MLEditable),'editable');
for m=1:length(vars)
    tokens = regexp(timing_trimmed,['^' vars{m} '[\t ]*=(.+)$'],'tokens');
    n = find(~cellfun(@isempty,tokens),1);
    if isempty(n)
        if ~strcmp(vars{m},'reward_dur'), MLEditable = rmfield(MLEditable,vars{m}); end
    else
        try val = eval(tokens{n}{1}{1}); catch, error('%s is an editable and must be initialized with only numbers or strings in the timing script.',vars{m}); end
        switch MLEditable.editable.(vars{m})
            case {'file','dir'}, sanity = isa(val,'char'); str = 'The ''file'' or ''dir'' type must be char.';
            case 'color', sanity = isnumeric(val) && isvector(val) && 3==length(val); str = 'The ''color'' type must be a 1-by-3 double vector.';
            case 'category', sanity = iscell(val) && isvector(val) && all(cellfun(@ischar,val)) && 1==sum(strcmp(val(1:end-1),val{end})); str = 'The ''category'' type must be a cell char array in which the last cell indicates the chosen category.';
            case 'range', sanity = isnumeric(val) && 4==numel(val) && val(1)<val(2) && 0<val(3) && val(3)<=(val(2)-val(1)) && val(1)<=val(end) && val(end)<=val(2); str = 'The ''range'' type must be [min max step value].';
            otherwise, sanity = ((islogical(val) || isnumeric(val)) && 0<numel(val) && numel(val)<7) || ischar(val); str = 'An editable must be a numeric/logical variable with 6 or less elements or a char array.';
        end
        if ~sanity, error(['Incorrect value for the editable variable, %s.' newline '%s'],vars{m},str); end
        MLEditable.(vars{m}) = val;
        timing_code{n} = '';
    end
end

if isempty(MLConfig.SubjectName), editable_by_subject = 'MLEditable'; else, editable_by_subject = ['MLEditable_' lower(MLConfig.SubjectName)]; end
if 2==exist(MLConfig.MLPath.ConfigurationFile,'file')
    saved_vars = whos('-file',MLConfig.MLPath.ConfigurationFile,editable_by_subject);
    if ~isempty(saved_vars) && 0<saved_vars.bytes
        saved_vars = load(MLConfig.MLPath.ConfigurationFile,editable_by_subject);
        MLEditable = copyfield(MLEditable,saved_vars.(editable_by_subject));
    else 
        saved_vars = whos('-file',MLConfig.MLPath.ConfigurationFile,'MLEditable');
        if ~isempty(saved_vars) && 0<saved_vars.bytes
            saved_vars = load(MLConfig.MLPath.ConfigurationFile,'MLEditable');
            MLEditable = copyfield(MLEditable,saved_vars.MLEditable);
        end
    end
end
if ~isempty(vars) && (~exist('trialholder','var') || ~strcmp(trialholder,'DO_NOT_OVERWRITE_EDITABLES'))
    if 2==exist(MLConfig.MLPath.ConfigurationFile,'file'), config = load(MLConfig.MLPath.ConfigurationFile); end
    config.MLEditable = MLEditable;
    config.(editable_by_subject) = MLEditable;
    save(MLConfig.MLPath.ConfigurationFile,'-struct','config');
    
    editable_vars = cell(length(vars),1);
    for m=1:length(vars), editable_vars{m} = sprintf('%s = TrialData.VariableChanges.%s;', vars{m}, vars{m}); end
    timing_code = [editable_vars; timing_code];
end
timing_code = regexprep(timing_code,'(.*)',['$1' newline]);

% read trialholder
if ~exist('trialholder','var') || 2~=exist(trialholder,'file')
    if any(~cellfun(@isempty,regexp(timing_trimmed,'toggleobject|eyejoytrack')))
        if any(~cellfun(@isempty,regexp(timing_trimmed,'create_scene|run_scene')))
            error('You cannot mix create_scene/run_scene (ver 2) with toggleobject/eyejoytrack (ver 1) in a timing script.');
        end
        
        trialholder = [MLConfig.MLPath.BaseDirectory 'trialholder_v1.m'];
        % Note that this part can be called every trial, if the userloop returns the trialholder filename.
        hFig = findobj('tag','mlmonitor');
        if ~isempty(hFig)
            set(findobj(hFig,'tag','MaxLatencyLabel'),'string','Max latency');
            set(findobj(hFig,'tag','CycleRateLabel'),'string','Cycle rate');
        end
    else
        trialholder = [MLConfig.MLPath.BaseDirectory 'trialholder_v2.m'];
        % Note that this part can be called every trial, if the userloop returns the trialholder filename.
    end
end
trialholder_code = fileread(trialholder);
insertion_point = strfind(trialholder_code,'%END OF TIMING CODE********************************************************');
if isempty(insertion_point), error('There is no timing script insertion point in ''%s''',trialholder); end

% minify runtime
if MLConfig.MinifyRuntime
    runtime_code = strtrim(regexp(tree2str(mtree([trialholder_code(1:insertion_point-1) [timing_code{:}] ...
        userfunc trialholder_code(insertion_point:end)])),'[^\n]+\n|[^\n]+$','match'))';
    tokens = regexp(runtime_code,'^([^'']*)(''.*'')([^'']*)$','tokens');
    row = cellfun(@isempty,tokens);
    tokens(row) = runtime_code(row);
    for m=1:length(tokens)
        if iscell(tokens{m})
            runtime_code{m} = [remove_blank(tokens{m}{1}{1}) tokens{m}{1}{2} remove_blank(tokens{m}{1}{3})];
        else
            runtime_code{m} = remove_blank(tokens{m});
        end
    end
else
    runtime_code = regexprep(regexp([trialholder_code(1:insertion_point-1) [timing_code{:}] userfunc ...
        trialholder_code(insertion_point:end)],'[^\n]+\n|[^\n]+$','match')','\n$','');
end

% write runtime
[~,funcname] = fileparts(timingfile);
funcname = [funcname '_runtime'];
runtime_code{1} = strrep(runtime_code{1},'trialholder',funcname);
runtime_script = [MLConfig.MLPath.RunTimeDirectory funcname '.m'];
if 2==exist(runtime_script,'file'), delete(runtime_script); end  % This is to show an error message where deletion is impossible. fopen doesn't make one.
fid = fopen(runtime_script,'w');
try
    for m=1:length(runtime_code)
        fprintf(fid,'%s\n',runtime_code{m});
    end
    fclose(fid);
%     pcode(funcname,'-inplace');
catch err
    fclose(fid);
    rethrow(err);
end

    function code = include(varargin)
        nfile = length(varargin);
        code = cell(nfile,1);
        for ml=1:nfile
            filepath = mlsetpath(varargin{ml},search_path);
            if isempty(filepath), error('%s does not exist.',varargin{ml}); end
            
            code{ml} = fileread(filepath);
            lastwarn('');  % clear last warning to catch errors
            code{ml} = regexp(tree2str(mtree(code{ml})),'[^\n]+\n|[^\n]+$','match')';
            [msgstr,msgid] = lastwarn;  % if the included script has a syntax error
            if strcmp(msgid,'MATLAB:mtree:tree2str:errtree'), error(regexprep(msgstr,'argument',varargin{m})); end
        end
        code = vertcat(code{:});
    end

end  % end of embedtimingfile


function str = remove_blank(str)
    symbols = {' = ','='; ' \+ ','\+'; ' - ','-'; ' \.\* ','\.\*'; ' \./ ','\./'; ' \.\^ ','\.\^'; ' & ','&'; ' && ','&&'; ' \| ','\|'; ' \|\| ','\|\|'; ...
        '\) \(','\)\('; '\[ ','\['; ' \]','\]'; '\( ','\('; ' \)','\)'; '{ ','{'; ' }','}'; ', ',','; '; ',';'};
    str = regexprep(str,symbols(:,1),symbols(:,2));
end

function dest = copyfield(dest,src)
    field = mlsetdiff(intersect(fieldnames(src),fieldnames(dest)),'editable');
    for m=1:length(field)
        if ~isa(dest.(field{m}),class(src.(field{m}))), continue, end
        if isfield(src,'editable') && isfield(src.editable,field{m}) && ~strcmp(src.editable.(field{m}),dest.editable.(field{m})), continue, end
        dest.(field{m}) = src.(field{m});
    end
end

function [varnames,types] = editable(varargin)
    global_type = '';
    type = '';
    count = 1;
    for m=1:length(varargin)
        var = varargin{m}; if ~iscell(var), var = {var}; end
        nvar = length(var);
        for n=1:nvar
            switch lower(var{n})
                case '-file', type = 'file';
                case '-dir', type = 'dir';
                case '-color', type = 'color';
                case '-category', type = 'category';
                case '-range', type = 'range';
                otherwise
                    varnames{count} = var{n}; %#ok<*AGROW>
                    types{count} = global_type;
                    if ~isempty(type), types{count} = type; end
                    type = '';
                    count = count + 1;
            end
            if n==nvar, global_type = type; end
        end
    end
end
