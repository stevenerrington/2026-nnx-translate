% add NIMH ML to the MATLAB path
p = [fileparts(which('monkeylogic')) filesep];
addpath(p,[p 'mgl']);

MLConfig = mlconfig;
MLConfig.SubjectScreenDevice = mglgetadaptercount;  % change this to the Subject screen device number

% get subject screen info
create(MLConfig.Screen,MLConfig);
destroy(MLConfig.Screen);

param = [0 20; 180 20; 0 40; 180 40];

for m=1:size(param,1)
    deg = param(m,1);
    coh = param(m,2);

    TrialRecord.CurrentConditionInfo.deg = deg;
    TrialRecord.CurrentConditionInfo.coh = coh;

    [imdata,info] = make_rdm(TrialRecord,MLConfig);

    filename = sprintf('rdm_d%d_c%d.mp4',deg,coh);
    v = VideoWriter(filename,'MPEG-4');
    set(v,'FrameRate',MLConfig.Screen.RefreshRate);
    open(v);
    nframe = size(imdata,4);
    for n=1:nframe
        writeVideo(v,imdata(:,:,:,n));
    end
    close(v);
end
