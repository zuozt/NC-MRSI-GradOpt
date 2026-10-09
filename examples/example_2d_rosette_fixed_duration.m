%% Example: 2D rosette fixed-duration MRSI gradient optimization
clear; clc;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(rootDir));

% Hardware, example for 31P. Adjust to your scanner.
sys.Gmax = 80e-3;          % T/m
sys.Smax = 200;            % T/m/s
sys.dtGrad = 10e-6;        % s
sys.gammaBar = 17.235e6;   % Hz/T for 31P

% MRSI timing
acq = setup_mrsi_readout(1024, 5000);  % nADC, spectral BW in Hz

% Optimization options
opt.mode = 'symmetric_fixed';
opt.symmetry = 'antisymmetric_k';
opt.forceGStartZero = true;
opt.forceGEndZero = true;
opt.safetyMargin = 0.95;
opt.lambdaSlew = 1e-8;
opt.lambdaSmooth = 1e-12;

% Target trajectory
params.N = acq.nADC;
params.Kmax = 120;        % cycles/m
params.nRadial = 4;
params.nAngular = 1;
ktraj = make_rosette_2d(params);

% Optimize
result = nc_mrsi_gradopt(ktraj, sys, acq, opt);
disp(result.report);

% Plot and export
plot_gradopt_result(result);
export_csv(result, fullfile(rootDir, 'examples', 'rosette2d_result.csv'));
write_report_txt(result, fullfile(rootDir, 'examples', 'rosette2d_report.txt'));
