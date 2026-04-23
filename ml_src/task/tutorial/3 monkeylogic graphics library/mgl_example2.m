% This is not an NIMH ML task but a MATLAB script to explain how to use MGL
% functions directly.

base_folder = [fileparts(which('monkeylogic')) filesep];
addpath([base_folder 'daqtoolbox']);
addpath([base_folder 'mgl']);

err = [];
try
    max_adapter_count = mglgetadaptercount;
    mglcreatesubjectscreen(max_adapter_count,[0 0 0],[0 0 1024 768],false);
    rect = mglgetadapterrect(1);
    mglcreatecontrolscreen([rect(3)-512 rect(2) rect(3) rect(2)+384]);
    
    crc = mgladdcircle([0 1 0; 1 0 0],[200 100]);
    mglrendergraphic;
    mglpresent;
    pause(1);
    
    % add a box
    % The box is shown behind the circle, since the box is created later
    box = mgladdbox([0 0 1; 1 1 1],[100 200]);
    mglrendergraphic;
    mglpresent;
    pause(1);
    
    % change circle properties
    mglsetproperty(crc,'origin',[200 200],'angle',45,'scale',2);
    mglrendergraphic;
    mglpresent;
    pause(1);
    
    % increase the box size
    mglsetproperty(box,'size',[200 200]);
    mglrendergraphic;
    mglpresent;
    pause(1);
    
    % raise the box
    % The initial z-order is 0 for all graphics. One with a higher z-order
    % is shown above the others.
    mglsetproperty(box,'zorder',1);
    mglrendergraphic;
    mglpresent;
    pause(1);
    
    % turn off the circle
    mglsetproperty(crc,'active',false);
    mglrendergraphic;
    mglpresent;
    pause(1);
    
    % All objects are destroyed anyway when the screens are destroyed
%     mgldestroygraphic([crc box]);

catch err
end

mgldestroycontrolscreen;
mgldestroysubjectscreen;

if ~isempty(err), rethrow(err); end
