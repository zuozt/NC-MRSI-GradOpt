function report = check_periodic_closure(ktraj, G, opts)
%CHECK_PERIODIC_CLOSURE Report periodic closure/moment consistency.
%
% For periodic MRSI, ktraj contains Npp unique samples inside [0,T). The
% duplicated endpoint at T is not stored. The final gradient sample closes the
% trajectory from k(Npp) to k(1) of the next period.

if nargin < 3
    opts = struct();
end
report = struct();
report.kStart = ktraj(1,:);
report.kEndSample = ktraj(end,:);
report.deltaKLastSampleToStart = ktraj(end,:) - ktraj(1,:);
report.deltaKTargetNorm = norm(report.deltaKLastSampleToStart);

if nargin >= 2 && ~isempty(G)
    report.GStart = G(1,:);
    report.GEnd = G(end,:);
    report.GBoundaryNorm = norm(G(1,:)) + norm(G(end,:));
    report.GPeriodicJump = G(1,:) - G(end,:);
    report.GPeriodicJumpNorm = norm(report.GPeriodicJump);
    if size(G,1) >= 4 && isfield(opts,'dtGrad')
        report.SlewPeriodicJump = ((G(2,:) - G(1,:)) - (G(end,:) - G(end-1,:))) ./ opts.dtGrad;
        report.SlewPeriodicJumpNorm = norm(report.SlewPeriodicJump);
    else
        report.SlewPeriodicJump = [];
        report.SlewPeriodicJumpNorm = NaN;
    end

    if isfield(opts,'gammaBar') && isfield(opts,'dtGrad')
        moment = sum(G,1) * opts.dtGrad;
        report.gradientMoment = moment;
        report.deltaKFromMoment = opts.gammaBar * moment;
        report.deltaKFromMomentNorm = norm(report.deltaKFromMoment);
        report.kNextStartFromGradient = ktraj(1,:) + report.deltaKFromMoment;
        report.kNextStartError = report.kNextStartFromGradient - ktraj(1,:);
        report.kNextStartErrorNorm = norm(report.kNextStartError);
        report.closedByMoment = report.kNextStartErrorNorm;
    else
        report.gradientMoment = sum(G,1);
        report.deltaKFromMoment = [];
        report.deltaKFromMomentNorm = NaN;
        report.kNextStartErrorNorm = NaN;
        report.closedByMoment = NaN;
    end

    if size(G,1) > 1 && isfield(opts,'dtGrad')
        dG = [diff(G,1,1); G(1,:) - G(end,:)];
        report.maxCyclicSlewAxis = max(abs(dG ./ opts.dtGrad), [], 1);
        report.maxCyclicSlewNorm = max(sqrt(sum((dG ./ opts.dtGrad).^2,2)));
    else
        report.maxCyclicSlewAxis = [];
        report.maxCyclicSlewNorm = NaN;
    end
else
    report.gradientMoment = [];
    report.deltaKFromMoment = [];
    report.deltaKFromMomentNorm = NaN;
    report.GStart = [];
    report.GEnd = [];
    report.GBoundaryNorm = NaN;
    report.GPeriodicJump = [];
    report.GPeriodicJumpNorm = NaN;
    report.kNextStartErrorNorm = NaN;
    report.maxCyclicSlewAxis = [];
    report.maxCyclicSlewNorm = NaN;
end
end
