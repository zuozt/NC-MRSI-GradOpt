function export_csv(result, filename)
%EXPORT_CSV Export gradient, slew, and k-space to CSV.
%
% If result.sequence exists, a companion *_full_module.csv file contains the
% real pre-gradient, ADC ring, and return-to-origin post-gradient.

write_readout_csv(result, filename);

if isfield(result,'sequence') && isstruct(result.sequence) && ...
        isfield(result.sequence,'G') && ~isempty(result.sequence.G)
    [p,n,ext] = fileparts(filename);
    if isempty(ext); ext = '.csv'; end
    filenameModule = fullfile(p,[n '_full_module' ext]);
    write_full_module_csv(result,filenameModule);
end
end

function write_readout_csv(result, filename)
G = result.G;
N = size(G,1);
D = size(G,2);
S = result.S;
% Non-periodic slew has N-1 rows, whereas cyclic slew has N rows.  Normalize
% both cases to one CSV row per gradient sample.
if size(S,1) < N
    S(end+1:N,:) = nan;
elseif size(S,1) > N
    S = S(1:N,:);
end
k = result.ktraj_actual;
t = result.time_grad;
varNames = {'t_s'};
for d = 1:D; varNames{end+1} = sprintf('G%d_T_per_m', d); end %#ok<AGROW>
for d = 1:D; varNames{end+1} = sprintf('S%d_T_per_m_per_s', d); end %#ok<AGROW>
for d = 1:D; varNames{end+1} = sprintf('k%d_cycles_per_m', d); end %#ok<AGROW>
T = array2table([t, G, S, k], 'VariableNames', varNames);
writetable(T, filename);
fprintf('Exported CSV: %s\n', filename);
end

function write_full_module_csv(result, filename)
G = result.sequence.G;
D = size(G,2);
t = result.sequence.time_grad;
S = result.sequence.S;
if size(S,1) < size(G,1)
    S(end+1:size(G,1),:) = nan;
elseif size(S,1) > size(G,1)
    S = S(1:size(G,1),:);
end
k = result.sequence.ktraj_actual;
adcMask = result.sequence.adcMask;
segmentCode = result.sequence.segmentCode;
varNames = {'t_s'};
for d = 1:D; varNames{end+1} = sprintf('G%d_T_per_m', d); end %#ok<AGROW>
for d = 1:D; varNames{end+1} = sprintf('S%d_T_per_m_per_s', d); end %#ok<AGROW>
for d = 1:D; varNames{end+1} = sprintf('k%d_cycles_per_m', d); end %#ok<AGROW>
varNames{end+1} = 'ADC_on';
varNames{end+1} = 'segment_code';
T = array2table([t,G,S,k,adcMask,segmentCode],'VariableNames',varNames);
writetable(T, filename);
fprintf('Exported CSV with real complete module: %s\n',filename);
end
