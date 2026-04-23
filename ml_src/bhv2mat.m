function bhv2mat(varargin)
%BHV2MAT rewrites NIMH ML data files to MAT (*.mat).
%
%   bhv2mat            % A file dialog will open. Multiple files can be selected
%   bhv2mat(filelist)  % filelist is a char (one file) or a cell (multiple file)
%
%   Jun 25, 2018    Written by Jaewon Hwang (jaewon.hwang@nih.gov, jaewon.hwang@hotmail.com)
%   Jan 30, 2021    Rewritten to use convert_format()

convert_format('mat',varargin{:});
