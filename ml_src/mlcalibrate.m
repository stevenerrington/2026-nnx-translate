classdef mlcalibrate < handle
%MLCALIBRATE provides following calibration functions
% sig2deg(voltage,offset): convert voltages (n-by-2) to degrees (the center is [0 0])
% deg2pix(deg)           : convert degrees to pixels (the top-left corner is [0 0])
% sig2pix(voltage,offset): concatenation of sig2deg and deg2pix
% pix2deg(pix)           : convert pixels to degrees
%
% subject2deg(xy), subject2pix(xy): convert window coordinates on the subject screen
%                                   to degrees and pixels, respectively
% control2deg(xy), control2pix(xy): convert window coordinates on the control screen
%                                   to degrees and pixels, respectively. Require to call
%                                   update_control_screen_geometry() whenever the zoom level
%                                   of the control screen changes.
%
% translate(offset): move the origin of the transformation matrix
% rotate(theta): rotate the transformation space.
%
%   Mar 12, 2017    Written by Jaewon Hwang (jaewon.hwang@nih.gov, jaewon.hwang@hotmail.com)

    properties (SetAccess = protected)
        sig2deg
    end
    properties (SetAccess = protected, Hidden)
        tform           % Transform Matrix: cell(1,3)
        calmethod       % Calibration Method: 1-3
        ppd             % PixelsPerDegree
        ssrc            % SubjectScreenRect
        ssfull          % SubjectScreenFullSize
        sshalf          % SubjectScreenHalfSize
        aspectratio     % SubjectScreenAspectRatio
        cspos           % ControlScreenPosition
        c2s_ratio       % Control2SubjectRatio
        rotation_t      % transpose of rotation matrix
        rotation_rev_t
        calfun
        deg2deg
        deg2sig
    end

    methods (Access = protected)
        function xy = raw_signal(obj,xy,offset)  % Calibration method 1: Raw signal
            m = size(xy,1); t = obj.tform{1}; xy = (xy - repmat(t.offset + offset,m,1)) * obj.rotation_t;
        end
        function xy = raw_signal_rev(obj,xy)
            m = size(xy,1); t = obj.tform{1}; xy = xy * obj.rotation_rev_t + repmat(t.offset,m,1);
        end
        function xy = origin_gain(obj,xy,offset)  % Calibration method 2: Origin-Gain
            m = size(xy,1); t = obj.tform{2}; xy = (xy - repmat(t.origin + offset*t.rotation_rev_t./t.gain,m,1)) .* repmat(t.gain,m,1) * (t.rotation_t * obj.rotation_t);
        end
        function xy = origin_gain_rev(obj,xy)
            m = size(xy,1); t = obj.tform{2}; xy = xy * (t.rotation_rev_t * obj.rotation_rev_t) ./ repmat(t.gain,m,1) + repmat(t.origin,m,1);
        end
        function xy = spatial_transform(obj,xy,offset)  % Calibration method 3: 2-D Spatial Transformation
            m = size(xy,1); t = obj.tform{3}.T.(obj.tform{3}.type); xy = (t.forward_fcn(t,xy) - repmat(offset,m,1)) * obj.rotation_t;
        end
        function xy = spatial_transform_rev(obj,xy)
            m = size(xy,1); t = obj.tform{3}.T.(obj.tform{3}.type); xy = t.inverse_fcn(t,xy * obj.rotation_rev_t);
        end
        function xy = custom_transform(obj,xy,offset)
            xy = obj.deg2deg(obj.calfun(xy,offset));
        end
    end        
    
    methods
        function obj = mlcalibrate(sig_type,MLConfig,devnum)
            if ~exist('devnum','var'), devnum = 1; end
            switch sig_type
                case {1,'eye'}
                    obj.tform = MLConfig.EyeTransform(devnum,:);
                    obj.calmethod = MLConfig.EyeCalibration(devnum);
                case {2,'joy'}
                    obj.tform = MLConfig.JoystickTransform(devnum,:);
                    obj.calmethod = MLConfig.JoystickCalibration(devnum);
            end
            if ~isfield(obj.tform{1},'offset'), obj.tform{1}.offset = [0 0]; end
            if ~isfield(obj.tform{2},'rotation'), obj.tform{2}.rotation = 0; end
            if ~isfield(obj.tform{2},'rotation_t'), obj.tform{2}.rotation_t = eye(2); end
            if ~isfield(obj.tform{2},'rotation_rev_t'), obj.tform{2}.rotation_rev_t = eye(2); end
            obj.tform{3} = geometric_transform('init',obj.tform{3});

            obj.ppd = MLConfig.PixelsPerDegree;
            obj.ssrc = MLConfig.Screen.SubjectScreenRect;
            obj.ssfull = MLConfig.Screen.SubjectScreenFullSize;
            obj.sshalf = MLConfig.Screen.SubjectScreenHalfSize;
            obj.aspectratio = MLConfig.Screen.SubjectScreenAspectRatio;
            obj.update_controlscreen_geometry();
            rotate(obj,0);

            switch obj.calmethod
                case 1, obj.calfun = @obj.raw_signal;        obj.deg2sig = @obj.raw_signal_rev;
                case 2, obj.calfun = @obj.origin_gain;       obj.deg2sig = @obj.origin_gain_rev;
                case 3, obj.calfun = @obj.spatial_transform; obj.deg2sig = @obj.spatial_transform_rev;
            end
            obj.sig2deg = obj.calfun;
        end
        function rc = update_controlscreen_geometry(obj)
            if ~mglcontrolscreenexists(), rc = []; return, end
            info = mglgetscreeninfo(2);
            rc = info.Rect;
            obj.cspos = rc;
            sz = rc(3:4) - rc(1:2);
            zoom = info.Zoom;
            if sz(1) < obj.aspectratio * sz(2)
                obj.cspos(3) = sz(1) * zoom;
                obj.cspos(4) = sz(1) * zoom / obj.aspectratio;
            else
                obj.cspos(3) = sz(2) * zoom * obj.aspectratio;
                obj.cspos(4) = sz(2) * zoom;
            end
            obj.cspos(1:2) = obj.cspos(1:2) + (sz-obj.cspos(3:4)) / 2;
            obj.c2s_ratio = obj.ssfull ./ obj.cspos(3:4);
        end            
        
        function xy = deg2pix(obj,xy)
            [m,n] = size(xy); n = n/2; xy = xy .* repmat(obj.ppd,m,n) + repmat(obj.sshalf,m,n);
        end
        function xy = sig2pix(obj,xy,offset)
            xy = obj.deg2pix(obj.sig2deg(xy,offset));
        end
        function xy = pix2deg(obj,xy)
            [m,n] = size(xy); n = n/2; xy = (xy - repmat(obj.sshalf,m,n)) ./ repmat(obj.ppd,m,n);
        end
        function xy = pix2subject(obj,xy)
            [m,n] = size(xy); n = n/2; xy = xy + repmat(obj.ssrc(1:2),m,n);
        end
        function xy = pix2control(obj,xy)
            [m,n] = size(xy); n = n/2; xy = xy ./ repmat(obj.c2s_ratio,m,n) + repmat(obj.cspos(1:2),m,n);
        end
        function xy = subject2deg(obj,xy)
            [m,n] = size(xy); n = n/2; xy = (xy - repmat(obj.ssrc(1:2) + obj.sshalf,m,n)) ./ repmat(obj.ppd,m,n);
        end
        function xy = subject2pix(obj,xy)
            [m,n] = size(xy); n = n/2; xy = xy - repmat(obj.ssrc(1:2),m,n);
        end
        function xy = control2deg(obj,xy)
            [m,n] = size(xy); n = n/2; xy = (xy - repmat(obj.cspos(1:2) + obj.sshalf ./ obj.c2s_ratio,m,n)) .* repmat(obj.c2s_ratio ./ obj.ppd,m,n);
        end
        function xy = control2pix(obj,xy)
            [m,n] = size(xy); n = n/2; xy = (xy - repmat(obj.cspos(1:2),m,n)) .* repmat(obj.c2s_ratio,m,n);
        end
        function xy = norm2deg(obj,xy)
            xy = obj.pix2deg(obj.norm2pix(xy));
        end
        function xy = norm2pix(obj,xy)
            [m,n] = size(xy); n = n/2; xy = xy.* repmat(obj.ssfull,m,n);
        end
        function xy = norm2size(obj,xy)
            xy = obj.norm2pix(xy) ./ obj.ppd(1);
        end
        
        function tform = translate(obj,offset)
            if any(offset)
                switch obj.calmethod
                    case 1
                        obj.tform{1}.offset = obj.tform{1}.offset + offset; 
                    case 2
                        obj.tform{2}.origin = obj.tform{2}.origin + offset*obj.tform{2}.rotation_rev_t./obj.tform{2}.gain;
                    case 3
                        t = obj.tform{3}.T.(obj.tform{3}.type);
                        offset_in_volts = t.inverse_fcn(t,offset) - t.inverse_fcn(t,[0 0]);
                        obj.tform{3}.moving_point = obj.tform{3}.moving_point + repmat(offset_in_volts,size(obj.tform{3}.moving_point,1),1);
                        obj.tform{3}.T.(obj.tform{3}.type) = geometric_transform('calc',obj.tform{3}.type,obj.tform{3}.moving_point,obj.tform{3}.fixed_point);
                end
            end
            tform = obj.tform{obj.calmethod};
        end
        function rotate(obj,theta)
            obj.rotation_t = [cosd(theta) -sind(theta); sind(theta) cosd(theta)]';
            obj.rotation_rev_t = [cosd(-theta) -sind(-theta); sind(-theta) cosd(-theta)]';
        end
        function custom_calfunc(obj,val)
            if isa(val,'function_handle'), obj.deg2deg = val; obj.sig2deg = @obj.custom_transform; else, obj.sig2deg = obj.calfun; end
        end
    end
    
    methods (Hidden)
        function tform = get_transform_matrix(obj), tform = obj.tform{obj.calmethod}; end
        function set_transform_matrix(obj,tform), obj.tform{obj.calmethod} = tform; end
    end
end
