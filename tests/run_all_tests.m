%% Run basic NC-MRSI-GradOpt tests
clear; clc;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(rootDir));

test_direct_k2grad;
test_gradient_limits;
test_symmetric_constraint;
test_fixed_duration_solver;
test_petal_rotation_consistency;
test_concentric_crt_trajectory;
test_crt_complete_module;
test_pulseq_adc_centered_conversion;

disp('All basic tests finished.');
