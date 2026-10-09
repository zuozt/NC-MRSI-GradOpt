function report = validate_solution(G, S, k_actual, k_target, opts)
%VALIDATE_SOLUTION Build a constraint and trajectory-error report.
err = k_actual - k_target;
report = struct();
report.maxGAxis = max(abs(G), [], 1);
report.maxSAxis = max(abs(S), [], 1);
report.maxGNorm = max(sqrt(sum(G.^2,2)));
report.maxSNorm = max(sqrt(sum(S.^2,2)));
if isfield(opts,'periodic') && opts.periodic
    report.cyclicGJump = G(1,:) - G(end,:);
    report.cyclicGJumpNorm = norm(report.cyclicGJump);
    if size(G,1) >= 4
        report.cyclicSlewJump = (G(2,:) - G(1,:) - G(end,:) + G(end-1,:)) ./ opts.dtGrad;
        report.cyclicSlewJumpNorm = norm(report.cyclicSlewJump);
    else
        report.cyclicSlewJump = NaN(1,size(G,2));
        report.cyclicSlewJumpNorm = NaN;
    end
else
    report.cyclicGJump = [];
    report.cyclicGJumpNorm = NaN;
    report.cyclicSlewJump = [];
    report.cyclicSlewJumpNorm = NaN;
end
report.kErrorRMS = sqrt(mean(sum(err.^2,2)));
report.kErrorMax = max(sqrt(sum(err.^2,2)));
report.startG = G(1,:);
report.endG = G(end,:);
report.startK = k_actual(1,:);
report.endK = k_actual(end,:);
if isfield(opts,'periodic') && opts.periodic
    report.duration = size(G,1) * opts.dtGrad;
else
    report.duration = (size(G,1)-1) * opts.dtGrad;
end
report.feasibleGradientAxis = all(report.maxGAxis <= opts.Guse * (1 + 1e-9));
report.feasibleSlewAxis = all(report.maxSAxis <= opts.Suse * (1 + 1e-9));
report.feasibleBoundary = true;
if opts.forceGStartZero
    report.feasibleBoundary = report.feasibleBoundary && norm(G(1,:)) < 1e-12;
end
if opts.forceGEndZero
    report.feasibleBoundary = report.feasibleBoundary && norm(G(end,:)) < 1e-12;
end
if isfield(opts,'forceGPeriodicEqual') && opts.forceGPeriodicEqual
    report.feasibleBoundary = report.feasibleBoundary && report.cyclicGJumpNorm < 1e-10;
end
if isfield(opts,'forceSlewPeriodicEqual') && opts.forceSlewPeriodicEqual && ~isnan(report.cyclicSlewJumpNorm)
    report.feasibleBoundary = report.feasibleBoundary && report.cyclicSlewJumpNorm < 1e-6;
end
report.symmetryErrorG = compute_gradient_symmetry_error(G, opts.symmetry);
report.symmetryErrorK = compute_k_symmetry_error(k_target, opts.symmetry);
report.isFeasible = report.feasibleGradientAxis && report.feasibleSlewAxis && report.feasibleBoundary;

warnings = {};
if report.maxGNorm > opts.Guse * (1 + 1e-9)
    warnings{end+1} = 'Vector gradient norm exceeds Guse, although axis-wise limits may pass.'; %#ok<AGROW>
end
if report.maxSNorm > opts.Suse * (1 + 1e-9)
    warnings{end+1} = 'Vector slew norm exceeds Suse, although axis-wise limits may pass.'; %#ok<AGROW>
end
if isfield(opts,'periodic') && opts.periodic && report.cyclicGJumpNorm > 1e-10
    warnings{end+1} = 'Cyclic gradient amplitude is not continuous: G(end) differs from G(1).'; %#ok<AGROW>
end
if isfield(opts,'periodic') && opts.periodic && ~isnan(report.cyclicSlewJumpNorm) && report.cyclicSlewJumpNorm > 1e-6
    warnings{end+1} = 'Cyclic slew is not continuous: boundary slew differs from start/end slew.'; %#ok<AGROW>
end
if ~report.isFeasible
    warnings{end+1} = 'Axis-wise feasibility or boundary-continuity check failed.'; %#ok<AGROW>
end
report.warnings = warnings;
end

function e = compute_gradient_symmetry_error(G, symmetry)
if strcmpi(symmetry, 'none')
    e = NaN;
    return;
end
Gflip = flipud(G);
switch lower(symmetry)
    case 'antisymmetric_k'
        e = max(sqrt(sum((G - Gflip).^2,2))); % G(T-t)=G(t)
    case 'even_k'
        e = max(sqrt(sum((G + Gflip).^2,2))); % G(T-t)=-G(t)
    otherwise
        e = NaN;
end
end

function e = compute_k_symmetry_error(k, symmetry)
if strcmpi(symmetry, 'none')
    e = NaN;
    return;
end
kflip = flipud(k);
switch lower(symmetry)
    case 'antisymmetric_k'
        e = max(sqrt(sum((k + kflip).^2,2))); % k(T-t)=-k(t)
    case 'even_k'
        e = max(sqrt(sum((k - kflip).^2,2))); % k(T-t)=k(t)
    otherwise
        e = NaN;
end
end
