%% Example: periodic 3D rosette MRSI API workflow, v0.2.8
clear; clc;
startup_nc_mrsi_gradopt;

Npp = 96;
Nspec = 512;
adcDwell = 5e-6;

sys = struct();
sys.Gmax = 80e-3;
sys.Smax = 200;
sys.dtGrad = adcDwell;
sys.gammaBar = 17.235e6;  % 31P, cycles/s/T

acq = setup_periodic_mrsi_readout(Npp, Nspec, adcDwell);

params = struct();
params.Npp = Npp;
params.Kmax = 25;
params.phi = 0;
params.beta = 0;
params.nRadial = 1;
params.nAngular = 1;
params.shape = 'petalute_paper';
k_period = make_periodic_rosette_3d(params);

opt = struct();
opt.mode = 'periodic_fixed';
opt.periodic = true;
opt.symmetry = 'none';
opt.forceGStartZero = false;
opt.forceGEndZero = false;
opt.forceGPeriodicEqual = true;
opt.forceSlewPeriodicEqual = true;
opt.safetyMargin = 0.95;
opt.lambdaSlew = 1e-8;
opt.lambdaSmooth = 1e-12;

result = nc_mrsi_gradopt(k_period, sys, acq, opt);
result.periodic.Npp = Npp;
result.periodic.Nspec = Nspec;
result.periodic.spectralBW = acq.spectralBW;
result.periodic.spectralResolution = acq.spectralResolution;
result.periodic.closure = check_periodic_closure(result.ktraj_actual, result.G, result.opts);

fprintf('Npp = %d, Nspec = %d, total ADC = %d\n', Npp, Nspec, acq.nADCtotal);
fprintf('Tperiod = %.3f us, SBW = %.3f Hz, df = %.3f Hz\n', ...
    acq.periodTime*1e6, acq.spectralBW, acq.spectralResolution);
fprintf('max |G| axis = %.3f mT/m\n', max(abs(result.G(:)))*1e3);
fprintf('max |S| axis = %.3f T/m/s\n', max(abs(result.S(:))));
fprintf('G boundary jump = %.6g T/m\n', result.periodic.closure.GPeriodicJumpNorm);
fprintf('S boundary jump = %.6g T/m/s\n', result.periodic.closure.SlewPeriodicJumpNorm);
fprintf('k next-start error = %.6g cycles/m\n', result.periodic.closure.kNextStartErrorNorm);

plot_gradopt_result(result);
full = expand_periodic_readout(result, Nspec);
