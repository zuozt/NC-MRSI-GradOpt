%% Example: Pulseq export fallback
clear; clc;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(rootDir));

sys.Gmax = 80e-3;
sys.Smax = 200;
sys.dtGrad = 10e-6;
sys.gammaBar = 17.235e6;
acq = setup_mrsi_readout(512, 5000);
opt.mode = 'fixed_duration';
opt.forceGStartZero = true;
opt.forceGEndZero = true;

params.N = acq.nADC;
params.Kmax = 60;
params.nRadial = 3;
params.nAngular = 1;
ktraj = make_rosette_2d(params);

result = nc_mrsi_gradopt(ktraj, sys, acq, opt);
export_pulseq(result, fullfile(rootDir, 'examples', 'demo_rosette.seq'));
