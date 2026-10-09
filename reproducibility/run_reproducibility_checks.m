function run_reproducibility_checks(outputDir)
%RUN_REPRODUCIBILITY_CHECKS Run existing tests and generate deterministic demo figures.
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(rootDir); startup_nc_mrsi_gradopt;
if nargin < 1 || isempty(outputDir)
    outputDir = fullfile(rootDir,'reproducibility','outputs');
end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
logFile = fullfile(outputDir,'test_log.txt');
diary(logFile); diary on;
try
    fprintf('MATLAB: %s\n',version);
    fprintf('Toolbox version: %s\n',strtrim(fileread(fullfile(rootDir,'VERSION.txt'))));
    fprintf('quadprog available: %d\n',exist('quadprog','file')==2);
    testNames = {'test_direct_k2grad','test_gradient_limits', ...
        'test_symmetric_constraint','test_fixed_duration_solver', ...
        'test_petal_rotation_consistency','test_concentric_crt_trajectory', ...
        'test_crt_complete_module','test_pulseq_adc_centered_conversion'};
    failed = {};
    for i=1:numel(testNames)
        try
            fprintf('RUN %s\n',testNames{i});
            run(fullfile(rootDir,'tests',[testNames{i} '.m']));
            fprintf('PASS %s\n',testNames{i});
        catch ME
            fprintf('FAIL %s: %s\n',testNames{i},ME.message);
            failed{end+1} = testNames{i}; %#ok<AGROW>
        end
    end
    if ~isempty(failed)
        error('Reproducibility:TestsFailed','Failed: %s',strjoin(failed,', '));
    end
    make_demo_figures(fullfile(outputDir,'demo'));
    fprintf('ALL CHECKS PASSED\n');
    diary off;
catch ME
    fprintf('CHECKS FAILED: %s\n',ME.message);
    diary off;
    rethrow(ME);
end
end
