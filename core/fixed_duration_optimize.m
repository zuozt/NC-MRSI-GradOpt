function G = fixed_duration_optimize(ktraj_target, opts)
%FIXED_DURATION_OPTIMIZE Fixed-readout constrained gradient optimization.
%
% The optimizer uses a control-point grid if the gradient raster contains too
% many samples. The optimized gradient is then linearly interpolated to the
% scanner gradient raster and validated by numerical integration.

Ngrad = size(ktraj_target, 1);
Nctrl = min(Ngrad, opts.maxControlPoints);
if Nctrl < 4
    error('At least 4 control points are required.');
end

if Nctrl < Ngrad
    uGrad = linspace(0, 1, Ngrad).';
    uCtrl = linspace(0, 1, Nctrl).';
    kCtrl = zeros(Nctrl, size(ktraj_target,2));
    for d = 1:size(ktraj_target,2)
        kCtrl(:,d) = interp1(uGrad, ktraj_target(:,d), uCtrl, 'linear', 'extrap');
    end
    optsCtrl = opts;
    optsCtrl.dtGrad = opts.readoutTime / (Nctrl - 1);
    Gctrl = solve_fixed_qp_on_grid(kCtrl, optsCtrl);
    G = zeros(Ngrad, size(ktraj_target,2));
    for d = 1:size(ktraj_target,2)
        G(:,d) = interp1(uCtrl, Gctrl(:,d), uGrad, 'linear', 'extrap');
    end
else
    G = solve_fixed_qp_on_grid(ktraj_target, opts);
end
end

function G = solve_fixed_qp_on_grid(ktraj_target, opts)
N = size(ktraj_target, 1);
Ddim = size(ktraj_target, 2);
G = zeros(N, Ddim);

A = build_integration_matrix(N, opts.gammaBar, opts.dtGrad);
D1 = diff(eye(N), 1, 1);
D2 = diff(eye(N), 2, 1);

Hbase = A' * A + opts.lambdaSlew * (D1' * D1) + opts.lambdaSmooth * (D2' * D2);
H = 2 * (Hbase + 1e-18 * eye(N));

lb = -opts.Guse * ones(N, 1);
ub =  opts.Guse * ones(N, 1);
Aineq = [D1; -D1];
bineq = opts.Suse * opts.dtGrad * ones(2*(N-1), 1);

[Aeq, beq] = build_boundary_constraints(N, opts);

useQuadprog = exist('quadprog', 'file') == 2;
if useQuadprog
    qopt = optimoptions('quadprog', 'Display', opts.optimizerDisplay, ...
        'Algorithm', 'interior-point-convex');
end

for d = 1:Ddim
    k0 = ktraj_target(1,d);
    y = ktraj_target(:,d) - k0;
    f = -2 * A' * y;

    if useQuadprog
        [gd,~,exitflag] = quadprog(H, f, Aineq, bineq, Aeq, beq, lb, ub, [], qopt);
        if exitflag <= 0 || isempty(gd)
            warning('quadprog failed for dimension %d. Falling back to projected least squares.', d);
            gd = fallback_projected_solution(H, f, opts, lb, ub, Aeq, beq);
        end
    else
        warning('quadprog not found. Using projected fallback for dimension %d.', d);
        gd = fallback_projected_solution(H, f, opts, lb, ub, Aeq, beq);
    end
    G(:,d) = gd;
end
end

function [Aeq, beq] = build_boundary_constraints(N, opts)
rows = [];
vals = [];
if opts.forceGStartZero
    r = zeros(1,N); r(1) = 1; rows = [rows; r]; vals = [vals; 0]; %#ok<AGROW>
end
if opts.forceGEndZero
    r = zeros(1,N); r(end) = 1; rows = [rows; r]; vals = [vals; 0]; %#ok<AGROW>
end
Aeq = rows;
beq = vals;
end

function x = fallback_projected_solution(H, f, opts, lb, ub, Aeq, beq)
% Simple fallback: unconstrained solution followed by bound/slew projection.
% This is not a replacement for quadprog, but keeps the toolbox runnable.
x = -H \ f;
x = max(min(x, ub), lb);

if ~isempty(Aeq)
    x = apply_boundary(x, Aeq, beq);
end
limit = opts.Suse * opts.dtGrad;
for it = 1:opts.fallbackIterations
    x = max(min(x, ub), lb);
    x = clamp_slew_forward_backward(x, limit);
    if ~isempty(Aeq)
        x = apply_boundary(x, Aeq, beq);
    end
end
end

function x = apply_boundary(x, Aeq, beq)
for i = 1:size(Aeq,1)
    idx = find(abs(Aeq(i,:)) > 0, 1, 'first');
    if ~isempty(idx)
        x(idx) = beq(i) / Aeq(i,idx);
    end
end
end

function x = clamp_slew_forward_backward(x, limit)
for i = 2:numel(x)
    dx = x(i) - x(i-1);
    if abs(dx) > limit
        x(i) = x(i-1) + sign(dx) * limit;
    end
end
for i = numel(x)-1:-1:1
    dx = x(i) - x(i+1);
    if abs(dx) > limit
        x(i) = x(i+1) + sign(dx) * limit;
    end
end
end
