function resultSet = optimize_concentric_crt_set(params, sys, acq, opt, setOpts)
%OPTIMIZE_CONCENTRIC_CRT_SET Optimize every ring as an independent period.
%
% resultSet = optimize_concentric_crt_set(params, sys, acq, opt, setOpts)
%
% This is the batch counterpart of nc_mrsi_gradopt for a complete CRT
% acquisition.  Each ring receives exactly params.Npp target/ADC samples and
% is optimized independently with identical timing and hardware constraints.
%
% setOpts fields:
%   .usePreGradient    add an independent zero-start pre-gradient, default true
%   .preGradientSamples fixed Npre for every ring; [] or 0 means auto
%   .usePostGradient   add an independent return-to-origin post-gradient,
%                      default true
%   .postGradientSamples fixed Npost for every ring; [] or 0 means auto
%   .Nspec             periods/FID used to build each expanded readout
%                      (defaults to acq.Nspec, or 1 if absent)
%
% The returned resultSet.rings(rr) is a normal nc_mrsi_gradopt result with
% added ringIndex, ringRadius, and full fields.

if nargin < 5 || isempty(setOpts)
    setOpts = struct();
end
if ~isfield(params,'Npp') || isempty(params.Npp)
    if isfield(acq,'Npp') && ~isempty(acq.Npp)
        params.Npp = acq.Npp;
    elseif isfield(acq,'nADC') && ~isempty(acq.nADC)
        params.Npp = acq.nADC;
    else
        error('params.Npp (samples per ring) is required.');
    end
end

crtSet = make_concentric_crt_set(params);
usePreGradient = getp(setOpts, 'usePreGradient', true);
Npre = getp(setOpts, 'preGradientSamples', []);
if ~isempty(Npre) && Npre <= 0
    Npre = [];
end
usePostGradient = getp(setOpts, 'usePostGradient', true);
Npost = getp(setOpts, 'postGradientSamples', []);
if ~isempty(Npost) && Npost <= 0
    Npost = [];
end
Nspec = getp(setOpts, 'Nspec', getp(acq, 'Nspec', 1));
Nspec = max(1, round(Nspec));

for rr = 1:crtSet.nRings
    ringResult = nc_mrsi_gradopt(crtSet.targets{rr}, sys, acq, opt);
    if usePreGradient
        ringResult = add_pre_gradient_to_periodic_result(ringResult, Npre);
    end
    if usePostGradient
        ringResult = add_post_gradient_to_periodic_result(ringResult,Npost);
    end
    ringResult.ringIndex = rr;
    ringResult.ringRadius = crtSet.radii(rr);
    ringResult.periodic = make_periodic_info(acq, ringResult, Nspec);
    ringResult.full = expand_periodic_readout(ringResult, Nspec);

    if rr == 1
        rings = repmat(ringResult, crtSet.nRings, 1);
    else
        rings(rr) = ringResult;
    end
end

feasible = false(crtSet.nRings,1);
kErrorRMS = zeros(crtSet.nRings,1);
kErrorMax = zeros(crtSet.nRings,1);
maxGAxis = zeros(crtSet.nRings, size(rings(1).G,2));
maxSAxis = zeros(crtSet.nRings, size(rings(1).G,2));
preFeasible = true(crtSet.nRings,1);
postFeasible = true(crtSet.nRings,1);
moduleFeasible = true(crtSet.nRings,1);
maxGAxisModule = maxGAxis;
maxSAxisModule = maxSAxis;
returnError = zeros(crtSet.nRings,1);
postSolverReturnError = zeros(crtSet.nRings,1);
fullFidReturnError = zeros(crtSet.nRings,1);
fullFidReturnPass = true(crtSet.nRings,1);
for rr = 1:crtSet.nRings
    feasible(rr) = logical(rings(rr).report.isFeasible);
    kErrorRMS(rr) = rings(rr).report.kErrorRMS;
    kErrorMax(rr) = rings(rr).report.kErrorMax;
    maxGAxis(rr,:) = rings(rr).report.maxGAxis;
    maxSAxis(rr,:) = rings(rr).report.maxSAxis;
    if isfield(rings(rr),'pre') && isfield(rings(rr).pre,'isFeasible')
        preFeasible(rr) = logical(rings(rr).pre.isFeasible);
    end
    if isfield(rings(rr),'post') && isfield(rings(rr).post,'isFeasible')
        postFeasible(rr) = logical(rings(rr).post.isFeasible);
        postSolverReturnError(rr) = rings(rr).post.returnErrorNorm;
    end
    if isfield(rings(rr),'sequence') && isfield(rings(rr).sequence,'isFeasible')
        moduleFeasible(rr) = logical(rings(rr).sequence.isFeasible);
        maxGAxisModule(rr,:) = rings(rr).sequence.maxGAxis;
        maxSAxisModule(rr,:) = rings(rr).sequence.maxSAxis;
        returnError(rr) = rings(rr).sequence.returnErrorNorm;
    end
    if isfield(rings(rr),'full') && isfield(rings(rr).full,'returnErrorNorm')
        fullFidReturnError(rr) = rings(rr).full.returnErrorNorm;
        fullFidReturnPass(rr) = rings(rr).full.returnErrorNorm < 1e-6 && ...
            rings(rr).full.terminalReturnErrorNorm < 1e-6;
    end
end

summary = struct();
summary.ringFeasible = feasible;
summary.preGradientFeasible = preFeasible;
summary.postGradientFeasible = postFeasible;
summary.completeModuleFeasible = moduleFeasible;
summary.allReadoutsFeasible = all(feasible);
summary.allPreGradientsFeasible = all(preFeasible);
summary.allPostGradientsFeasible = all(postFeasible);
summary.allCompleteModulesFeasible = all(moduleFeasible);
summary.allFullFidReturnsFeasible = all(fullFidReturnPass);
summary.allFeasible = all(feasible) && all(preFeasible) && ...
    all(postFeasible) && all(moduleFeasible) && all(fullFidReturnPass);
summary.kErrorRMS = kErrorRMS;
summary.kErrorMax = kErrorMax;
summary.maxGAxis = maxGAxis;
summary.maxSAxis = maxSAxis;
summary.maxGAxisModule = maxGAxisModule;
summary.maxSAxisModule = maxSAxisModule;
summary.returnError = returnError;
summary.worstReturnError = max(returnError);
summary.postSolverReturnError = postSolverReturnError;
summary.worstPostSolverReturnError = max(postSolverReturnError);
summary.fullFidReturnError = fullFidReturnError;
summary.fullFidReturnPass = fullFidReturnPass;
summary.worstFullFidReturnError = max(fullFidReturnError);
summary.worstKErrorRMS = max(kErrorRMS);
summary.worstKErrorMax = max(kErrorMax);
summary.maxGAxisAcrossRings = max(maxGAxis,[],1);
summary.maxSAxisAcrossRings = max(maxSAxis,[],1);
summary.maxGAxisCompleteModule = max(maxGAxisModule,[],1);
summary.maxSAxisCompleteModule = max(maxSAxisModule,[],1);

resultSet = struct();
resultSet.isCrtRingSet = true;
resultSet.mode = 'multi_ring_set';
resultSet.NppPerRing = crtSet.NppPerRing;
resultSet.nRings = crtSet.nRings;
resultSet.totalSpatialSamples = crtSet.totalSpatialSamples;
resultSet.totalADCSamplesAllRings = crtSet.totalSpatialSamples * Nspec;
resultSet.radii = crtSet.radii;
resultSet.targets = crtSet.targets;
resultSet.targetStack = crtSet.targetStack;
resultSet.rings = rings;
resultSet.summary = summary;
resultSet.params = params;
resultSet.sys = sys;
resultSet.acq = acq;
resultSet.opt = opt;
resultSet.setOpts = setOpts;
end

function info = make_periodic_info(acq, result, Nspec)
info = struct();
info.Npp = size(result.G,1);
info.Nspec = Nspec;
info.nADCtotal = info.Npp * Nspec;
info.adcDwell = getp(acq, 'dtADC', result.opts.dtADC);
info.periodTime = info.Npp * info.adcDwell;
info.spectralBW = 1 / info.periodTime;
info.spectralResolution = info.spectralBW / Nspec;
info.totalReadoutTime = info.nADCtotal * info.adcDwell;
info.closure = check_periodic_closure(result.ktraj_actual, result.G, result.opts);
end

function v = getp(s, name, defaultValue)
if isfield(s,name) && ~isempty(s.(name))
    v = s.(name);
else
    v = defaultValue;
end
end
