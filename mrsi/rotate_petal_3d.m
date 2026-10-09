function petal = rotate_petal_3d(baseResult, R, sys, acq, opt)
%ROTATE_PETAL_3D Rotate optimized base petal and recompute k-space and report.
Grot = rotate_gradient_3d(baseResult.G, R);
opts = baseResult.opts;
if nargin >= 3 && ~isempty(sys)
    if nargin < 4 || isempty(acq); acq = struct(); end
    if nargin < 5 || isempty(opt); opt = struct(); end
    opts = parse_options(sys, acq, opt);
end
Srot = compute_slew(Grot, opts.dtGrad);
k0 = baseResult.ktraj_actual(1,:);
if numel(k0) < size(Grot,2)
    k0 = [k0, zeros(1, size(Grot,2)-numel(k0))];
end
krot = integrate_gradient(Grot, opts, k0);
kadc = sample_ktraj_at_adc(krot, opts);
petal = baseResult;
petal.G = Grot;
petal.S = Srot;
petal.ktraj_actual = krot;
petal.ktraj_adc = kadc;
petal.report = validate_solution(Grot, Srot, krot, krot, opts);
end
