function post = design_post_gradient_to_origin(kStart, GStart, opts, Npost)
%DESIGN_POST_GRADIENT_TO_ORIGIN Return from a ring boundary to k=0 and G=0.
%
% post = design_post_gradient_to_origin(kStart, GStart, opts, Npost)
%
% The post-gradient is outside the ADC window.  Its discrete waveform:
%   1) starts at the final readout gradient, Gpost(1)=GStart,
%   2) ends at zero gradient, Gpost(end)=0,
%   3) has moment gammaBar*dt*sum(Gpost)=-kStart,
%   4) obeys the configured axis-wise gradient and slew limits.
%
% kStart is the k-space position after the final cyclic readout interval has
% closed the ring.  For a valid compact period this is the ring start.

if nargin < 4
    Npost = [];
end
kStart = kStart(:).';
GStart = GStart(:).';
D = numel(kStart);
if numel(GStart) ~= D
    error('kStart and GStart must have the same number of dimensions.');
end

if isempty(Npost) || ~isfinite(Npost) || Npost < 4
    Npost = estimate_post_samples(kStart, GStart, opts);
end
Npost = max(4, round(Npost));

maxNpost = max(Npost, 256);
lastErr = [];
for nTry = Npost:maxNpost
    try
        Gpost = solve_post_qp(kStart, GStart, opts, nTry);
        post = build_post_struct(Gpost, kStart, GStart, opts);
        post.requestedNpost = Npost;
        return;
    catch ME
        lastErr = ME;
    end
end

if isempty(lastErr)
    lastMessage = 'unknown solver failure';
else
    lastMessage = lastErr.message;
end
warning(['Post-gradient QP failed or was infeasible. Using clipped equality ' ...
    'fallback. Last error: %s'], lastMessage);
Gpost = fallback_post_solution(kStart, GStart, opts, maxNpost);
post = build_post_struct(Gpost, kStart, GStart, opts);
post.requestedNpost = Npost;
post.fallbackUsed = true;
end

function Npost = estimate_post_samples(kStart, GStart, opts)
moment = abs(kStart) ./ opts.gammaBar;
Nmoment = max(moment ./ max(opts.Guse*opts.dtGrad, eps));
Nslew = max(abs(GStart) ./ max(opts.Suse*opts.dtGrad, eps)) + 2;
Npost = ceil(max([Nmoment(:); Nslew(:); 12]) * 1.8);
Npost = max(8, Npost);
end

function Gpost = solve_post_qp(kStart, GStart, opts, Npost)
D = numel(kStart);
Gpost = zeros(Npost, D);
if exist('quadprog', 'file') ~= 2
    error('quadprog is not available.');
end

D1 = diff(eye(Npost),1,1);
D2 = diff(eye(Npost),2,1);
H = 2*(1e-4*eye(Npost) + D1'*D1 + 0.2*(D2'*D2));
f = zeros(Npost,1);
lb = -opts.Guse * ones(Npost,1);
ub =  opts.Guse * ones(Npost,1);
Aineq = [D1; -D1];
bineq = opts.Suse * opts.dtGrad * ones(2*(Npost-1),1);
qopt = optimoptions('quadprog', 'Display', 'off', ...
    'Algorithm', 'interior-point-convex');

for d = 1:D
    Aeq = zeros(3,Npost);
    beq = zeros(3,1);
    Aeq(1,1) = 1;              beq(1) = GStart(d);
    Aeq(2,end) = 1;            beq(2) = 0;
    Aeq(3,:) = opts.gammaBar * opts.dtGrad;
    beq(3) = -kStart(d);
    [gd,~,exitflag] = quadprog(H,f,Aineq,bineq,Aeq,beq, ...
        lb,ub,[],qopt);
    if exitflag <= 0 || isempty(gd)
        error('post-gradient quadprog failed for dimension %d with Npost=%d.', ...
            d,Npost);
    end
    Gpost(:,d) = gd;
end
end

function Gpost = fallback_post_solution(kStart, GStart, opts, Npost)
D = numel(kStart);
Gpost = zeros(Npost,D);
for d = 1:D
    Aeq = zeros(3,Npost);
    beq = zeros(3,1);
    Aeq(1,1) = 1;   beq(1) = GStart(d);
    Aeq(2,end) = 1; beq(2) = 0;
    Aeq(3,:) = opts.gammaBar * opts.dtGrad;
    beq(3) = -kStart(d);
    gd = Aeq' * (pinv(Aeq*Aeq') * beq);
    gd = max(min(gd,opts.Guse),-opts.Guse);
    Gpost(:,d) = gd;
end
end

function post = build_post_struct(Gpost, kStart, GStart, opts)
D = size(Gpost,2);
Spost = diff(Gpost,1,1) ./ opts.dtGrad;
kpost = repmat(kStart,size(Gpost,1),1) + ...
    opts.gammaBar * opts.dtGrad * cumsum(Gpost,1);

post = struct();
post.enabled = true;
post.kind = 'hardware-constrained post-gradient from ring boundary to origin';
post.G = Gpost;
post.S = Spost;
post.ktraj_actual = kpost;
post.time_grad = (0:size(Gpost,1)-1).' * opts.dtGrad;
post.Npost = size(Gpost,1);
post.duration = post.Npost * opts.dtGrad;
post.kStartActual = kStart;
post.kEndTarget = zeros(1,D);
post.GStartTarget = GStart;
post.startG = Gpost(1,:);
post.endG = Gpost(end,:);
post.startMismatchNorm = norm(Gpost(1,:) - GStart);
post.endGNorm = norm(Gpost(end,:));
post.momentTarget = -kStart;
post.momentActual = opts.gammaBar * opts.dtGrad * sum(Gpost,1);
post.momentError = post.momentActual - post.momentTarget;
post.momentErrorNorm = norm(post.momentError);
post.returnError = kpost(end,:);
post.returnErrorNorm = norm(post.returnError);
post.boundarySlewIn = (Gpost(1,:) - GStart) ./ opts.dtGrad;
post.boundarySlewOut = (zeros(1,D) - Gpost(end,:)) ./ opts.dtGrad;
post.maxGAxis = max(abs(Gpost),[],1);
if isempty(Spost)
    post.maxSAxis = zeros(1,D);
else
    post.maxSAxis = max(abs(Spost),[],1);
end
post.isFeasible = all(post.maxGAxis <= opts.Guse*(1+1e-8)) && ...
    all(post.maxSAxis <= opts.Suse*(1+1e-8)) && ...
    post.startMismatchNorm < 1e-10 && post.endGNorm < 1e-10 && ...
    post.returnErrorNorm < 1e-6;
end
