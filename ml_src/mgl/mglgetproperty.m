function varargout = mglgetproperty(id,method,varargin)
% property = mglgetproperty(id,method)
%   id: must be a scalar.
%   method: see the following list.
%
% GDI: active, origin, size, angle, scale, edgecolor, facecolor, rect, zorder
%   PIE: startdegree, centerangle
%   POLYGON: vertex
% BITMAP: active, origin, size, angle, rect, zorder
% MOVIE: active, origin, getnextframe, currentposition, angle, looping, size, duration, initframe, getbuffer, info, rect, zorder
% LINE: active, color, linetype, size, zorder
% TEXT: active, origin, fonttype, text, fontsize, fontface, angle, scale, halign, valign, color, bgcolor, size, rect, zorder
% WAVE: active, duration, currentposition, looping, isplaying, frequency, info

varargout{1} = [];
if isempty(id) || isnan(id(1)), return, else, id = double(id(1)); end
if exist('method','var'), method = lower(method); else, method = ''; end

type = mglgettype(id);
switch type{1}
    case 'MOVIE'
        switch method
            case 'getbuffer'
                if 2 < nargin
                    seektime = varargin{1};
                    varargout{1} = permute(mdqmex(7,id,method,seektime),[2 1 3 4]);
                else
                    varargout{1} = permute(mdqmex(7,id,method),[2 1 3 4]);
                end
            otherwise, varargout{1} = mdqmex(7,id,method);
        end
    otherwise
        if 1<nargout
            [varargout{1},varargout{2}] = mdqmex(7,id,method);
        else
            varargout{1} = mdqmex(7,id,method);
        end
end
