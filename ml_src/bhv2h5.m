function bhv2h5(varargin)
%BHV2H5 rewrites NIMH ML data files to HDF5 (*.h5).
%
%   bhv2h5            % A file dialog will open. Multiple files can be selected
%   bhv2h5(filelist)  % filelist is a char (one file) or a cell (multiple file)
%
%   Jan 30, 2021    Written by Jaewon Hwang (jaewon.hwang@nih.gov, jaewon.hwang@hotmail.com)

convert_format('h5',varargin{:});
