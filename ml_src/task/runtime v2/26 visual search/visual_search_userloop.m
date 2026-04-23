function [C,timingfile,userdefined_trialholder] = visual_search_userloop(MLConfig,TrialRecord) %#ok<*INUSL>

% default return value
C = [];
timingfile = 'visual_search.m';
userdefined_trialholder = '';

persistent ImageList Location Condition

% prepare image list
if isempty(ImageList)
    filelist = dir('*.bmp');              % read image names (A, B, C, D)
    ImageList = {filelist.name}';
    Location = [5 5; -5 5; -5 -5; 5 -5];  % 4 possible target locations
    return                                % return if this is the very first call to userloop
end

nimage = length(ImageList);
nlocation = size(Location,1);
if isempty(Condition)
    % col 1: target image number (1-A, 2-B, 3-C, 4-D)
    % col 2: target image location (1 to 4)
    for image_no=1:nimage
        Condition = [Condition; repmat(image_no,nlocation,1) (1:nlocation)']; %#ok<*AGROW>
    end
    
    Condition = Condition(randperm(size(Condition,1)),:);  % randomize the order
end

% repeat the same condition if the last trial failed
if isempty(TrialRecord.TrialErrors) || 0==TrialRecord.TrialErrors(end)
    % copy the next condition to TrialRecord.User
    TrialRecord.User.cond = Condition(1,:);
    Condition(1,:) = [];
end

% set target and distractors
target_no = TrialRecord.User.cond(1);
target_loc = TrialRecord.User.cond(2);
distractor_no = setdiff(1:nimage,target_no);
ndistractor = length(distractor_no);
distractor_loc = setdiff(1:nlocation,target_loc);
distractor_loc = distractor_loc(1:ndistractor);  % in case there are more locations than the number of images
distractor_loc = distractor_loc(randperm(ndistractor));

% for record keeping
TrialRecord.User.image_no = [target_no distractor_no];  % 1st image is the target
TrialRecord.User.images = ImageList(TrialRecord.User.image_no);
TrialRecord.User.location_no = [target_loc distractor_loc];
TrialRecord.User.location = Location(TrialRecord.User.location_no,:);

% create taskobjects
images = TrialRecord.User.images;
location = TrialRecord.User.location;
C = {'crc(0.2,[1 0 0],1,0,0)', ...       % Taskobject#1: fixation point
    sprintf('pic(%s,0,0)',images{1}) };  % Taskobject#2: cue (= target)
for m=1:length(images)
    C{end+1} = sprintf('pic(%s,%f,%f)',images{m},location(m,:));  % Taskobject#3: target, Taskobject#4-6: distractors
end

end
