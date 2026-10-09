function report = validate_periodic_pulseq_roundtrip(filename, module, writeInfo, validationOpts)
%VALIDATE_PERIODIC_PULSEQ_ROUNDTRIP Read a .seq back and verify its physics.
%
% The validation uses Pulseq's own Sequence.read, checkTiming,
% waveforms_and_times, and calculateKspacePP implementations.

if nargin < 4 || isempty(validationOpts)
    validationOpts = struct();
end
require_pulseq();

% Pulseq 1.4.1 stores decimal text and quantized compressed shapes.  These
% defaults cover serialization error while remaining far below one spatial
% encoding step.  Callers may still override every tolerance.
tolG = getp(validationOpts,'tolG_Tm',2e-8);
tolK = getp(validationOpts,'tolK_cpm',1e-3);
tolClosure = getp(validationOpts,'tolClosure_cpm',1e-3);
tolReturn = getp(validationOpts,'tolReturn_cpm',tolClosure);
tolDuration = getp(validationOpts,'tolDuration_s',1e-9);
tolTiming = getp(validationOpts,'tolPeriod_s',1e-10);

seqRead = mr.Sequence(writeInfo.sys);
seqRead.read(filename);
[timingOK,timingErrors] = seqRead.checkTiming;
[waveData,~,~,tAdc] = seqRead.waveforms_and_times();
[kAdc,tAdcK,kContinuous,~] = seqRead.calculateKspacePP();
[durationRead,nBlocks] = seqRead.duration();

tAdc = tAdc(:).';
tAdcK = tAdcK(:).';
if numel(tAdc) ~= numel(tAdcK) || ...
        (~isempty(tAdc) && max(abs(tAdc-tAdcK)) > 1e-12)
    error('Pulseq ADC time outputs are inconsistent.');
end

repeats = writeInfo.repeats;
Npp = module.Npp;
expectedCount = Npp*repeats;
expectedK = repmat(module.kAdcReference.',1,repeats);
expectedG = repmat(module.Gread.',1,repeats);

GreadAtAdc = zeros(3,numel(tAdc));
for aa = 1:3
    if isempty(waveData{aa})
        continue;
    end
    GreadAtAdc(aa,:) = interp1(waveData{aa}(1,:),waveData{aa}(2,:), ...
        tAdc,'linear')/module.gammaBar;
end

adcCountPass = numel(tAdc)==expectedCount;
if adcCountPass
    dG = GreadAtAdc-expectedG;
    dk = kAdc-expectedK;
    maxWaveformDifference = max(abs(dG(:)));
    kRmsError = sqrt(mean(dk(:).^2));
    kMaxError = max(abs(dk(:)));

    tMatrix = reshape(tAdc,Npp,repeats);
    withinPeriod = diff(tMatrix,1,1);
    fixedDwellError = max(abs(withinPeriod(:)-module.dtADC));
    if repeats>1
        periodStarts = tMatrix(1,:);
        periodTimeError = max(abs(diff(periodStarts)-Npp*module.dtADC));
        kStartMatrix = reshape(kAdc(:,1:Npp*repeats),3,Npp,repeats);
        firstSamples = reshape(kStartMatrix(:,1,:),3,repeats);
        closureError = max(max(abs(firstSamples-firstSamples(:,1))));
        repeatDelta = abs(kStartMatrix-repmat(kStartMatrix(:,:,1),1,1,repeats));
        repeatError = max(repeatDelta(:));
    else
        periodTimeError = 0;
        if isfield(module,'GreadEdge') && size(module.GreadEdge,1)==Npp+1
            q = module.GreadEdge;
            closingStep = module.gammaBar*module.dtGrad .* ...
                (q(end-1,:)+6*q(1,:)+q(2,:)) ./ 8;
            closureError = max(abs(module.kAdcReference(end,:) + ...
                closingStep - module.kAdcReference(1,:)));
        else
            % Backward compatibility for centre-sampled arbitrary gradients.
            closureError = norm((module.kAdcReference(end,:) + ...
                0.5*module.gammaBar*module.dtGrad* ...
                (module.Gread(end,:)+module.Gread(1,:))) - ...
                module.kAdcReference(1,:));
        end
        repeatError = 0;
    end
else
    maxWaveformDifference = inf;
    kRmsError = inf;
    kMaxError = inf;
    fixedDwellError = inf;
    periodTimeError = inf;
    closureError = inf;
    repeatError = inf;
end

[maxGAxis,maxSAxis] = waveform_limits(waveData,module.gammaBar);
hardwarePass = all(maxGAxis <= writeInfo.sys.maxGrad/module.gammaBar*(1+1e-8)) && ...
    all(maxSAxis <= writeInfo.sys.maxSlew/module.gammaBar*(1+1e-8));
durationError = abs(durationRead-writeInfo.totalDuration);
if isempty(kContinuous)
    moduleReturnError = inf;
else
    moduleReturnError = norm(kContinuous(:,end));
end

waveformPass = maxWaveformDifference <= tolG;
kspacePass = kMaxError <= tolK;
closurePass = closureError <= tolClosure;
returnPass = moduleReturnError <= tolReturn;
fixedTimingPass = fixedDwellError <= tolTiming && periodTimeError <= tolTiming;
durationPass = durationError <= tolDuration;
modulePass = timingOK && waveformPass && fixedTimingPass && durationPass;
readoutPass = adcCountPass && kspacePass && closurePass;
overallPass = modulePass && readoutPass && hardwarePass && returnPass;

report = struct();
report.filename = filename;
report.fileFormat = writeInfo.fileFormat;
report.repeats = repeats;
report.Npp = Npp;
report.expectedADCSamples = expectedCount;
report.readADCSamples = numel(tAdc);
report.adcCountPass = adcCountPass;
report.timingCheckPass = timingOK;
report.timingErrors = timingErrors;
report.maxWaveformDifference_Tm = maxWaveformDifference;
report.waveformPass = waveformPass;
report.kTrajectoryRMSError_cpm = kRmsError;
report.kTrajectoryMaxError_cpm = kMaxError;
report.kspacePass = kspacePass;
report.closureError_cpm = closureError;
report.closurePass = closurePass;
report.moduleReturnError_cpm = moduleReturnError;
report.returnPass = returnPass;
report.repeatConsistencyError_cpm = repeatError;
report.fixedDwellError_s = fixedDwellError;
report.periodTimeError_s = periodTimeError;
report.fixedTimingPass = fixedTimingPass;
report.expectedDuration_s = writeInfo.totalDuration;
report.readDuration_s = durationRead;
report.durationError_s = durationError;
report.durationPass = durationPass;
report.maxGradientAxis_Tm = maxGAxis;
report.maxSlewAxis_Tms = maxSAxis;
report.hardwarePass = hardwarePass;
report.modulePass = modulePass;
report.readoutPass = readoutPass;
report.overallPass = overallPass;
report.numBlocks = nBlocks;
report.tolerances = struct('G_Tm',tolG,'K_cpm',tolK, ...
    'closure_cpm',tolClosure,'return_cpm',tolReturn, ...
    'duration_s',tolDuration,'period_s',tolTiming);
end

function [maxG,maxS] = waveform_limits(waveData,gammaBar)
maxG = zeros(1,3);
maxS = zeros(1,3);
for aa = 1:3
    w = waveData{aa};
    if isempty(w)
        continue;
    end
    maxG(aa) = max(abs(w(2,:)))/gammaBar;
    dt = diff(w(1,:));
    dg = diff(w(2,:))/gammaBar;
    keep = dt>1e-15;
    if any(keep)
        maxS(aa) = max(abs(dg(keep)./dt(keep)));
    end
end
end

function require_pulseq()
if exist('mr.Sequence','class') ~= 8 && exist('mr.Sequence','file') ~= 2
    error('Pulseq MATLAB was not found. Run startup_nc_mrsi_gradopt first.');
end
end

function v=getp(s,name,defaultValue)
if isfield(s,name) && ~isempty(s.(name))
    v=s.(name);
else
    v=defaultValue;
end
end
