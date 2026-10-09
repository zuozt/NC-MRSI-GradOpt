function module = prepare_periodic_pulseq_module(result, moduleOpts)
%PREPARE_PERIODIC_PULSEQ_MODULE Convert a periodic result to Pulseq timing.
%
% module = prepare_periodic_pulseq_module(result, moduleOpts)
%
% NC-MRSI-GradOpt stores G(i) as the constant gradient moment that advances
% k(i) to k(i+1). Pulseq plays gradients by linearly interpolating explicit
% samples on the gradient raster. This function solves for periodic
% raster-edge samples whose exact piecewise-linear integral between
% neighbouring ADC centres reproduces result.ktraj_actual.
%
% The generated module contains:
%   - an ADC-free extended pre-gradient from G=0 to the periodic boundary,
%   - one periodic readout waveform with Npp ADC-centred samples,
%   - an ADC-free extended post-gradient cancelling the remaining k moment
%     and returning to both k=0 and G=0.
%
% Pre/post gradients use edge samples on the gradient raster.  This is
% intentional: Pulseq 1.4.1 does not serialize arbitrary-gradient first/last
% values.  Edge-sampled extended gradients preserve the explicit zero start
% and zero end after write_v141 -> Sequence.read.
%
% moduleOpts fields:
%   .targetSource       'actual' (default) or 'target'
%   .preGradientSamples []/0 for automatic, otherwise requested Npre
%   .postGradientSamples []/0 for automatic, otherwise requested Npost
%   .momentTolerance    default 1e-6 cycles/m

if nargin < 2 || isempty(moduleOpts)
    moduleOpts = struct();
end
validate_result(result);

targetSource = lower(getp(moduleOpts, 'targetSource', 'actual'));
switch targetSource
    case 'actual'
        kAdc = result.ktraj_actual;
    case 'target'
        kAdc = result.ktraj_target;
    otherwise
        error('moduleOpts.targetSource must be ''actual'' or ''target''.');
end
kAdc = pad3(kAdc);

opts = result.opts;
N = size(kAdc,1);
dt = opts.dtGrad;
gammaBar = opts.gammaBar;
if abs(opts.dtADC-dt) > max(1e-12, 1e-9*dt)
    error('ADC-centred Pulseq export currently requires dtADC == dtGrad.');
end
if opts.nADC ~= N
    error('ADC-centred Pulseq export requires nADC == number of period samples.');
end

[Gread, GreadEdge, conversion] = adc_kspace_to_pulseq_gradient(kAdc, gammaBar, dt, ...
    pad3(result.G));
Gboundary = GreadEdge(1,:);

% Pulseq places the first ADC at dt/2. From the block boundary to that ADC
% the gradient is the first half of the linear edge interval q(1)->q(2).
kBlockStart = kAdc(1,:) - gammaBar * dt .* ...
    (3*GreadEdge(1,:) + GreadEdge(2,:)) ./ 8;

Npre = getp(moduleOpts, 'preGradientSamples', []);
if isempty(Npre) && isfield(result,'pre') && isstruct(result.pre) && ...
        isfield(result.pre,'Npre')
    Npre = result.pre.Npre;
end
pre = design_pulseq_pre_gradient(kBlockStart, Gboundary, opts, Npre);

Npost = getp(moduleOpts, 'postGradientSamples', []);
post = design_pulseq_post_gradient(kBlockStart,Gboundary,opts,Npost);

module = struct();
module.kind = 'periodic ADC-centred Pulseq gradient-ADC module';
module.targetSource = targetSource;
module.Npp = N;
module.dtGrad = dt;
module.dtADC = opts.dtADC;
module.gammaBar = gammaBar;
module.kAdcReference = kAdc;
module.kBlockStart = kBlockStart;
module.Gread = Gread;
module.GreadEdge = GreadEdge;
module.Gboundary = Gboundary;
module.pre = pre;
module.post = post;
module.conversion = conversion;
module.maxGAxisRead = max(abs(GreadEdge),[],1);
module.maxSAxisRead = max(abs(diff(GreadEdge,1,1)./dt),[],1);
module.maxGAxisModule = max([module.maxGAxisRead; pre.maxGAxis; post.maxGAxis],[],1);
module.maxSAxisModule = max([module.maxSAxisRead; pre.maxSAxis; post.maxSAxis],[],1);
module.hardwarePass = all(module.maxGAxisModule <= opts.Guse*(1+1e-8)) && ...
    all(module.maxSAxisModule <= opts.Suse*(1+1e-8));
module.momentTolerance = getp(moduleOpts, 'momentTolerance', 1e-6);
module.prephasePass = pre.momentErrorNorm <= module.momentTolerance;
module.returnPass = post.returnErrorNorm <= module.momentTolerance;
module.isFeasible = module.hardwarePass && module.prephasePass && ...
    module.returnPass && post.isFeasible && ...
    conversion.isConsistent;
end

function [Gadc, Gedge, info] = adc_kspace_to_pulseq_gradient(k, gammaBar, dt, Glegacy)
N = size(k,1);
D = size(k,2);
dk = [diff(k,1,1); k(1,:)-k(end,:)] ./ (gammaBar*dt);

% Let q(i) be the gradient at raster edge i, with q(N+1)=q(1).
% ADC i is at the centre of q(i)->q(i+1). Exact piecewise-linear
% integration from ADC i to ADC i+1 gives
%
%   dk(i)/(gammaBar*dt) = (q(i)+6*q(i+1)+q(i+2))/8.
%
% Solving this cyclic system avoids comparing the toolbox's constant-moment
% model with Pulseq's raster-edge interpolation model.
B = zeros(N,N);
for ii = 1:N
    B(ii,ii) = B(ii,ii) + 1/8;
    B(ii,mod(ii,N)+1) = B(ii,mod(ii,N)+1) + 6/8;
    B(ii,mod(ii+1,N)+1) = B(ii,mod(ii+1,N)+1) + 1/8;
end

q = zeros(N,D);
residual = zeros(1,D);
for dd = 1:D
    q(:,dd) = B \ dk(:,dd);
    residual(dd) = max(abs(B*q(:,dd)-dk(:,dd)));
end
Gedge = [q; q(1,:)];
Gadc = 0.5*(Gedge(1:end-1,:)+Gedge(2:end,:));

info = struct();
info.model = ['Pulseq explicit raster-edge interpolation; exact ' ...
    'ADC-centre-to-ADC-centre integration'];
info.integrationMatrix = B;
info.maxStepResidual_Tm = residual;
info.maxKStepResidual_cpm = max(residual)*gammaBar*dt;
info.isConsistent = info.maxKStepResidual_cpm <= 1e-8;
info.legacyWaveformDifference_Tm = max(abs(Gadc-Glegacy),[],1);
end

function pre = design_pulseq_pre_gradient(kEnd, Gboundary, opts, Npre)
if isempty(Npre) || ~isfinite(Npre) || Npre < 4
    Npre = estimate_pre_samples(kEnd, Gboundary, opts);
end
Npre = max(4,round(Npre));
maxNpre = max(256,Npre);
lastMessage = '';

if exist('quadprog','file')==2
    for nTry = Npre:maxNpre
        try
            Gedge = solve_pre_qp(kEnd, Gboundary, opts, nTry);
            pre = build_pre(Gedge, kEnd, opts);
            pre.requestedNpre = Npre;
            return;
        catch ME
            lastMessage = ME.message;
        end
    end
else
    lastMessage = 'quadprog is unavailable';
end

warning('Pulseq pre-gradient QP failed. Using equality fallback: %s', lastMessage);
Gedge = solve_pre_fallback(kEnd, Gboundary, opts, maxNpre);
pre = build_pre(Gedge, kEnd, opts);
pre.requestedNpre = Npre;
pre.fallbackUsed = true;

    function G = solve_pre_qp(kTarget, gLast, localOpts, n)
        if exist('quadprog','file') ~= 2
            error('quadprog is unavailable.');
        end
        D = numel(kTarget);
        m = n+1; % n raster intervals, m edge samples
        G = zeros(m,D);
        D1 = diff(eye(m),1,1);
        D2 = diff(eye(m),2,1);
        H = 2*(1e-5*eye(m)+D1'*D1+0.2*(D2'*D2));
        f = zeros(m,1);
        lb = -localOpts.Guse*ones(m,1);
        ub = localOpts.Guse*ones(m,1);
        Aineq = [D1; -D1];
        limit = localOpts.Suse*localOpts.dtGrad;
        bineq = limit*ones(2*n,1);
        qopt = optimoptions('quadprog','Display','off', ...
            'Algorithm','interior-point-convex');
        weights = ones(1,m);
        weights([1 end]) = 0.5;
        firstRow = zeros(1,m);
        firstRow(1) = 1;
        lastRow = zeros(1,m);
        lastRow(end) = 1;
        Aeq = [weights; firstRow; lastRow];
        for d = 1:D
            rhsMoment = kTarget(d)/(localOpts.gammaBar*localOpts.dtGrad);
            beq = [rhsMoment; 0; gLast(d)];
            [gd,~,exitflag] = quadprog(H,f,Aineq,bineq,Aeq,beq, ...
                lb,ub,[],qopt);
            if exitflag <= 0 || isempty(gd)
                error('Pulseq pre-gradient QP failed for axis %d, Npre=%d.',d,n);
            end
            G(:,d) = gd;
        end
    end

    function G = solve_pre_fallback(kTarget, gLast, localOpts, n)
        D = numel(kTarget);
        m = n+1;
        weights = ones(1,m);
        weights([1 end]) = 0.5;
        firstRow = zeros(1,m);
        firstRow(1) = 1;
        lastRow = zeros(1,m);
        lastRow(end) = 1;
        Aeq = [weights; firstRow; lastRow];
        G = zeros(m,D);
        for d = 1:D
            rhsMoment = kTarget(d)/(localOpts.gammaBar*localOpts.dtGrad);
            beq = [rhsMoment; 0; gLast(d)];
            G(:,d) = Aeq'*(pinv(Aeq*Aeq')*beq);
        end
    end

    function out = build_pre(Gedge, kTarget, localOpts)
        first = Gedge(1,:);
        last = Gedge(end,:);
        area = pulseq_extended_area(Gedge, localOpts.dtGrad);
        kActual = localOpts.gammaBar*area;
        slew = diff(Gedge,1,1)./localOpts.dtGrad;
        out = struct();
        out.representation = 'extended raster-edge gradient';
        out.Gedge = Gedge;
        out.G = 0.5*(Gedge(1:end-1,:)+Gedge(2:end,:));
        out.times = (0:size(out.G,1)).'*localOpts.dtGrad;
        out.first = first;
        out.last = last;
        out.Npre = size(out.G,1);
        out.duration = out.Npre*localOpts.dtGrad;
        out.kTarget = kTarget;
        out.kActual = kActual;
        out.momentError = kActual-kTarget;
        out.momentErrorNorm = norm(out.momentError);
        out.maxGAxis = max(abs(Gedge),[],1);
        out.maxSAxis = max(abs(slew),[],1);
        out.isFeasible = all(out.maxGAxis <= localOpts.Guse*(1+1e-8)) && ...
            all(out.maxSAxis <= localOpts.Suse*(1+1e-8)) && ...
            out.momentErrorNorm <= 1e-6;
    end
end

function post = design_pulseq_post_gradient(kStart,Gboundary,opts,Npost)
if isempty(Npost) || ~isfinite(Npost) || Npost < 4
    Npost = estimate_pre_samples(kStart,Gboundary,opts);
end
Npost = max(4,round(Npost));
maxNpost = max(256,Npost);
lastMessage = '';

if exist('quadprog','file')==2
    for nTry=Npost:maxNpost
        try
            Gedge=solve_post_qp(-kStart,Gboundary,zeros(size(Gboundary)),opts,nTry);
            post=build_post(Gedge,kStart,opts);
            post.requestedNpost=Npost;
            return;
        catch ME
            lastMessage=ME.message;
        end
    end
else
    lastMessage='quadprog is unavailable';
end

warning('Pulseq return-to-origin post-gradient QP failed. Using equality fallback: %s',lastMessage);
Gedge=solve_post_fallback(-kStart,Gboundary,zeros(size(Gboundary)),opts,maxNpost);
post=build_post(Gedge,kStart,opts);
post.requestedNpost=Npost;
post.fallbackUsed=true;

    function Gout=solve_post_qp(kMoment,gFirst,gLast,localOpts,n)
        D=numel(kMoment);
        m=n+1;
        Gout=zeros(m,D);
        D1=diff(eye(m),1,1);
        D2=diff(eye(m),2,1);
        H=2*(1e-5*eye(m)+D1'*D1+0.2*(D2'*D2));
        f=zeros(m,1);
        lb=-localOpts.Guse*ones(m,1);
        ub= localOpts.Guse*ones(m,1);
        Aineq=[D1;-D1];
        limit=localOpts.Suse*localOpts.dtGrad;
        bineq=limit*ones(2*n,1);
        qopt=optimoptions('quadprog','Display','off', ...
            'Algorithm','interior-point-convex');
        weights=ones(1,m);
        weights([1 end])=0.5;
        firstRow=zeros(1,m);
        firstRow(1)=1;
        lastRow=zeros(1,m);
        lastRow(end)=1;
        Aeq=[weights;firstRow;lastRow];
        for d=1:D
            rhsMoment=kMoment(d)/(localOpts.gammaBar*localOpts.dtGrad);
            beq=[rhsMoment;gFirst(d);gLast(d)];
            [gd,~,exitflag]=quadprog(H,f,Aineq,bineq,Aeq,beq, ...
                lb,ub,[],qopt);
            if exitflag<=0 || isempty(gd)
                error('Pulseq post-gradient QP failed for axis %d, Npost=%d.',d,n);
            end
            Gout(:,d)=gd;
        end
    end

    function Gout=solve_post_fallback(kMoment,gFirst,gLast,localOpts,n)
        D=numel(kMoment);
        m=n+1;
        weights=ones(1,m);
        weights([1 end])=0.5;
        firstRow=zeros(1,m);
        firstRow(1)=1;
        lastRow=zeros(1,m);
        lastRow(end)=1;
        Aeq=[weights;firstRow;lastRow];
        Gout=zeros(m,D);
        for d=1:D
            rhsMoment=kMoment(d)/(localOpts.gammaBar*localOpts.dtGrad);
            beq=[rhsMoment;gFirst(d);gLast(d)];
            Gout(:,d)=Aeq'*(pinv(Aeq*Aeq')*beq);
        end
    end

    function out=build_post(Gedge,kInitial,localOpts)
        first=Gedge(1,:);
        last=Gedge(end,:);
        area=pulseq_extended_area(Gedge,localOpts.dtGrad);
        kMoment=localOpts.gammaBar*area;
        slew=diff(Gedge,1,1)./localOpts.dtGrad;
        out=struct();
        out.representation='extended raster-edge gradient';
        out.Gedge=Gedge;
        out.G=0.5*(Gedge(1:end-1,:)+Gedge(2:end,:));
        out.times=(0:size(out.G,1)).'*localOpts.dtGrad;
        out.first=first;
        out.last=last;
        out.Npost=size(out.G,1);
        out.duration=out.Npost*localOpts.dtGrad;
        out.kStart=kInitial;
        out.kMoment=kMoment;
        out.kEnd=kInitial+kMoment;
        out.returnError=out.kEnd;
        out.returnErrorNorm=norm(out.returnError);
        out.maxGAxis=max(abs(Gedge),[],1);
        out.maxSAxis=max(abs(slew),[],1);
        out.isFeasible=all(out.maxGAxis <= localOpts.Guse*(1+1e-8)) && ...
            all(out.maxSAxis <= localOpts.Suse*(1+1e-8)) && ...
            out.returnErrorNorm <= 1e-6;
    end
end

function area = pulseq_extended_area(Gedge, dt)
weights = ones(size(Gedge,1),1);
weights([1 end]) = 0.5;
area = dt*(weights.'*Gedge);
end

function N = estimate_pre_samples(kEnd,Gboundary,opts)
moment = max(abs(kEnd))/(opts.gammaBar*opts.Guse*opts.dtGrad);
ramp = max(abs(Gboundary))/(opts.Suse*opts.dtGrad);
N = max(8,ceil(1.8*max([moment ramp 8])));
end

function validate_result(result)
required = {'G','ktraj_actual','ktraj_target','opts'};
for ii = 1:numel(required)
    if ~isfield(result,required{ii}) || isempty(result.(required{ii}))
        error('result.%s is required.',required{ii});
    end
end
requiredOpts = {'gammaBar','dtGrad','dtADC','nADC','Guse','Suse'};
for ii = 1:numel(requiredOpts)
    if ~isfield(result.opts,requiredOpts{ii})
        error('result.opts.%s is required.',requiredOpts{ii});
    end
end
end

function A = pad3(A)
if size(A,2)<3
    A(:,end+1:3)=0;
end
end

function v = getp(s,name,defaultValue)
if isfield(s,name) && ~isempty(s.(name))
    v=s.(name);
else
    v=defaultValue;
end
end
