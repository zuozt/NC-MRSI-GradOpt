%% Example: complete proton CRT ring set for periodic MRSI
% Every ring is an independent compact-period module with Npp samples.
% Six rings therefore give six optimized 128-sample modules, not one shared
% 128-sample period.

clear; clc;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(rootDir));

% Periodic MRSI timing
Npp      = 128;       % samples PER RING / compact spatial period
Nspec    = 512;       % repeated periods / spectral points
adcDwell = 5e-6;      % s

% Hardware system
sys.Gmax     = 20e-3;       % T/m; use 20 mT/m for a conservative CRT test
sys.Smax     = 180;         % T/m/s
sys.dtGrad   = adcDwell;    % s
sys.gammaBar = 42.57747892e6; % 1H, cycles/s/T

% Acquisition structure
acq = setup_periodic_mrsi_readout(Npp, Nspec, adcDwell);

% FOV/resolution-derived CRT parameters
FOV_m = 0.240;             % m
resolution_m = 0.020;      % m
Kmax = 1/(2*resolution_m); % cycles/m, 25 for 20 mm
dk = 1/FOV_m;              % cycles/m
nRings = round(Kmax/dk);   % about 6 rings

% Complete multi-ring-set definition
p = struct();
p.Npp = Npp;
p.Kmax = Kmax;
p.nRings = nRings;
p.rMin = dk;
p.nTurnsPerRing = 1;
p.phase = 0;
p.mode = 'multi_ring_set';
crtTargets = make_concentric_crt_set(p);
assert(crtTargets.NppPerRing == Npp);
assert(crtTargets.totalSpatialSamples == nRings*Npp);

% Periodic fixed-duration optimization
opt = struct();
opt.mode = 'periodic_fixed';
opt.periodic = true;
opt.symmetry = 'none';
opt.safetyMargin = 0.95;
opt.maxControlPoints = 256;
opt.lambdaSlew = 0;
opt.lambdaSmooth = 0;
opt.forceGStartZero = false;
opt.forceGEndZero = false;
opt.forceGPeriodicEqual = false;
opt.forceSlewPeriodicEqual = false;
opt.optimizerDisplay = 'off';

setOpts = struct();
setOpts.usePreGradient = true;
setOpts.preGradientSamples = 0; % automatic length, independently per ring
setOpts.Nspec = Nspec;

result = optimize_concentric_crt_set(p, sys, acq, opt, setOpts);
disp(result.summary);

% Inspect the outer ring with the standard result plotter.
plot_gradopt_result(result.rings(end));

% Save one structure containing every target, optimized period, pre-gradient,
% expanded readout, and aggregate feasibility summary.
outFile = fullfile(rootDir, 'examples', 'gradopt_periodic_crt_multi_ring_set_1H_result.mat');
save(outFile, 'result', 'crtTargets', 'p', 'sys', 'acq', 'opt', 'setOpts');
fprintf('Saved complete proton CRT ring-set result: %s\n', outFile);
