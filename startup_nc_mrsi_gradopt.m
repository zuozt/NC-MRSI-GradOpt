function startup_nc_mrsi_gradopt()
%STARTUP_NC_MRSI_GRADOPT Add NC-MRSI-GradOpt toolbox folders to MATLAB path.
%
% Usage:
%   cd NC_MRSI_GradOpt
%   startup_nc_mrsi_gradopt
%
rootDir = fileparts(mfilename('fullpath'));
toolboxFolders = {'constraints','core','docs','examples','export','gui', ...
    'mrsi','tests','trajectories','validation','visualization'};
addpath(rootDir);
for ii=1:numel(toolboxFolders)
    folder=fullfile(rootDir,toolboxFolders{ii});
    if exist(folder,'dir')==7
        addpath(genpath(folder));
    end
end

% Use the bundled Pulseq MATLAB source only when another Pulseq installation
% is not already active. This avoids silently shadowing a site installation.
if exist('mr.Sequence','class')~=8 && exist('mr.Sequence','file')~=2
    bundledPulseq=fullfile(rootDir,'third_party','pulseq','matlab');
    if exist(bundledPulseq,'dir')==7
        addpath(bundledPulseq);
        fprintf('Bundled Pulseq MATLAB added to path: %s\n',bundledPulseq);
    end
end
fprintf('NC-MRSI-GradOpt added to MATLAB path: %s\n', rootDir);
end
