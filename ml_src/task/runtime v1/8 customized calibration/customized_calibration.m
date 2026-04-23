hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

dashboard(1,'Customized Calibration',[1 0 0]);
dashboard(2,'Users can manipulate or perturb the calibration by adding a custom function.',[0 1 0]);
dashboard(3,'This example makes the eye cursor move only horizontally.');
dashboard(4,'Actual eye signals, not simulated ones, are required.');

intercept = 3;

% For the second eye signal, use Eye2Cal, instead of EyeCal. Likewise, you can
% use JoyCal and Joy2Cal, for the 1st and 2nd joysticks, respectively.
EyeCal.custom_calfunc(@clamp_eyey);  % This replaces the eye calibration function with a user function

toggleobject(1);
idle(10000);

% The rotation of the space is already built in, so you don't need a custom
% function to do it.
%
%   EyeCal.rotate(degree);
%   JoyCal.rotate(degree);
%
% User functions should be placed at the end of the timing script.
%
% A custom calibration function receives a n-by-2 XY matrix and should
% return the same-sized matrix. The values are all in visual degrees.
function xy = clamp_eyey(xy)
    xy(:,2) = intercept;  % Change all y degrees to 3.
end
