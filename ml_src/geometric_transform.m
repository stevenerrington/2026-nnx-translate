function varargout = geometric_transform(cmd,varargin)
    switch cmd
        case 'init'
            tform = varargin{1};
            varargout{1} = init_tform(tform);
        case 'calc'
            type = varargin{1}; row = ~isnan(varargin{2}(:,1)); moving = varargin{2}(row,:); fixed = varargin{3}(row,:);
            switch type
                case 'projective', varargout{1} = calculate_projective_transform(moving,fixed);
                case 'polynomial3', varargout{1} = calculate_polynomial_transform(moving,fixed,3);
                otherwise, varargout{1} = calculate_polynomial_transform(moving,fixed,4);
            end
        otherwise
            error('geometric_transform:UnknownCmd','Unknown command!!!');
    end
end

function tform = init_tform(tform)
    [x,y] = meshgrid(-10:10,-10:10);
    x = x(:); y = y(:);
    moving0 = [x y]; fixed0 = [x y];
    
    if ~isfield(tform,'type'), tform.type = 'projective'; end
    if ~isfield(tform,'moving_point') || ~isfield(tform,'fixed_point')
        moving = moving0; fixed = fixed0; 
    else
        row = ~isnan(tform.moving_point(:,1)); moving = tform.moving_point(row,:); fixed = tform.fixed_point(row,:);
    end

    % projective transform
    try
        tform.T.projective = calculate_projective_transform(moving,fixed);
    catch
        tform.T.projective = calculate_projective_transform(moving0,fixed0);
    end

    % polynomial transforms
    for m={'polynomial3','polynomial4'}
        degree = str2double(m{1}(end));
        try
            tform.T.(m{1}) = calculate_polynomial_transform(moving,fixed,degree);
        catch
            tform.T.(m{1}) = calculate_polynomial_transform(moving0,fixed0,degree);
        end
    end
end

% projective transformation
% https://homepages.inf.ed.ac.uk/rbf/CVonline/LOCAL_COPIES/BEARDSLEY/node3.html
function tform = calculate_projective_transform(p,q)
    m = size(p,1);
    z = zeros(m,1);
    o = ones(m,1);
    p1 = p(:,1);
    p2 = p(:,2);
    q1 = q(:,1);
    q2 = q(:,2);

    M = [p1 p2 o z z z -p1.*q1 -p2.*q1; z z z p1 p2 o -p1.*q2 -p2.*q2];
    if rank(M)<8, error('MATLAB:rankDeficientMatrix','At least 4 non-collinear points needed to infer projective transform.'); end
    T = reshape([M \ [q1; q2]; 1],3,3);
    
    tform.ndims_in = 2;
    tform.ndims_out = 2;
    tform.forward_fcn = @fwd_projective;
    tform.inverse_fcn = @inv_projective;
    tform.tdata.T = T;
    tform.tdata.Tinv = inv(T);
end
function q = fwd_projective(obj,p)
    q = [p ones(size(p,1),1)] * obj.tdata.T;
    q = q(:,1:2) ./ repmat(q(:,3),1,2);
end
function p = inv_projective(obj,q)
    p = [q ones(size(q,1),1)] * obj.tdata.Tinv;
    p = p(:,1:2) ./ repmat(p(:,3),1,2);
end

% polynomial transform
% http://air.bmap.ucla.edu/AIR5/2Dnonlinear.html
function tform = calculate_polynomial_transform(moving,fixed,degree)
    warning('off'); lastwarn('');
    F = build_polynomial(moving,degree); tform.fwd_mat = [F\fixed(:,1) F\fixed(:,2)];
    I = build_polynomial(fixed,degree);  tform.inv_mat = [I\moving(:,1) I\moving(:,2)];
    warning('on');
    [~,msgid] = lastwarn; np = fi(3==degree,10,15);
    if size(fixed,1)<np || any(strcmp(msgid,{'MATLAB:rankDeficientMatrix','MATLAB:nearlySingularMatrix'}))
        error('MATLAB:rankDeficientMatrix','At least %d non-collinear points needed to infer polynomial transform.',np);
    end

    tform.degree = degree;
    tform.forward_fcn = @fwd_polynomial;
    tform.inverse_fcn = @inv_polynomial;
end
function uv = fwd_polynomial(obj,xy)
    uv = build_polynomial(xy,obj.degree) * obj.fwd_mat;
end
function xy = inv_polynomial(obj,uv)
    xy = build_polynomial(uv,obj.degree) * obj.inv_mat;
end
function X = build_polynomial(xy,degree)
    n = size(xy,1); x = xy(:,1); y = xy(:,2);
    switch degree
        case 3, X = [ones(n,1) x y x.^2 x.*y y.^2 x.^3 (x.^2).*y (y.^2).*x y.^3];
        case 4, X = [ones(n,1) x y x.^2 x.*y y.^2 x.^3 (x.^2).*y (y.^2).*x y.^3 x.^4 (x.^3).*y (x.^2).*(y.^2) (y.^3).*x y.^4];
    end
end

function op = fi(tf,op1,op2), if tf, op = op1; else, op = op2; end, end
