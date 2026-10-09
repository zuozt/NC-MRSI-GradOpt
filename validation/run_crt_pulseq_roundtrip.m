function output = run_crt_pulseq_roundtrip(resultInput, outputDir, seqOpts, validationOpts)
%RUN_CRT_PULSEQ_ROUNDTRIP One-command CRT export and write-read validation.
%
% output = run_crt_pulseq_roundtrip(resultInput, outputDir)
%
% resultInput may be:
%   - a multi_ring_set result structure, or
%   - a MAT filename containing variable result.

if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(pwd,'pulseq_export');
end
if nargin < 3 || isempty(seqOpts)
    seqOpts = struct();
end
if nargin < 4 || isempty(validationOpts)
    validationOpts = struct();
end

if ischar(resultInput) || (isstring(resultInput) && isscalar(resultInput))
    S=load(char(resultInput));
    if ~isfield(S,'result')
        error('MAT file must contain variable result.');
    end
    resultSet=S.result;
elseif isstruct(resultInput)
    resultSet=resultInput;
else
    error('resultInput must be a result structure or MAT filename.');
end

if ~isfield(seqOpts,'compatibility')
    seqOpts.compatibility='1.4.1';
end
gammaBar=resultSet.rings(1).opts.gammaBar;
if abs(gammaBar-42.5774789e6)/42.5774789e6<0.01
    baseName='CRT_1H';
elseif abs(gammaBar-17.235e6)/17.235e6<0.01
    baseName='CRT_31P';
else
    baseName='CRT';
end
if isfield(seqOpts,'baseName') && ~isempty(seqOpts.baseName)
    baseName=seqOpts.baseName;
end

[compactFiles,manifest]=export_crt_ring_set_pulseq( ...
    resultSet,outputDir,baseName,seqOpts);
validation=validate_crt_ring_set_pulseq(resultSet,manifest,validationOpts);

output=struct();
output.compactFiles=compactFiles;
output.manifest=manifest;
output.validation=validation;
fprintf('CRT Pulseq overall round-trip pass: %d\n',validation.overallPass);
end
