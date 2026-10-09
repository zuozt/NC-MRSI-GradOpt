%% Example: six-ring CRT compact/full-FID Pulseq round-trip
clear; clc;
rootDir=fileparts(fileparts(mfilename('fullpath')));
addpath(rootDir);
startup_nc_mrsi_gradopt;

% Point this to the v0.3.4/v0.3.5 multi_ring_set result produced by the GUI.
resultFile=fullfile(rootDir,'examples','gradopt_periodic_mrsi_CRT_multi_ring_result.mat');
if exist(resultFile,'file')~=2
    error(['Copy gradopt_periodic_mrsi_CRT_multi_ring_result.mat into examples/, ' ...
        'or edit resultFile in this script.']);
end
S=load(resultFile);
resultSet=S.result;

outputDir=fullfile(rootDir,'examples','pulseq_export');
seqOpts=struct();
seqOpts.compatibility='1.4.1';
seqOpts.fullRepeats=512;
seqOpts.exportCompact=true;
seqOpts.exportFull=true;

[compactFiles,manifest]=export_crt_ring_set_pulseq( ...
    resultSet,outputDir,'CRT_1H',seqOpts); %#ok<ASGLU>
validation=validate_crt_ring_set_pulseq(resultSet,manifest);

fprintf('All compact files pass: %d\n',validation.allCompactPass);
fprintf('All full-FID files pass: %d\n',validation.allFullPass);
fprintf('Overall round-trip pass: %d\n',validation.overallPass);
