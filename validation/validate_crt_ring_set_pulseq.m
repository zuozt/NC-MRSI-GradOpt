function validation = validate_crt_ring_set_pulseq(resultSet, manifest, validationOpts)
%VALIDATE_CRT_RING_SET_PULSEQ Validate all exported CRT compact/full files.
%
% Files written in manifest.outputDir:
%   crt_pulseq_roundtrip_summary.csv
%   crt_pulseq_roundtrip_details.mat
%   crt_pulseq_roundtrip_report.txt

if nargin < 3 || isempty(validationOpts)
    validationOpts = struct();
end
if ~isfield(resultSet,'isCrtRingSet') || ~resultSet.isCrtRingSet
    error('resultSet must be a CRT multi_ring_set result.');
end

nRings = resultSet.nRings;
details = repmat(struct('ringIndex',0,'radius_cpm',0, ...
    'compact',struct(),'full',struct()),nRings,1);
for rr = 1:nRings
    details(rr).ringIndex = rr;
    details(rr).radius_cpm = resultSet.radii(rr);
    if ~isempty(manifest.compactFiles{rr})
        details(rr).compact = validate_periodic_pulseq_roundtrip( ...
            manifest.compactFiles{rr},manifest.modules(rr), ...
            manifest.compactInfo(rr),validationOpts);
    end
    if ~isempty(manifest.fullFiles{rr})
        details(rr).full = validate_periodic_pulseq_roundtrip( ...
            manifest.fullFiles{rr},manifest.modules(rr), ...
            manifest.fullInfo(rr),validationOpts);
    end
end

compactPass = arrayfun(@(x) report_pass(x.compact),details);
fullPass = arrayfun(@(x) report_pass(x.full),details);
compactExported = ~cellfun(@isempty,manifest.compactFiles);
fullExported = ~cellfun(@isempty,manifest.fullFiles);
validation = struct();
validation.kind = 'CRT Pulseq write-read round-trip validation';
validation.details = details;
validation.compactPass = compactPass(:);
validation.fullPass = fullPass(:);
validation.compactExported = compactExported(:);
validation.fullExported = fullExported(:);
validation.allCompactPass = all(compactPass(compactExported));
validation.allFullPass = all(fullPass(fullExported));
validation.overallPass = validation.allCompactPass && validation.allFullPass;
validation.summaryCSV = fullfile(manifest.outputDir,'crt_pulseq_roundtrip_summary.csv');
validation.detailsMAT = fullfile(manifest.outputDir,'crt_pulseq_roundtrip_details.mat');
validation.reportTXT = fullfile(manifest.outputDir,'crt_pulseq_roundtrip_report.txt');

write_summary_csv(validation.summaryCSV,details);
save(validation.detailsMAT,'validation','manifest','-v7.3');
write_report(validation.reportTXT,validation,resultSet,manifest);
end

function tf=report_pass(s)
tf = isstruct(s) && isfield(s,'overallPass') && logical(s.overallPass);
end

function write_summary_csv(filename,details)
fid=fopen(filename,'w');
assert(fid~=-1,'Cannot open summary CSV: %s',filename);
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,['ring_index,radius_cpm,kind,repeats,Npp,expected_adc,read_adc,' ...
    'timing_pass,waveform_error_Tm,waveform_pass,k_rms_error_cpm,' ...
    'k_max_error_cpm,kspace_pass,closure_error_cpm,closure_pass,' ...
    'module_return_error_cpm,return_pass,' ...
    'period_time_error_s,fixed_timing_pass,duration_error_s,' ...
    'max_g_axis_Tm,max_s_axis_Tms,hardware_pass,module_pass,' ...
    'readout_pass,overall_pass\n']);
for rr=1:numel(details)
    write_row(fid,details(rr).ringIndex,details(rr).radius_cpm,'compact',details(rr).compact);
    write_row(fid,details(rr).ringIndex,details(rr).radius_cpm,'full',details(rr).full);
end
end

function write_row(fid,ringIndex,radius,kind,r)
if ~isstruct(r) || ~isfield(r,'overallPass')
    return;
end
fprintf(fid,['%d,%.12g,%s,%d,%d,%d,%d,%d,%.12g,%d,%.12g,%.12g,%d,' ...
    '%.12g,%d,%.12g,%d,%.12g,%d,%.12g,"%s","%s",%d,%d,%d,%d\n'], ...
    ringIndex,radius,kind,r.repeats,r.Npp,r.expectedADCSamples, ...
    r.readADCSamples,r.timingCheckPass,r.maxWaveformDifference_Tm, ...
    r.waveformPass,r.kTrajectoryRMSError_cpm,r.kTrajectoryMaxError_cpm, ...
    r.kspacePass,r.closureError_cpm,r.closurePass, ...
    r.moduleReturnError_cpm,r.returnPass,r.periodTimeError_s, ...
    r.fixedTimingPass,r.durationError_s,vecstr(r.maxGradientAxis_Tm), ...
    vecstr(r.maxSlewAxis_Tms),r.hardwarePass,r.modulePass, ...
    r.readoutPass,r.overallPass);
end

function write_report(filename,validation,resultSet,manifest)
fid=fopen(filename,'w');
assert(fid~=-1,'Cannot open report: %s',filename);
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'NC-MRSI-GradOpt CRT Pulseq round-trip report\n');
fprintf(fid,'================================================\n');
fprintf(fid,'Rings: %d\n',resultSet.nRings);
fprintf(fid,'Samples per ring: %d\n',resultSet.NppPerRing);
fprintf(fid,'Full-FID repeats: %d\n',manifest.fullRepeats);
fprintf(fid,'Compact files pass: %d/%d\n',sum(validation.compactPass),resultSet.nRings);
fprintf(fid,'Full-FID files pass: %d/%d\n',sum(validation.fullPass),resultSet.nRings);
fprintf(fid,'Overall pass: %d\n\n',validation.overallPass);
for rr=1:resultSet.nRings
    fprintf(fid,'Ring %d, radius %.6f cycles/m\n',rr,resultSet.radii(rr));
    print_one(fid,'compact',validation.details(rr).compact);
    print_one(fid,'full',validation.details(rr).full);
end
end

function print_one(fid,label,r)
if ~isstruct(r) || ~isfield(r,'overallPass')
    fprintf(fid,'  %-8s not exported\n',label);
    return;
end
fprintf(fid,['  %-8s pass=%d, ADC=%d/%d, timing=%d, ' ...
    'dG=%.3g T/m, kRMS=%.3g c/m, kMax=%.3g c/m, closure=%.3g c/m, return=%.3g c/m\n'], ...
    label,r.overallPass,r.readADCSamples,r.expectedADCSamples, ...
    r.timingCheckPass,r.maxWaveformDifference_Tm, ...
    r.kTrajectoryRMSError_cpm,r.kTrajectoryMaxError_cpm, ...
    r.closureError_cpm,r.moduleReturnError_cpm);
end

function s=vecstr(v)
s=sprintf('%.12g;',v);
if ~isempty(s); s(end)=[]; end
end
