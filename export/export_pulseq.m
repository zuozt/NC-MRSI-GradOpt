function info = export_pulseq(result, filename, seqOpts)
%EXPORT_PULSEQ Export arbitrary gradients to a Pulseq sequence if available.
%
% Periodic results with one gradient raster per ADC dwell are converted to
% the ADC-centred Pulseq model by prepare_periodic_pulseq_module. Other
% results use the legacy block layout with corrected T/m -> Hz/m units.

if nargin < 3
    seqOpts = struct();
end
if exist('mr.Sequence', 'class') ~= 8 && exist('mr.Sequence', 'file') ~= 2
    warning('Pulseq MATLAB toolbox was not found. Exporting CSV fallback instead.');
    [p,n,~] = fileparts(filename);
    if isempty(p); p = pwd; end
    export_csv(result, fullfile(p, [n '_pulseq_fallback.csv']));
    info = struct('filename','','fallbackCSV',fullfile(p,[n '_pulseq_fallback.csv']));
    return;
end

% Preferred periodic path: preserve target positions at physical ADC centres.
isPeriodic = isfield(result,'opts') && isfield(result.opts,'periodic') && ...
    logical(result.opts.periodic);
if isPeriodic && isfield(result.opts,'dtADC') && ...
        abs(result.opts.dtADC-result.opts.dtGrad) <= max(1e-12,1e-9*result.opts.dtGrad) && ...
        result.opts.nADC == size(result.G,1)
    moduleOpts = getp(seqOpts,'moduleOpts',struct());
    module = prepare_periodic_pulseq_module(result,moduleOpts);
    repeats = getp(seqOpts,'repeats',1);
    info = write_periodic_pulseq_module(module,result,filename,repeats,seqOpts);
    info.module = module;
    return;
end

gammaBar = result.opts.gammaBar;
sys = mr.opts('MaxGrad', result.opts.Gmax, 'GradUnit', 'T/m', ...
    'MaxSlew', result.opts.Smax, 'SlewUnit', 'T/m/s', ...
    'gradRasterTime', result.opts.dtGrad, ...
    'blockDurationRaster',result.opts.dtGrad,'gamma',gammaBar);
seq = mr.Sequence(sys);

% Optional pre-gradient outside ADC. It starts at G=0 and ends at the first
% readout gradient. It also prephases from k=0 to the ring start k position.
if isfield(result,'pre') && isstruct(result.pre) && isfield(result.pre,'G') && ~isempty(result.pre.G)
    Gpre = pad3(result.pre.G);
    Gpre = gammaBar*Gpre;
    gxPre = mr.makeArbitraryGrad('x', Gpre(:,1), 'system', sys);
    gyPre = mr.makeArbitraryGrad('y', Gpre(:,2), 'system', sys);
    gzPre = mr.makeArbitraryGrad('z', Gpre(:,3), 'system', sys);
    seq.addBlock(gxPre, gyPre, gzPre);
end

G = pad3(result.G);
G = gammaBar*G;
gx = mr.makeArbitraryGrad('x', G(:,1), 'system', sys);
gy = mr.makeArbitraryGrad('y', G(:,2), 'system', sys);
gz = mr.makeArbitraryGrad('z', G(:,3), 'system', sys);

% If a separate pre-gradient block exists, ADC starts with the readout block.
% Otherwise retain the user-provided ADC delay.
adcDelay = result.opts.adcDelay;
if isfield(result,'pre') && isstruct(result.pre) && isfield(result.pre,'G') && ~isempty(result.pre.G)
    adcDelay = 0;
end
adc = mr.makeAdc(result.opts.nADC, 'Dwell', result.opts.dtADC, 'Delay', adcDelay, 'system', sys);
seq.addBlock(gx, gy, gz, adc);
compatibility = lower(getp(seqOpts,'compatibility','1.4.1'));
if any(strcmp(compatibility,{'1.4.1','v1.4.1','141'}))
    seq.write_v141(filename);
    fileFormat='1.4.1';
else
    seq.write(filename);
    fileFormat='current';
end
info = struct('filename',filename,'fileFormat',fileFormat, ...
    'gammaBar',gammaBar,'unitConversion','T/m multiplied by gammaBar to Hz/m');
fprintf('Exported Pulseq sequence: %s\n', filename);
end

function G3 = pad3(G)
G3 = G;
if size(G3,2) < 3
    G3(:,end+1:3) = 0;
end
end

function v=getp(s,name,defaultValue)
if isfield(s,name) && ~isempty(s.(name))
    v=s.(name);
else
    v=defaultValue;
end
end
