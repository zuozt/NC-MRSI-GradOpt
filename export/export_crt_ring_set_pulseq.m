function [compactFiles, manifest] = export_crt_ring_set_pulseq(resultSet, outputDir, baseName, seqOpts)
%EXPORT_CRT_RING_SET_PULSEQ Export compact and full-FID files for every ring.
%
% [compactFiles, manifest] = export_crt_ring_set_pulseq(...)
%
% For each independent CRT ring, this writes:
%   compact/<baseName>_ringNN_compact.seq
%   fullFID/<baseName>_ringNN_fullMMM.seq
%
% The first output remains a cell array of compact filenames for backwards
% compatibility. The second output is a manifest containing both file sets,
% prepared Pulseq modules, and write metadata.
%
% seqOpts fields:
%   .exportCompact  default true
%   .exportFull     default true
%   .fullRepeats    defaults to resultSet.rings(1).periodic.Nspec
%   .compatibility  '1.4.1' (default) or 'current'
%   .moduleOpts     options passed to prepare_periodic_pulseq_module

if nargin < 2 || isempty(outputDir)
    outputDir = pwd;
end
if nargin < 3 || isempty(baseName)
    baseName = 'crt_ring';
end
if nargin < 4
    seqOpts = struct();
end
if ~isfield(resultSet,'isCrtRingSet') || ~resultSet.isCrtRingSet
    error('resultSet must be produced by optimize_concentric_crt_set.');
end
if exist(outputDir,'dir') ~= 7
    mkdir(outputDir);
end

exportCompact = getp(seqOpts,'exportCompact',true);
exportFull = getp(seqOpts,'exportFull',true);
moduleOpts = getp(seqOpts,'moduleOpts',struct());
fullRepeats = getp(seqOpts,'fullRepeats',[]);
if isempty(fullRepeats)
    if isfield(resultSet.rings(1),'periodic') && ...
            isfield(resultSet.rings(1).periodic,'Nspec')
        fullRepeats = resultSet.rings(1).periodic.Nspec;
    else
        fullRepeats = 512;
    end
end
fullRepeats = max(1,round(fullRepeats));

compactDir = fullfile(outputDir,'compact');
fullDir = fullfile(outputDir,'fullFID');
if exportCompact && exist(compactDir,'dir')~=7; mkdir(compactDir); end
if exportFull && exist(fullDir,'dir')~=7; mkdir(fullDir); end

compactFiles = cell(resultSet.nRings,1);
fullFiles = cell(resultSet.nRings,1);
modules = [];
compactInfo = repmat(struct(),resultSet.nRings,1);
fullInfo = repmat(struct(),resultSet.nRings,1);
for rr = 1:resultSet.nRings
    moduleThis = prepare_periodic_pulseq_module(resultSet.rings(rr),moduleOpts);
    if rr==1
        modules = repmat(moduleThis,resultSet.nRings,1);
    else
        modules(rr) = moduleThis;
    end
    if exportCompact
        compactFiles{rr} = fullfile(compactDir, ...
            sprintf('%s_ring%02d_compact.seq',baseName,rr));
        infoThis = write_periodic_pulseq_module(modules(rr), ...
            resultSet.rings(rr),compactFiles{rr},1,seqOpts);
        if rr==1
            compactInfo = repmat(infoThis,resultSet.nRings,1);
        else
            compactInfo(rr) = infoThis;
        end
    end
    if exportFull
        fullFiles{rr} = fullfile(fullDir, ...
            sprintf('%s_ring%02d_full%03d.seq',baseName,rr,fullRepeats));
        infoThis = write_periodic_pulseq_module(modules(rr), ...
            resultSet.rings(rr),fullFiles{rr},fullRepeats,seqOpts);
        if rr==1
            fullInfo = repmat(infoThis,resultSet.nRings,1);
        else
            fullInfo(rr) = infoThis;
        end
    end
end

manifest = struct();
manifest.kind = 'CRT Pulseq compact/full-FID export manifest';
manifest.baseName = baseName;
manifest.outputDir = outputDir;
manifest.nRings = resultSet.nRings;
manifest.Npp = resultSet.NppPerRing;
manifest.fullRepeats = fullRepeats;
manifest.compactFiles = compactFiles;
manifest.fullFiles = fullFiles;
manifest.modules = modules;
manifest.compactInfo = compactInfo;
manifest.fullInfo = fullInfo;
manifest.seqOpts = seqOpts;
end

function v=getp(s,name,defaultValue)
if isfield(s,name) && ~isempty(s.(name))
    v=s.(name);
else
    v=defaultValue;
end
end
