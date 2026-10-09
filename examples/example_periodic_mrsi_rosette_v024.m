% Example: periodic 31P rosette MRSI compact-period optimization.
startup_nc_mrsi_gradopt;

Npp = 96;
Nspec = 512;
adcDwell = 5e-6;

p = struct();
p.Npp = Npp;
p.Kmax = 25;
p.nRadial = 1;
p.nAngular = 1;
p.phi = 0;
ktraj_period = make_periodic_rosette_3d(p);

sys = struct();
sys.Gmax = 80e-3;
sys.Smax = 200;
sys.dtGrad = 5e-6;
sys.gammaBar = 17.235e6;

acq = setup_periodic_mrsi_readout(Npp, Nspec, adcDwell);

opt = struct();
opt.mode = 'symmetric_fixed';
opt.symmetry = 'antisymmetric_k';
opt.forceGStartZero = true;
opt.forceGEndZero = true;
opt.safetyMargin = 0.95;
opt.maxControlPoints = 256;
opt.lambdaSlew = 1e-8;
opt.lambdaSmooth = 1e-12;

result = nc_mrsi_gradopt(ktraj_period, sys, acq, opt);
result.periodic.Npp = Npp;
result.periodic.Nspec = Nspec;
result.periodic.spectralBW = acq.spectralBW;
result.periodic.spectralResolution = acq.spectralResolution;
result.periodic.closure = check_periodic_closure(result.ktraj_actual, result.G, result.opts);
full = expand_periodic_readout(result, Nspec);

fprintf('Npp = %d, Nspec = %d, total ADC = %d\n', Npp, Nspec, acq.nADCtotal);
fprintf('Tperiod = %.3f us, spectral BW = %.3f Hz\n', acq.periodTime*1e6, acq.spectralBW);
fprintf('Spectral resolution = %.3f Hz\n', acq.spectralResolution);
fprintf('max |G| axis = %.3f mT/m\n', max(abs(result.G(:)))*1e3);
fprintf('max |S| axis = %.3f T/m/s\n', max(abs(result.S(:))));
fprintf('period dk from gradient moment = %.6g cycles/m\n', result.periodic.closure.deltaKFromMomentNorm);
