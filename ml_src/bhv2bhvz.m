function bhv2bhvz(varargin)
%BHV2BHVZ rewrites NIMH ML data files to BHVZ (*.bhvz).
%
%   bhv2bhvz            % A file dialog will open. Multiple files can be selected
%   bhv2bhvz(filelist)  % filelist is a char (one file) or a cell (multiple file)
%
%   Aug 2, 2020     Written by Jaewon Hwang (jaewon.hwang@nih.gov, jaewon.hwang@hotmail.com)
%   Jan 30, 2021    Rewritten to use convert_format()

convert_format('bhvz',varargin{:});
