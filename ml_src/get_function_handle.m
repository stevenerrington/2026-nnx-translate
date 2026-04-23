function h = get_function_handle(funcpath)

h = [];
if ~exist('funcpath','var') || 2~=exist(funcpath,'file'), return, end

cwd = [];
err = [];
try
    [p,n] = fileparts(funcpath);
    if exist(p,'dir'), cwd = pwd; cd(p); end
    eval(['clear ' n]);
    h = str2func(n);
    nargin(h);
catch err
end
if ~isempty(cwd), cd(cwd); end
if ~isempty(err), rethrow(err); end
