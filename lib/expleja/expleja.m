function [expAv,errest, info, c, m, extreigs, mu, gamma2] = ...
         expleja (h, A, v, varargin)
% Function file: [PHIKAV, ERREST, INFO, C, M, EXTREIGS, MU, GAMMA2] = ...
%                 EXPLEJA (H, A, V, TOL, P, PARAMIN, EXTREIGS)
%
% Description: Matrix exponential times vector or matrix.
%
%   Compute EXPM(H * A) * V without forming EXP(H*A). A is a matrix
%   *preferably* sparse.
%   V is a vector or a matrix.
%       If length (TOL) == 1, then TOL is the absolute tolerance. If
%   length (TOL) == 2, then TOL(1) is the absolute tolerance and TOL(2)
%   the tolerance relative to the current approximation of EXPM(H * A)*V.
%   If length (TOL) == 3, then TOL(3) specifies the norm, by default this
%   is INF. If length (TOL) == 4, then TOL(4) specifies the operator norm,
%   by default this is INF. If nothing is provided TOL = [0, 2^(-53), INF,
%   INF].
%       By P one can specify the maximal power of A that is used for the
%   hump reduction procedure. The default is P=5.
%   The parameter PARAMIN can be generated by the function
%   SELECT_INTERP_PARA as its first output parameter. This allows for a
%   computation of the 'essential' interpolation parameters for the
%   interpolation in case the matrix stays constant.
%       If EXTREIGS is not given, the spectrum of A is estimated by
%   Gershgorin's disks theorem. Otherwise, it is estimated by EXTREIGS.SR
%   (smaller real part of the eigenvalues), EXTREIGS.LR (largest real
%   part), EXTREIGS.LI (largest imaginary part) and EXTREIGS.SI (smallest
%   imaginary part).
%       On output, sum (INFO) is the total number of iterations
%   (== matrix-vector products) and ERREST(j) the estimated error in step j
%   (in the specified norm). C are the auxillary matrix vector products
%   needed for the norm estimates, M is the selected degree of
%   interpolation, EXTREIGS is like above. MU the used shift and GAMMA2
%   corresponds to the selected interpolation interval.
%
%   The code is based on PHILEJA provided by Marco Caliari.
%   Reference: M. Caliari, P. Kandolf, A. Ostermann and S. Rainer,
%   The Leja method revisited: backward error analysis for the matrix
%   exponential, submitted, http://arxiv.org/abs/1506.08665
%
%   Peter Kandolf, July 8, 2015, cooperation with Marco Caliari,
%   Alexander Ostermann and Stefan Rainer
%   Additional notes:
%   - The error is estimated during the newton interpolation, which is
%   performed until
%        ||errorestimate||_TOL(3) > max(TOL(1),TOL(2)*||Y||_TOL(3))
%   is satisfied.
%
%   Minimal example:
%       A=diag([-10:0])+diag(ones(1,10),1);
%       v=ones(11,1); h=1;
%       y=expleja(h,A,v);
%
% This file is part of the expleja project.
% Authors: Marco Caliari and Peter Kandolf
% Date: September 23, 2016

  %% check consistency of matrix and vector sizes
  n = size (v,1);
  if (n ~= size (A, 2)) size (v), size (A),
    error ('Inconsistent matrix and vector sizes')
  end
  %% Check if tolerance is given and set to default otherwise
  if (nargin >= 4 && ~isempty (varargin{1}))
    tol = varargin{1};
    if (length (tol) == 1), tol(2) = 0; tol(3) = Inf; tol(4) = 2;
    elseif (length (tol) == 2), tol(3) = Inf; tol(4) = 2;
    elseif (length (tol) == 3), tol(4) = 2;
    end
  else % default value
    tol = [0, 2^(-53), inf, inf];
  end
  %% maximal p for hump test
  if (nargin >= 5 && ~isempty (varargin{2}))
    p = varargin{2};
  else
    p = 5;
  end
  %% get interpolation parameters
  if (nargin >= 6 && ~isempty (varargin{3}))
    param = varargin{3};
    A = A - param.mu * speye (n, n);
    c = 0;
  else
    %% get spectral estimate
    if (nargin >= 7 && ~isempty (varargin{4}))
      extreigs = varargin{4};
    else
      extreigs = gersh (A);
    end
    %% h and/or A are zero - computation is finished
    if ((h * (abs (extreigs.SR) + abs (extreigs.LR) + ...
            abs (extreigs.LI) + abs (extreigs.SI)) == 0) || ...
        norm (v, tol(3)) == 0)
      expAv = v; errest = 0; info = 0; c = 0; m = 0; extreigs = [];
      mu = 0; gamma2 = 0; return
    end
    %% Compute parameters for the interpolation
    [param, A] = ...
    select_interp_para (h, A, extreigs, tol, 100, p, 1);
    c = param.c;
  end
  m = param.m; mu = param.mu; gamma2 = param.gamma2;
  nsteps = param.nsteps;
  expAv = v; errest = zeros (nsteps, 1); info = zeros (nsteps, 1);
  %% scaling parameter per step
  eta = exp (mu * h / nsteps);
  for j = 1:nsteps
    [pexpAv, perrest, pinfo] = param.newt (max(h) / nsteps, A, expAv, ...
                                          param.xi, param.dd, ...
                                          tol(1) / nsteps, ...
                                          tol(2) / nsteps, tol(3));
    errest(j) = perrest; info(j) = pinfo;
    expAv = pexpAv * eta;
  end
end
%!test
%! A = 2 * rand(10) - 1 + 1i * (2 * rand(10) - 1);
%! v = 2 * rand(10,1) - 1 + 1i * (2 * rand(10,1) - 1);
%! h = rand;
%! assert(expleja(h,A,v),expm(h*A)*v,-1e-12)
%!test
%! A = eye(10);
%! v = 2 * rand(10,1) - 1 + 1i * (2 * rand(10,1) - 1);
%! h = rand;
%! assert(expleja(h,A,v),expm(h*A)*v,-4*eps)
%!test
%! A = 10 * eye(10);
%! v = 2 * rand(10,1) - 1 + 1i * (2 * rand(10,1) - 1);
%! h = rand;
%! assert(expleja(h,A,v),expm(h*A)*v,-1e-14)
%!test % newtons
%! m = 10;
%! A = toeplitz (sparse (1, 2, -1, 1, m),sparse (1, 2, 1, 1, m));
%! v = ones (m, 1);
%! h = 1;
%! assert(expleja(h,A,v),expm(h*A)*v,-1e-14)
%!test % newton
%! m = 10;
%! A = toeplitz (sparse ([1, 1], [1, 2], [-2, 1], 1, m));
%! v = ones (10, 1);
%! h = 1;
%! assert(expleja(h,A,v),expm(h*A)*v,-1e-14)
%!test
%! m = 51;
%! A = toeplitz (sparse ([1, 1], [1, 2], [-2, 1] * m ^ 2, 1, m));
%! v = ones (m, 1);
%! h = 0.1;
%! assert(expleja(h,A,v,[eps,eps,2]),expm(h*A)*v,-4e-13)
%!demo
%! fprintf('1) Normal functionality of EXPLEJA:\n');
%! n = 10;
%! A = -gallery ('poisson', n);
%! v = linspace (-1, 1, n ^ 2)';
%! t = 1;
%! y = expleja (t, A ,v);
%! fprintf('\tRelative differences between EXPM and EXPLEJA.\n')
%! fprintf('\tShould be of order %9.2e and has error %9.2e\n', eps / 2, ...
%!         norm (y - expm( t * A ) * v, 1) / norm (y, 1))
%!demo
%! fprintf('2) With multiple vectors v\n');
%! n = 10;
%! A = -gallery ('poisson', n);
%! v = linspace (-1, 1, n ^ 2)';
%! v1 = exp (-10 * v .^ 2);
%! t = 1;
%! y = expleja (t, A, [v, v1]);
%! fprintf('\tRelative differences between EXPM and EXPLEJA.\n')
%! fprintf('\tShould be of order %9.2e and has error %9.2e\n', eps / 2, ...
%!         norm (y - expm (t * A) * [v, v1], 1) / norm (y, 1))
%!demo
%! fprintf('3) Precompute the interpolation parameters\n');
%! n = 10;
%! A = -gallery ('poisson', n);
%! v = linspace (-1, 1, n ^ 2)';
%! t = 1;
%! y1 = v;
%! mult = 10;
%! tic
%! for i = 1:mult
%!   y1 = expleja (t, A, y1);
%! end
%! time0 = toc;
%! % Standard configuration for expleja and param
%! extreigs = gersh (A);     % Gerschgorin estimates
%! tol = [0, 2 ^ -53, 1, 1]; % tolerance
%! p = 5;                    % maximal order of hump reduction
%! max_points = 100;         % maximal number of interpolation points
%! shift = 1;                % allow a matrix shift
%! tic
%! [param, ~] = select_interp_para (t, A, extreigs, tol, max_points, p, shift);
%! time1 = toc;
%! y2=v;
%! tic
%! for i = 1:mult
%!   y2 = expleja (t, A, y2, tol, p, param);
%! end
%! time2 = toc;
%! fprintf('\tTiming comparison in seconds with constant stepsize.\n')
%! fprintf('\tTime for %d steps w/o precomputing %9.2e\n', mult, time0)
%! fprintf('\tTime for %d steps with precomputing %9.2e\n', mult, time2)
%! fprintf('\tTime for the precomputing stage %9.2e\n', time1)
%! fprintf('\tTotal speed-up %9.2e\n', time0/(time1+time2))
%!demo
%! fprintf('4) Simulate integrator with variable time step size\n');
%! A = -10 * gallery ('triw', 20, 4);
%! v = ones (length (A), 1);
%! t = 1;
%! y1 = v;
%! T = [1,1.25,1.1,1.5,1,1,1.25,1.1,1.5,1,1,1.25,1.1,1.5,1,1,1.25,1.1,1.5,1];
%! tic
%! for t = T
%!   y1 = expleja (t, A, y1);
%! end
%! time1 = toc;
%! % Standard configuration for expleja and param
%! extreigs = gersh (A);     % Gerschgorin estimates
%! tol = [0, 2 ^ -53, 1, 1]; % tolerance
%! p = 5;                    % maximal order of hump reduction
%! max_points = 100;         % maximal number of interpolation points
%! shift = 1;                % allow a matrix shift
%! y2 = v;
%! tic
%! [param, ~] = select_interp_para(T(1), A, extreigs, tol, max_points, p,...
%!                                shift);
%! y2 = expleja (T(1), A, y2, tol, p, param);
%! shift = 0; % Do not reshift A in the param update
%!            % (ATTENTION keep p constant)
%! for t = T(2:end)
%!   [param, ~] = select_interp_para (t, A, extreigs, tol, max_points, p,...
%!                                    shift,param);
%!   y2 = expleja (t, A, y2, tol, p, param);
%! end
%! time2 = toc;
%! fprintf('\tTiming comparison in seconds with variable stepsize.\n')
%! fprintf('\tTime for multiple steps w/o precomputing %9.2e and error %9.2e\n',time1, norm(y1-expm(sum(T)*A)*v,1)/norm(y1,1))
%! fprintf('\tTime for multiple steps with precomputing %9.2e and error %9.2e\n',time2, norm(y2-expm(sum(T)*A)*v,1)/norm(y2,1))
%! fprintf('\tTotal speed-up %9.2e\n',time1/time2)
