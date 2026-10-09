%% Test fixed-duration solver feasibility on a simple radial trajectory
sys.Gmax = 80e-3; sys.Smax = 200; sys.dtGrad = 10e-6; sys.gammaBar = 17.235e6;
acq = setup_mrsi_readout(128, 5000);
opt.mode = 'fixed_duration'; opt.forceGStartZero = true; opt.forceGEndZero = true;
opt.safetyMargin = 0.95; opt.lambdaSlew = 1e-8; opt.lambdaSmooth = 1e-12;
params.N = acq.nADC; params.Kmax = 20; params.angle = 0;
k = make_radial(params);
r = nc_mrsi_gradopt(k, sys, acq, opt);
assert(isfield(r, 'G'));
assert(all(isfinite(r.G(:))));
disp('test_fixed_duration_solver passed');
