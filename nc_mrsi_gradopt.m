function result = nc_mrsi_gradopt(ktraj_target, sys, acq, opt)
%NC_MRSI_GRADOPT Optimize gradient waveforms for non-Cartesian MRSI.
%
% result = nc_mrsi_gradopt(ktraj_target, sys, acq, opt)
%
% Inputs
%   ktraj_target : [N x D] target k-space trajectory, D=1/2/3, cycles/m.
%                  For fixed-duration MRSI, N may be ADC points or gradient
%                  raster points; it will be resampled to the gradient raster.
%   sys          : hardware structure
%       .Gmax       maximum gradient amplitude, T/m
%       .Smax       maximum slew rate, T/m/s
%       .dtGrad     gradient raster time, s
%       .gammaBar   gamma / 2pi, Hz/T
%   acq          : MRSI acquisition structure
%       .nADC         number of ADC samples
%       .dtADC        ADC dwell time, s
%       .spectralBW   spectral bandwidth, Hz; used if dtADC is absent
%       .readoutTime  readout duration, s; used if present
%   opt          : optimization options structure
%       .mode         'direct', 'fixed_duration', or 'symmetric_fixed'
%       .symmetry     'none', 'antisymmetric_k', or 'even_k'
%       .safetyMargin default 0.95
%       .lambdaSlew   smoothness weight for first difference
%       .lambdaSmooth smoothness weight for second difference
%
% Outputs
%   result.G              [M x D] gradient waveform, T/m
%   result.S              [M-1 x D] slew waveform, T/m/s
%   result.ktraj_actual   [M x D] actual k-space trajectory, cycles/m
%   result.ktraj_target   [M x D] target trajectory on gradient raster
%   result.ktraj_adc      [nADC x D] actual trajectory sampled at ADC times
%   result.report         constraint and error report
%
% Notes
%   This first release focuses on fixed-duration MRSI optimization. It uses
%   component-wise gradient and slew constraints. Vector-norm constraints can
%   be added through nonlinear or conic solvers if required.

if nargin < 2
    error('At least ktraj_target and sys are required.');
end
if nargin < 3 || isempty(acq)
    acq = struct();
end
if nargin < 4 || isempty(opt)
    opt = struct();
end

opts = parse_options(sys, acq, opt);
ktraj_target = validate_ktraj_input(ktraj_target);
ktraj_grad = preprocess_ktraj(ktraj_target, opts);

if opts.periodic || strcmpi(opts.mode, 'periodic_fixed')
    % Periodic MRSI: optimize exactly one compact period. Do not treat the
    % repeated FID readout as a long non-periodic trajectory.
    G = periodic_fixed_duration_optimize(ktraj_grad, opts);
else
    switch lower(opts.mode)
        case 'direct'
            G = k2grad_direct(ktraj_grad, opts);
        case 'fixed_duration'
            G = fixed_duration_optimize(ktraj_grad, opts);
        case 'symmetric_fixed'
            G = symmetric_fixed_duration_optimize(ktraj_grad, opts);
        otherwise
            error('Unknown opt.mode: %s', opts.mode);
    end

    G = enforce_boundary_conditions(G, opts);
    if ~strcmpi(opts.symmetry, 'none') && contains(lower(opts.mode), 'symmetric')
        G = enforce_gradient_symmetry(G, opts.symmetry);
    end
end

if opts.periodic || strcmpi(opts.mode, 'periodic_fixed')
    S = compute_cyclic_slew(G, opts.dtGrad);
    ktraj_actual = integrate_periodic_gradient_samples(G, opts, ktraj_grad(1,:));
else
    S = compute_slew(G, opts.dtGrad);
    ktraj_actual = integrate_gradient(G, opts, ktraj_grad(1,:));
end
ktraj_adc = sample_ktraj_at_adc(ktraj_actual, opts);
report = validate_solution(G, S, ktraj_actual, ktraj_grad, opts);

result = struct();
result.G = G;
result.S = S;
result.ktraj_actual = ktraj_actual;
result.ktraj_target = ktraj_grad;
result.ktraj_adc = ktraj_adc;
result.time_grad = (0:size(G,1)-1).' * opts.dtGrad;
result.time_adc = opts.adcDelay + (0:opts.nADC-1).' * opts.dtADC;
result.opts = opts;
result.report = report;
end
