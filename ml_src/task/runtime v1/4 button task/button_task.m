button = ML_ButtonsAvailable;
if length(button)<1, error('This task requires at least one button. Please set it up or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');
bhv_code(1,'Button 1',2,'Button 2');  % behavioral codes

dashboard(1,'Press any button.',[1 0 0]);
dashboard(2,'');
dashboard(3,'');

error_type = 0;

[ontarget,rt] = eyejoytrack('acquiretouch',button,[],5000);
if ~ontarget
    error_type = 1;  % no response
else
    dashboard(2,sprintf('Button %d is pushed!',button(ontarget)));
end

if 0==error_type
    ontarget = eyejoytrack('holdtouch',button(ontarget),[],500);
    if ontarget
        dashboard(3,'And held for 500 ms!');
    end
end

set_iti(2000);
