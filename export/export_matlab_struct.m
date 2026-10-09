function export_matlab_struct(result, filename)
%EXPORT_MATLAB_STRUCT Save result structure as a MAT file.
save(filename, 'result');
fprintf('Exported MAT: %s\n', filename);
end
