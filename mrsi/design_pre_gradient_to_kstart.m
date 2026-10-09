function pre = design_pre_gradient_to_kstart(kStart, GEnd, opts, Npre)
%DESIGN_PRE_GRADIENT_TO_KSTART Design pre-ADC gradient from zero to a k start.
%
% pre = design_pre_gradient_to_kstart(kStart, GEnd, opts, Npre)
%
% Purpose
%   For CRT single-ring MRSI, the ADC readout may start on a nonzero-radius
%   ring.  A non-ADC pre-gradient is therefore needed before the ring starts.
%   This helper designs a pre-gradient that
%
%       1) starts from zero gradient, Gpre(1)=0,
%       2) ends at the first readout gradient, Gpre(end)=GEnd,
%       3) has zeroth moment gammaBar*dt*sum(Gpre)=kStart,
%       4) obeys axis-wise gradient and slew limits when possible.
%
% Inputs
%   kStart : [1 x D] desired k-space position at ADC start, cycles/m.
%            Usually result.ktraj_actual(1,:) or result.ktraj_target(1,:).
%   GEnd   : [1 x D] readout gradient at ADC start, T/m.
%            Usually result.G(1,:).
%   opts   : result.opts, must contain gammaBar, dtGrad, Guse, Suse.
%   Npre   : number of pre-gradient samples. If empty, an automatic value is
%            estimated and increased until a solution is found.
%
% Output
%   pre.G              [Npre x D] pre-gradient waveform, T/m
%   pre.S              [Npre-1 x D] slew within pre-gradient, T/m/s
%   pre.ktraj_actual   [Npre x D] k trajectory before ADC, cycles/m
%   pre.time_grad      [Npre x 1] negative time axis ending at -dt, s
%   pre.Npre           number of pre-gradient samples
%   pre.momentError    final prephase k error, cycles/m
%   pre.boundarySlew   slew from Gpre(end) to readout G(1), T/m/s
%   pre.isFeasible     basic gradient/slew/moment feasibility flag
%
% Notes
%   The pre-gradient is outside the ADC window.  The optimized compact ring
%   itself is still treated as one periodic MRSI readout period.

if nargin < 4
    Npre = [];
end
kStart = kStart(:).';
GEnd = GEnd(:).';
D = numel(kStart);
if numel(GEnd) ~= D
    error('kStart and GEnd must have the same number of dimensions.');
end

if isempty(Npre) || ~isfinite(Npre) || Npre < 4
    Npre = estimate_pre_samples(kStart, GEnd, opts);
end
Npre = max(4, round(Npre));

% Try the requested Npre first.  If the QP is infeasible, gradually increase
% the number of samples because more time makes the moment and slew constraints
% easier to satisfy.
maxNpre = max(Npre, 256);
lastErr = [];
for nTry = Npre:maxNpre
    try
        Gpre = solve_pre_qp(kStart, GEnd, opts, nTry);
        pre = build_pre_struct(Gpre, kStart, GEnd, opts);
        pre.requestedNpre = Npre;
        return;
    catch ME
        lastErr = ME;
    end
end

% Fallback: use a minimum-norm equality solution without hard inequality
% guarantees, then clip and report infeasibility.  This avoids hard failure
% in MATLAB installations without Optimization Toolbox.
warning('Pre-gradient QP failed or was infeasible. Using clipped equality fallback. Last error: %s', lastErr.message);
Gpre = fallback_pre_solution(kStart, GEnd, opts, maxNpre);
pre = build_pre_struct(Gpre, kStart, GEnd, opts);
pre.requestedNpre = Npre;
pre.fallbackUsed = true;
end

function Npre = estimate_pre_samples(kStart, GEnd, opts)
% Moment-based lower bound plus a slew-based lower bound.  Add slack because
% the waveform must both achieve a k-space prephase moment and end at GEnd.
Guse = opts.Guse;
dt = opts.dtGrad;
moment = abs(kStart) ./ opts.gammaBar;  % T/m*s
Nmoment = max(moment ./ max(Guse*dt, eps));
Nslew = max(abs(GEnd) ./ max(opts.Suse*dt, eps)) + 2;
Npre = ceil(max([Nmoment(:); Nslew(:); 12]) * 1.8);
Npre = max(8, Npre);
end

function Gpre = solve_pre_qp(kStart, GEnd, opts, Npre)
D = numel(kStart);
Gpre = zeros(Npre, D);

useQuadprog = exist('quadprog', 'file') == 2;
if ~useQuadprog
    error('quadprog is not available.');
end

% Smooth/minimum-energy objective.
D1 = diff(eye(Npre),1,1);
D2 = diff(eye(Npre),2,1);
H = 2*(1e-4*eye(Npre) + D1'*D1 + 0.2*(D2'*D2));
f = zeros(Npre,1);

% Gradient amplitude limits.
lb = -opts.Guse * ones(Npre,1);
ub =  opts.Guse * ones(Npre,1);

% Slew limits within the pre-gradient.
Aineq = [D1; -D1];
bineq = opts.Suse * opts.dtGrad * ones(2*(Npre-1), 1);

qopt = optimoptions('quadprog', 'Display', 'off', 'Algorithm', 'interior-point-convex');
for d = 1:D
    % Equalities:
    %   first sample gradient = 0
    %   last sample gradient  = GEnd(d)
    %   gradient moment       = kStart(d)/gammaBar
    Aeq = zeros(3,Npre);
    beq = zeros(3,1);
    Aeq(1,1) = 1;             beq(1) = 0;
    Aeq(2,end) = 1;           beq(2) = GEnd(d);
    Aeq(3,:) = opts.gammaBar * opts.dtGrad; beq(3) = kStart(d);

    [gd,~,exitflag] = quadprog(H, f, Aineq, bineq, Aeq, beq, lb, ub, [], qopt);
    if exitflag <= 0 || isempty(gd)
        error('pre-gradient quadprog failed for dimension %d with Npre=%d.', d, Npre);
    end
    Gpre(:,d) = gd;
end
end

function Gpre = fallback_pre_solution(kStart, GEnd, opts, Npre)
D = numel(kStart);
Gpre = zeros(Npre,D);
for d = 1:D
    Aeq = zeros(3,Npre);
    beq = zeros(3,1);
    Aeq(1,1) = 1; beq(1) = 0;
    Aeq(2,end) = 1; beq(2) = GEnd(d);
    Aeq(3,:) = opts.gammaBar * opts.dtGrad; beq(3) = kStart(d);
    gd = Aeq' * (pinv(Aeq*Aeq') * beq);
    gd = max(min(gd, opts.Guse), -opts.Guse);
    Gpre(:,d) = gd;
end
end

function pre = build_pre_struct(Gpre, kStart, GEnd, opts)
D = size(Gpre,2);
Spre = diff(Gpre,1,1) ./ opts.dtGrad;
kpre = opts.gammaBar * opts.dtGrad * cumsum(Gpre,1);
timePre = ((-size(Gpre,1)):-1).' * opts.dtGrad;

pre = struct();
pre.enabled = true;
pre.kind = 'zero-start pre-gradient to ring start';
pre.G = Gpre;
pre.S = Spre;
pre.ktraj_actual = kpre;
pre.time_grad = timePre;
pre.Npre = size(Gpre,1);
pre.duration = size(Gpre,1) * opts.dtGrad;
pre.kStartTarget = kStart;
pre.GEndTarget = GEnd;
pre.startG = Gpre(1,:);
pre.endG = Gpre(end,:);
pre.startGNorm = norm(Gpre(1,:));
pre.endMismatchNorm = norm(Gpre(end,:) - GEnd);
pre.momentError = kpre(end,:) - kStart;
pre.momentErrorNorm = norm(pre.momentError);
pre.boundarySlew = (GEnd - Gpre(end,:)) ./ opts.dtGrad;
pre.boundarySlewNorm = norm(pre.boundarySlew);
pre.maxGAxis = max(abs(Gpre), [], 1);
if isempty(Spre)
    pre.maxSAxis = zeros(1,D);
else
    pre.maxSAxis = max(abs(Spre), [], 1);
end
pre.isFeasible = all(pre.maxGAxis <= opts.Guse*(1+1e-8)) && ...
    all(pre.maxSAxis <= opts.Suse*(1+1e-8)) && ...
    pre.startGNorm < 1e-10 && pre.endMismatchNorm < 1e-10 && ...
    pre.momentErrorNorm < 1e-6;
end
