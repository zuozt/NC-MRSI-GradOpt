function opts = parse_options(sys, acq, opt)
%PARSE_OPTIONS Merge system, acquisition, and optimization options.
if nargin < 2 || isempty(acq)
    acq = struct();
end
if nargin < 3 || isempty(opt)
    opt = struct();
end

requiredSys = {'Gmax','Smax','dtGrad','gammaBar'};
for i = 1:numel(requiredSys)
    if ~isfield(sys, requiredSys{i}) || isempty(sys.(requiredSys{i}))
        error('sys.%s is required.', requiredSys{i});
    end
end

opts = struct();
opts.Gmax = sys.Gmax;
opts.Smax = sys.Smax;
opts.dtGrad = sys.dtGrad;
opts.gammaBar = sys.gammaBar;

opts.nADC = getfield_default(acq, 'nADC', []);
opts.spectralBW = getfield_default(acq, 'spectralBW', []);
opts.dtADC = getfield_default(acq, 'dtADC', []);
if isempty(opts.dtADC)
    if isempty(opts.spectralBW)
        opts.dtADC = opts.dtGrad;
    else
        opts.dtADC = 1 / opts.spectralBW;
    end
end
if isempty(opts.nADC)
    opts.nADC = size_from_readout(acq, opts.dtADC, opts.dtGrad);
end
opts.readoutTime = getfield_default(acq, 'readoutTime', opts.nADC * opts.dtADC);
opts.adcDelay = getfield_default(acq, 'adcDelay', 0);
opts.adcStartMode = getfield_default(acq, 'adcStartMode', 'start');

opts.mode = getfield_default(opt, 'mode', 'fixed_duration');
opts.symmetry = getfield_default(opt, 'symmetry', 'none');
opts.periodic = getfield_default(opt, 'periodic', false) || strcmpi(opts.mode, 'periodic_fixed');

% Periodic MRSI requires more than k-space closure.  The repeated
% compact gradient period should be C1-like at the cyclic boundary: the end
% of one period and the start of the next period must be continuous in
% gradient amplitude, and the boundary slew should be continuous with the
% adjacent slew samples.  These conditions may make the actual k trajectory
% differ slightly from the analytical PETALUTE target, but they avoid a
% hardware-discontinuous periodic readout.
if opts.periodic
    defaultForceStartZero = false;
    defaultForceEndZero = false;
    defaultForcePeriodicEqual = true;      % G(end) = G(1)
    defaultForceSlewPeriodicEqual = true;  % dG/dt(end) = dG/dt(start)
    defaultLambdaSlew = 1e-8;
    defaultLambdaSmooth = 1e-12;
else
    defaultForceStartZero = true;
    defaultForceEndZero = true;
    defaultForcePeriodicEqual = false;
    defaultForceSlewPeriodicEqual = false;
    defaultLambdaSlew = 1e-8;
    defaultLambdaSmooth = 1e-12;
end
opts.forceGStartZero = getfield_default(opt, 'forceGStartZero', defaultForceStartZero);
opts.forceGEndZero = getfield_default(opt, 'forceGEndZero', defaultForceEndZero);
opts.forceGPeriodicEqual = getfield_default(opt, 'forceGPeriodicEqual', defaultForcePeriodicEqual);
opts.forceSlewPeriodicEqual = getfield_default(opt, 'forceSlewPeriodicEqual', defaultForceSlewPeriodicEqual);
opts.safetyMargin = getfield_default(opt, 'safetyMargin', 0.95);
opts.lambdaSlew = getfield_default(opt, 'lambdaSlew', defaultLambdaSlew);
opts.lambdaSmooth = getfield_default(opt, 'lambdaSmooth', defaultLambdaSmooth);
opts.optimizerDisplay = getfield_default(opt, 'optimizerDisplay', 'off');
opts.fallbackIterations = getfield_default(opt, 'fallbackIterations', 20);
opts.maxControlPoints = getfield_default(opt, 'maxControlPoints', 2048);
opts.resampleMethod = getfield_default(opt, 'resampleMethod', 'linear');
opts.k0 = getfield_default(opt, 'k0', []);
opts.verbose = getfield_default(opt, 'verbose', true);
opts.Npp = getfield_default(acq, 'Npp', []);
if isempty(opts.Npp)
    opts.Npp = getfield_default(opt, 'Npp', []);
end
opts.Guse = opts.Gmax * opts.safetyMargin;
opts.Suse = opts.Smax * opts.safetyMargin;

if opts.Guse <= 0 || opts.Suse <= 0 || opts.dtGrad <= 0 || opts.gammaBar <= 0
    error('Gmax, Smax, dtGrad, and gammaBar must be positive.');
end
if opts.dtADC <= 0 || opts.nADC < 1 || opts.readoutTime <= 0
    error('Invalid ADC timing.');
end

if opts.periodic
    if isempty(opts.Npp)
        opts.Npp = opts.nADC;
    end
    opts.Npp = round(opts.Npp);
    opts.nGrad = opts.Npp;
    opts.nADC = opts.Npp;
    % One compact periodic interval contains Npp gradient/ADC samples.
    % The repeated waveform period is Npp*dtGrad; the Npp-th gradient
    % interval closes the trajectory to the first sample of the next period.
    opts.readoutTime = opts.Npp * opts.dtGrad;
else
    opts.nGrad = round(opts.readoutTime / opts.dtGrad) + 1;
    opts.readoutTime = (opts.nGrad - 1) * opts.dtGrad;
end
end

function value = getfield_default(s, name, defaultValue)
if isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
else
    value = defaultValue;
end
end

function nADC = size_from_readout(acq, dtADC, dtGrad)
if isfield(acq, 'readoutTime') && ~isempty(acq.readoutTime)
    nADC = floor(acq.readoutTime / dtADC) + 1;
else
    nADC = 1024;
    warning('acq.nADC was not provided. Defaulting to 1024 ADC samples.');
end
if isempty(dtADC)
    dtADC = dtGrad;
end
end
