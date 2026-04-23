% This is not an NIMH ML task but a MATLAB script to explain how to use MGL
% functions directly.

% add the mgl paths to MATLAB
base_folder = [fileparts(which('monkeylogic')) filesep];
addpath([base_folder 'daqtoolbox']);
addpath([base_folder 'mgl']);

err = [];
try
    % create screens
    max_adapter_count = mglgetadaptercount;
    mglcreatesubjectscreen(max_adapter_count,[0 0 0],[0 0 1024 768],false);
    rect = mglgetadapterrect(1);
    mglcreatecontrolscreen([rect(3)-512 rect(2) rect(3) rect(2)+384]);
    
    % add a circle
    crc = mgladdcircle([0 1 0; 1 0 0],[200 100]);

    % display the circle
    mglrendergraphic;
    mglpresent;
    pause(1);
    
    % destroy the circle
    mgldestroygraphic(crc);  % all created objects must be destroyed
    
catch err
end

% destroy the screens
mgldestroycontrolscreen;
mgldestroysubjectscreen;

if ~isempty(err), rethrow(err); end
