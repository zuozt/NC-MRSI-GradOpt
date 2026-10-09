function write_report_txt(result, filename)
%WRITE_REPORT_TXT Write validation report as plain text.
r = result.report;
fid = fopen(filename, 'w');
fprintf(fid, 'NC-MRSI-GradOpt validation report\n');
fprintf(fid, 'Duration: %.9g s\n', r.duration);
fprintf(fid, 'Max G axis: %s T/m\n', mat2str(r.maxGAxis, 6));
fprintf(fid, 'Max S axis: %s T/m/s\n', mat2str(r.maxSAxis, 6));
fprintf(fid, 'Max G norm: %.9g T/m\n', r.maxGNorm);
fprintf(fid, 'Max S norm: %.9g T/m/s\n', r.maxSNorm);
fprintf(fid, 'k RMS error: %.9g cycles/m\n', r.kErrorRMS);
fprintf(fid, 'k max error: %.9g cycles/m\n', r.kErrorMax);
fprintf(fid, 'Feasible axis-wise: %d\n', r.isFeasible);
if ~isempty(r.warnings)
    fprintf(fid, 'Warnings:\n');
    for i = 1:numel(r.warnings)
        fprintf(fid, '  - %s\n', r.warnings{i});
    end
end
fclose(fid);
fprintf('Exported report: %s\n', filename);
end
