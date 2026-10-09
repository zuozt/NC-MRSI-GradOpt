%% Test that rotating a petal preserves gradient norm approximately
sys.Gmax = 80e-3; sys.Smax = 200; sys.dtGrad = 10e-6; sys.gammaBar = 17.235e6;
acq = setup_mrsi_readout(128, 5000);
opt.mode = 'fixed_duration'; opt.forceGStartZero = true; opt.forceGEndZero = true;
params.N = acq.nADC; params.Kmax = 20; params.nRadial = 2; params.nAngular = 1; params.phi = pi/12;
k = make_rosette_3d(params);
r = nc_mrsi_gradopt(k, sys, acq, opt);
R = make_rotation_z(pi/4);
p = rotate_petal_3d(r, R);
n1 = sqrt(sum(r.G.^2,2));
n2 = sqrt(sum(p.G.^2,2));
assert(max(abs(n1-n2)) < 1e-10);
disp('test_petal_rotation_consistency passed');
