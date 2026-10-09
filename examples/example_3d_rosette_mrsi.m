%% Example: 3D rosette/petal fixed-duration MRSI gradient optimization
clear; clc;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(rootDir));

sys.Gmax = 80e-3;          % T/m
sys.Smax = 200;            % T/m/s
sys.dtGrad = 10e-6;        % s
sys.gammaBar = 17.235e6;   % Hz/T for 31P

acq = setup_mrsi_readout(1024, 5000);

opt.mode = 'symmetric_fixed';
opt.symmetry = 'antisymmetric_k';
opt.forceGStartZero = true;
opt.forceGEndZero = true;
opt.safetyMargin = 0.95;
opt.lambdaSlew = 1e-8;
opt.lambdaSmooth = 1e-12;

params.N = acq.nADC;
params.Kmax = 100;
params.nRadial = 4;
params.nAngular = 1;
params.phi = pi/9;
ktraj = make_rosette_3d(params);

base = design_single_petal(ktraj, sys, acq, opt);
disp(base.report);

% Generate rotated petals from a single optimized base waveform.
nPetals = 8;
R = zeros(3,3,nPetals);
for p = 1:nPetals
    R(:,:,p) = make_rotation_z(2*pi*(p-1)/nPetals);
end
petals = generate_multipetal_readout(base, R);

plot_gradopt_result(base);
export_siemens_idea_txt(base, fullfile(rootDir, 'examples', 'idea_export_base_petal'));
