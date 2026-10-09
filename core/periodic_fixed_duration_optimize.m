function G = periodic_fixed_duration_optimize(ktraj_target, opts)
%PERIODIC_FIXED_DURATION_OPTIMIZE Optimize ONE compact periodic gradient.
%
% This solver is for periodic MRSI. It optimizes only one compact period of
% length Npp. The full MRSI readout should be produced by repeating the
% resulting G period Nspec times.
%
% Discrete periodic model:
%   k(1)      = k0
%   k(i)      = k0 + gamma*dt*sum_{j=1}^{i-1} G(j), i=2..Npp
%   k_next(1) = k(Npp) + gamma*dt*G(Npp)
%
% Periodicity is enforced by:
%   sum_j G(j) = 0       -> k_next(1) = k(1)
%   optionally G(Npp)=G(1) for gradient-amplitude continuity across repeat
%   optionally dG/dt(Npp)=dG/dt(1) for slew-continuity across repeat
%   cyclic slew limits include G(1)-G(Npp).
%
% Constraints are axis-wise. Vector-norm constraints can be added later.

N = size(ktraj_target, 1);
Ddim = size(ktraj_target, 2);
if N < 4
    error('Periodic optimization requires Npp >= 4.');
end

% Direct cyclic finite-difference gradient exactly reproduces one compact
% periodic target when it satisfies hardware limits.  This is the correct
% baseline for periodic MRSI: G(i) maps k(i) -> k(i+1), and G(N) maps
% k(N) -> k(1) of the next spectral period.
Gdirect = periodic_direct_gradient(ktraj_target, opts);
if isfield(opts,'lambdaSlew') && isfield(opts,'lambdaSmooth') && ...
        opts.lambdaSlew == 0 && opts.lambdaSmooth == 0 && ...
        periodic_direct_is_feasible(Gdirect, opts)
    G = Gdirect;
    return;
end

% Periodic solver should not reduce to control points by default because the
% cyclic equality/slew constraints are defined on the physical samples.
G = zeros(N, Ddim);

A = build_periodic_integration_matrix(N, opts.gammaBar, opts.dtGrad);
Dcyc = build_cyclic_diff_matrix(N);
D2cyc = Dcyc * Dcyc;

Hbase = A' * A + opts.lambdaSlew * (Dcyc' * Dcyc) + opts.lambdaSmooth * (D2cyc' * D2cyc);
H = 2 * (Hbase + 1e-18 * eye(N));

lb = -opts.Guse * ones(N, 1);
ub =  opts.Guse * ones(N, 1);

% Cyclic slew: includes transition from last point of one period to first
% point of the next repeated period.
Aineq = [Dcyc; -Dcyc];
bineq = opts.Suse * opts.dtGrad * ones(2*N, 1);

[Aeq, beq] = build_periodic_equalities(N, opts);

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
            warning('periodic quadprog failed for dimension %d. Using cyclic projected fallback.', d);
            gd = periodic_fallback_solution(ktraj_target(:,d), opts, lb, ub, Aeq, beq);
        end
    else
        warning('quadprog not found. Using cyclic projected fallback for dimension %d.', d);
        gd = periodic_fallback_solution(ktraj_target(:,d), opts, lb, ub, Aeq, beq);
    end
    G(:,d) = gd;
end
end


function G = periodic_direct_gradient(ktraj, opts)
N = size(ktraj,1);
D = size(ktraj,2);
G = zeros(N,D);
if N < 2
    return;
end
G(1:N-1,:) = diff(ktraj,1,1) ./ (opts.gammaBar * opts.dtGrad);
G(N,:) = (ktraj(1,:) - ktraj(N,:)) ./ (opts.gammaBar * opts.dtGrad);
end

function ok = periodic_direct_is_feasible(G, opts)
if isempty(G)
    ok = false;
    return;
end
Gaxis = max(abs(G), [], 1);
dG = [diff(G,1,1); G(1,:) - G(end,:)];
Saxis = max(abs(dG ./ opts.dtGrad), [], 1);
okG = all(Gaxis <= opts.Guse * (1 + 1e-12));
okS = all(Saxis <= opts.Suse * (1 + 1e-12));
% Honor optional user-requested equalities.  For PETALUTE these should be off.
okEq = true;
if isfield(opts,'forceGStartZero') && opts.forceGStartZero
    okEq = okEq && norm(G(1,:)) < 1e-12;
end
if isfield(opts,'forceGEndZero') && opts.forceGEndZero
    okEq = okEq && norm(G(end,:)) < 1e-12;
end
if isfield(opts,'forceGPeriodicEqual') && opts.forceGPeriodicEqual
    okEq = okEq && norm(G(1,:) - G(end,:)) < 1e-12;
end
if isfield(opts,'forceSlewPeriodicEqual') && opts.forceSlewPeriodicEqual && size(G,1) >= 4
    okEq = okEq && norm((G(2,:) - G(1,:)) - (G(end,:) - G(end-1,:))) < 1e-12;
end
ok = okG && okS && okEq;
end

function A = build_periodic_integration_matrix(N, gammaBar, dt)
% Maps G(1:N) to sampled k(1:N) relative to k0. The Nth gradient sample
% closes the period and is not included in k(1:N); it is constrained via
% zero moment.
A = tril(ones(N,N), -1) * gammaBar * dt;
end

function D = build_cyclic_diff_matrix(N)
D = zeros(N,N);
for i = 1:N-1
    D(i,i) = -1;
    D(i,i+1) = 1;
end
D(N,N) = -1;
D(N,1) = 1;
end

function [Aeq, beq] = build_periodic_equalities(N, opts)
Aeq = [];
beq = [];

% Periodic k closure: total zeroth gradient moment in one period is zero.
Aeq = [Aeq; ones(1,N)];
beq = [beq; 0];

% Optional non-periodic-style zero boundary constraints. These are usually
% off for periodic MRSI unless an explicit ramp-in/ramp-out block is used.
if isfield(opts,'forceGStartZero') && opts.forceGStartZero
    r = zeros(1,N); r(1) = 1;
    Aeq = [Aeq; r]; beq = [beq; 0];
end
if isfield(opts,'forceGEndZero') && opts.forceGEndZero
    r = zeros(1,N); r(end) = 1;
    Aeq = [Aeq; r]; beq = [beq; 0];
end

% Optional exact equality G(1)=G(end) for gradient-amplitude continuity
% when the compact waveform is repeated without an inserted ramp block.
if isfield(opts,'forceGPeriodicEqual') && opts.forceGPeriodicEqual
    r = zeros(1,N); r(1) = 1; r(end) = -1;
    Aeq = [Aeq; r]; beq = [beq; 0];
end

% Optional first-derivative/slew continuity at the periodic boundary.
% Discrete condition: G(2)-G(1) = G(N)-G(N-1).  This makes the slew entering
% the boundary match the slew leaving the boundary in the next repeated
% period.  Use only for N>=4; for very short periods the constraint is ill posed.
if isfield(opts,'forceSlewPeriodicEqual') && opts.forceSlewPeriodicEqual && N >= 4
    r = zeros(1,N);
    r(2) = 1;
    r(1) = -1;
    r(end) = -1;
    r(end-1) = 1;
    Aeq = [Aeq; r]; beq = [beq; 0];
end
end

function g = periodic_fallback_solution(kd, opts, lb, ub, Aeq, beq)
% Cyclic finite-difference starting point followed by projection. This keeps
% the toolbox runnable without Optimization Toolbox, but quadprog is preferred.
N = numel(kd);
g = zeros(N,1);
for i = 1:N-1
    g(i) = (kd(i+1) - kd(i)) / (opts.gammaBar * opts.dtGrad);
end
g(N) = (kd(1) - kd(N)) / (opts.gammaBar * opts.dtGrad);
g = max(min(g, ub), lb);
g = project_equalities(g, Aeq, beq);
limit = opts.Suse * opts.dtGrad;
for it = 1:opts.fallbackIterations
    g = max(min(g, ub), lb);
    g = clamp_cyclic_slew(g, limit);
    g = project_equalities(g, Aeq, beq);
end
end

function x = project_equalities(x, Aeq, beq)
if isempty(Aeq)
    return;
end
% Orthogonal projection onto Aeq*x=beq.
x = x - Aeq' * (pinv(Aeq*Aeq') * (Aeq*x - beq));
end

function x = clamp_cyclic_slew(x, limit)
N = numel(x);
for pass = 1:2
    for i = 2:N
        dx = x(i) - x(i-1);
        if abs(dx) > limit
            x(i) = x(i-1) + sign(dx) * limit;
        end
    end
    dx = x(1) - x(N);
    if abs(dx) > limit
        x(1) = x(N) + sign(dx) * limit;
    end
    for i = N-1:-1:1
        dx = x(i) - x(i+1);
        if abs(dx) > limit
            x(i) = x(i+1) + sign(dx) * limit;
        end
    end
end
end
