%% Test direct k-to-gradient conversion
sys.Gmax = 80e-3; sys.Smax = 200; sys.dtGrad = 10e-6; sys.gammaBar = 17.235e6;
acq.readoutTime = 1e-3; acq.nADC = 101; acq.dtADC = 10e-6;
opt.mode = 'direct'; opt.forceGStartZero = false; opt.forceGEndZero = false;
N = round(acq.readoutTime/sys.dtGrad)+1;
k = [(0:N-1).' * sys.gammaBar * sys.dtGrad * 1e-3];
r = nc_mrsi_gradopt(k, sys, acq, opt);
assert(abs(mean(r.G(1:end-1)) - 1e-3) < 1e-8);
disp('test_direct_k2grad passed');
