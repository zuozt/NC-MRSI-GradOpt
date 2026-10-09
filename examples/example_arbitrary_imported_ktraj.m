%% Example: arbitrary imported k-space trajectory
clear; clc;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(rootDir));

% Replace this with your own CSV/TXT/MAT file.
% ktraj = import_ktraj('my_ktraj.csv');

% Demonstration target: spiral
params.N = 1024;
params.Kmax = 80;
params.nTurns = 5;
ktraj = make_spiral(params);

sys.Gmax = 40e-3;
sys.Smax = 150;
sys.dtGrad = 10e-6;
sys.gammaBar = 42.576e6;   % Hz/T for 1H

acq = setup_mrsi_readout(1024, 4000);
opt.mode = 'fixed_duration';
opt.symmetry = 'none';
opt.safetyMargin = 0.95;
opt.forceGStartZero = true;
opt.forceGEndZero = true;

result = nc_mrsi_gradopt(ktraj, sys, acq, opt);
plot_gradopt_result(result);
