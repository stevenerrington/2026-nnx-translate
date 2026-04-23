% This is an example of how to read editable variables in the userloop
% function. The variable, 'param_file', will be sent to the userloop via
% 'TrialRecord.Editable'.

hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

param_file = 'func1.m';          % parameter function name
editable('-file','param_file');  % make it editable

[~,n] = fileparts(param_file);   % get the filename only
param = eval(n);                 % call the function

dashboard(1,sprintf('Parameter file: %s',param_file));
dashboard(2,sprintf('Probability: %.1f',param.probability));
dashboard(3,sprintf('Probability read in userloop: %.1f',TrialRecord.User.probability));

idle(1000);
set_iti(200);