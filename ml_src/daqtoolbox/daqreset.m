function daqreset()

toolbox_dir = mfilename('fullpath');
toolbox_dir = toolbox_dir(1:find(toolbox_dir==filesep,1,'last'));
system_path = getenv('PATH');
split_path = regexp(system_path,'[^;]+','match');

for extension_dir = {'eyelink','viewpoint','tobii',''}
    target_dir = [toolbox_dir extension_dir{1}];
    if ~exist(target_dir,'dir') || any(strcmpi(split_path,target_dir)), continue, end
    system_path = [target_dir ';' system_path]; %#ok<AGROW>
end
setenv('PATH',system_path);

for workspace = {'caller','base'}
    s = evalin(workspace{1},'whos');
    for m=1:length(s)
        switch s(m).class
            case {'aichannel','analoginput','analogoutput','aochannel','digitalio','dioline','eyetracker','pointingdevice','SerialPort','videocapture','arduino'}
                evalin(workspace{1},['clear(''' s(m).name ''')']);
        end
    end
end

mdqmex(20,4);

end
