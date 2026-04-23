function id = mglsetproperty(id,varargin)
% 'Multiple IDs to different values' is not allowed for the following methods.
% 'Multiple IDs to one value' is still possible.
%
% GDI:
%   POLYGON: vertex
% BITMAP: bitmap
% MOVIE: addframe
% LINE: addpoint
% TEXT: text, fontface, font, halign, valign

if isempty(id), return, end
idx = 1;

try
    while idx < nargin
        method = lower(varargin{idx}); idx = idx+1;
        switch method
            case {'active','looping','collective'}, mdqmex(6,id,method,logical(varargin{idx})); idx = idx+1;
            case {'origin','angle','seek'}, mdqmex(6,id,method,double(varargin{idx})); idx = idx+1;  % seek: in seconds
            case 'scale', val = double(varargin{idx}); if numel(id)==numel(val), val = repmat(val(:),1,2); end, mdqmex(6,id,method,val); idx = idx+1;
            case {'edgecolor','facecolor','color','bgcolor'}
                color = double(varargin{idx});
                if 0~=mod(numel(color),3), error('Color must be [R G B].'); end
                if max(color(:))<=1, color = color*255; end
                mdqmex(6,id,method,color); idx = idx+1;
            case 'zorder'
                if ischar(varargin{idx})
                    switch lower(varargin{idx})
                        case 'front', val = 2147483647;
                        case 'back', val = 0;
                        case 'forward', val = min(2147483647,mdqmex(7,id,method)+1);
                        case 'backward', val = max(0,mdqmex(7,id,method)-1);
                        otherwise, error('Incorrect z-order argument!');
                    end
                else
                    val = max(0,min(2147483647,double(varargin{idx})));
                end
                mdqmex(6,id,method,val); idx = idx+1;
            otherwise
                valid_id = id(~isnan(id)); if isempty(valid_id), return, end
                [type,subtype] = mglgettype(valid_id(1));
                switch type{1}
                    case 'GDI'
                        switch method
                            case 'size', sz = double(varargin{idx}); if 2~=size(sz,2), sz = repmat(sz(:),1,2); end, mdqmex(6,id,method,sz); idx = idx+1;                
                        end
                        switch subtype{1}
                            case 'PIE'
                                switch method
                                    case {'centerangle','startdegree'}, mdqmex(6,id,method,double(varargin{idx})); idx = idx+1;
                                end
                            case 'POLYGON'
                                switch method
                                    case 'vertex', mdqmex(6,id,method,double(varargin{idx}(:,1)),double(1-varargin{idx}(:,2))); idx = idx+1;
                                end
                        end
                    case 'BITMAP'
                        switch method
                            case 'bitmap'
                                bits = varargin{idx}; idx = idx+1;
                                if verLessThan('matlab','9.7'), [sz(1),sz(2),sz(3),sz(4)] = size(bits); else, sz = size(bits,[1 2 3 4]); end
                                if ~any([1 3 4]==sz(3)), error('The first argument doesn''t look like a bitmap or movie.'); end
                                if ~isa(bits,'uint8'), if max(bits(:))<=1, bits = bits*255; end, bits = cast(bits,'uint8'); end
                                if 1==sz(3), bits = repmat(bits,[1 1 3]); sz(3) = 3; end
                                if 3==sz(3), bits(:,:,4,:) = 255; bits = circshift(bits,[0 0 1 0]); end
                                mdqmex(6,id,method,sz([2 1]),flipud(reshape(permute(bits,[3 2 1 4]),4,[])));
                        end
                    case 'MOVIE'
                        switch method
                            case 'setnextframe', mdqmex(6,id,method,double(varargin{idx}-1)); idx = idx+1;  % 0-based
                            case 'addframe'
                                bits = varargin{idx}; idx = idx+1;
                                if verLessThan('matlab','9.7'), [sz(1),sz(2),sz(3),sz(4)] = size(bits); else, sz = size(bits,[1 2 3 4]); end
                                if ~any([1 3 4]==sz(3)), error('The first argument doesn''t look like a bitmap or movie.'); end
                                if ~isa(bits,'uint8'), if max(bits(:))<=1, bits = bits*255; end, bits = cast(bits,'uint8'); end
                                if 1==sz(3), bits = repmat(bits,[1 1 3]); sz(3) = 3; end
                                if 3==sz(3), bits(:,:,4,:) = 255; bits = circshift(bits,[0 0 1 0]); end
                                mdqmex(6,id,method,flipud(reshape(permute(bits,[3 2 1 4]),4,[])));
                            case 'timeperframe', mdqmex(6,id,method,double(varargin{idx})); idx = idx+1;  % in seconds
                            otherwise, mdqmex(6,id,method);  % resetinitframenum, framebyframe, pause, resume
                        end
                    case 'LINE'
                        switch method
                            case 'addpoint', mdqmex(6,id,method,int32(varargin{idx}')); idx = idx+1;
                            case 'clear', mdqmex(6,id,method);
                            case 'linetype', mdqmex(6,id,method,varargin{idx}); idx = idx+1;
                        end
                    case 'TEXT'
                        switch method
                            case {'text','fontface'}, mdqmex(6,id,method,varargin{idx}); idx = idx+1;
                            case 'fontsize', mdqmex(6,id,method,double(varargin{idx})); idx = idx+1;
                            case 'font'
                                if ischar(varargin{idx}), fontface = varargin{idx}; fontsize = varargin{idx+1}; else, fontface = varargin{idx+1}; fontsize = varargin{idx}; end
                                mdqmex(6,id,'fontface',fontface);
                                mdqmex(6,id,'fontsize',double(fontsize)); idx = idx+2;
                            case {'normal','bold','italic','underline','strikeout'}, mdqmex(6,id,method);
                            case 'left',   mdqmex(6,id,'halign',1);
                            case 'center', mdqmex(6,id,'halign',2);
                            case 'right',  mdqmex(6,id,'halign',3);
                            case 'top',    mdqmex(6,id,'valign',1);
                            case 'middle', mdqmex(6,id,'valign',2);
                            case 'bottom', mdqmex(6,id,'valign',3);
                            case {'halign','valign'}
                                switch lower(varargin{idx})
                                    case {1,'left','top'}, mdqmex(6,id,method,1);
                                    case {2,'center','middle'}, mdqmex(6,id,method,2);
                                    case {3,'right','bottom'}, mdqmex(6,id,method,3);
                                end
                                idx = idx+1;
                        end
                end
        end
    end
catch err
    switch err.identifier
        case 'MATLAB:badsubscript', error('mglsetproperty: Method and Arg do not match');
        otherwise, rethrow(err);
    end
end
