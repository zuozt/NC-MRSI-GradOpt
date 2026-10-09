function full = expand_periodic_readout(resultPeriod, Nspec)
%EXPAND_PERIODIC_READOUT Repeat a compact period result along the spectral dimension.
%
% If real pre/post gradients exist, full.G_with_module contains:
%   pre-gradient + Nspec repeated ADC periods + post-gradient.
% full.G remains the repeated ADC readout only for backwards compatibility.

if nargin < 2 || isempty(Nspec)
    if isfield(resultPeriod,'periodic') && isfield(resultPeriod.periodic,'Nspec')
        Nspec = resultPeriod.periodic.Nspec;
    else
        Nspec = 1;
    end
end
Nspec = round(Nspec);

Gperiod = resultPeriod.G;
opts = resultPeriod.opts;
Gfull = repmat(Gperiod, [Nspec 1]);
Sfull = compute_slew(Gfull, opts.dtGrad);
k0 = resultPeriod.ktraj_target(1,:);
kfull = integrate_gradient(Gfull, opts, k0);

t = (0:size(Gfull,1)-1).' * opts.dtGrad;
full = struct();
full.G = Gfull;
full.S = Sfull;
full.ktraj_actual = kfull;
full.time_grad = t;
full.Nspec = Nspec;
full.NppGrad = size(Gperiod,1);
full.NtotalGrad = size(Gfull,1);

if isfield(resultPeriod,'pre') && isstruct(resultPeriod.pre) && isfield(resultPeriod.pre,'G') && ~isempty(resultPeriod.pre.G)
    full.pre = resultPeriod.pre;
    full.G_with_pre = [resultPeriod.pre.G; Gfull];
    full.time_with_pre = [resultPeriod.pre.time_grad; t];
    full.adcStartIndex = resultPeriod.pre.Npre + 1;
    full.NtotalGradWithPre = size(full.G_with_pre,1);
end

if isfield(resultPeriod,'post') && isstruct(resultPeriod.post) && ...
        isfield(resultPeriod.post,'G') && ~isempty(resultPeriod.post.G)
    Npost = size(resultPeriod.post.G,1);
    full.post = resultPeriod.post;
    if isfield(resultPeriod,'pre') && isfield(resultPeriod.pre,'G')
        Gpre = resultPeriod.pre.G;
        Npre = size(Gpre,1);
        kInitial = zeros(1,size(Gfull,2));
    else
        Gpre = zeros(0,size(Gfull,2));
        Npre = 0;
        kInitial = k0;
    end
    full.G_with_module = [Gpre;Gfull;resultPeriod.post.G];
    full.S_with_module = diff(full.G_with_module,1,1)./opts.dtGrad;
    full.ktraj_with_module = integrate_gradient( ...
        full.G_with_module,opts,kInitial);
    full.integrationConvention = ...
        'continuous interval integration from G_with_module on one time axis';
    full.time_with_module = ...
        ((0:size(full.G_with_module,1)-1).'-Npre)*opts.dtGrad;
    full.adcMask_with_module = [zeros(size(Gpre,1),1); ...
        ones(size(Gfull,1),1);zeros(Npost,1)];
    full.segmentCode_with_module = [zeros(size(Gpre,1),1); ...
        ones(size(Gfull,1),1);2*ones(Npost,1)];
    full.adcStartIndex = Npre+1;
    full.adcEndIndex = Npre+size(Gfull,1);
    full.postStartIndex = full.adcEndIndex+1;
    full.readoutClosureIndex = full.postStartIndex;
    full.readoutClosurePoint = ...
        full.ktraj_with_module(full.readoutClosureIndex,:);
    full.ktraj_pre = full.ktraj_with_module(1:Npre,:);
    full.ktraj_adc = full.ktraj_with_module( ...
        full.adcStartIndex:full.adcEndIndex,:);
    full.ktraj_post = full.ktraj_with_module(full.postStartIndex:end,:);
    full.post.ktraj_actual = full.ktraj_post;
    full.post.kStartActual = full.readoutClosurePoint;
    full.NtotalGradWithModule = size(full.G_with_module,1);
    full.returnError = full.ktraj_with_module(end,:);
    full.returnErrorNorm = norm(full.returnError);
    full.terminalReturnError = kInitial + ...
        opts.gammaBar*opts.dtGrad*sum(full.G_with_module,1);
    full.terminalReturnErrorNorm = norm(full.terminalReturnError);
    full.post.returnError = full.returnError;
    full.post.returnErrorNorm = full.returnErrorNorm;
    full.post.kEndActual = full.returnError;
end
end
