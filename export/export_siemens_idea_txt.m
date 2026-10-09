function export_siemens_idea_txt(result, outDir)
%EXPORT_SIEMENS_IDEA_TXT Export gradient table for Siemens IDEA integration.
%
% The output is an intermediate text representation. It is not a direct IDEA
% .cpp file. Units are mT/m for gradients and T/m/s for slew.

if ~exist(outDir, 'dir')
    mkdir(outDir);
end
G_mTm = result.G * 1e3;
S = result.S;
k = result.ktraj_actual;
N = size(G_mTm,1);
D = size(G_mTm,2);
if D < 3
    G_mTm(:,3) = 0;
    k(:,3) = 0;
end
adcMask = zeros(N,1);
adcTimes = result.time_adc;
for i = 1:numel(adcTimes)
    [~,idx] = min(abs(result.time_grad - adcTimes(i)));
    if idx >= 1 && idx <= N
        adcMask(idx) = 1;
    end
end
T = table(result.time_grad, G_mTm(:,1), G_mTm(:,2), G_mTm(:,3), adcMask, ...
    k(:,1), k(:,2), k(:,3), ...
    'VariableNames', {'t_s','Gx_mTm','Gy_mTm','Gz_mTm','ADC','kx_cyc_m','ky_cyc_m','kz_cyc_m'});
writetable(T, fullfile(outDir, 'gradient_table_for_idea.csv'));

fid = fopen(fullfile(outDir, 'metadata.txt'), 'w');
fprintf(fid, 'dt_grad_s = %.12g\n', result.opts.dtGrad);
fprintf(fid, 'dt_adc_s = %.12g\n', result.opts.dtADC);
fprintf(fid, 'gamma_bar_Hz_per_T = %.12g\n', result.opts.gammaBar);
fprintf(fid, 'gradient_unit = mT/m\n');
fprintf(fid, 'k_unit = cycles/m\n');
fprintf(fid, 'n_gradient_points = %d\n', N);
fprintf(fid, 'n_adc = %d\n', result.opts.nADC);
fclose(fid);
fprintf('Exported Siemens IDEA intermediate files: %s\n', outDir);
end
