function export_crt_ring_set_csv(resultSet, filename)
%EXPORT_CRT_RING_SET_CSV Export all independently optimized CRT rings.
%
% One combined CSV is written.  Rows are identified by ring_index and
% sample_index; each ring has exactly resultSet.NppPerRing ADC/readout rows.
% If complete modules are present, a companion *_full_module.csv is written
% with the real pre-gradient, ADC ring, and return-to-origin post-gradient.

if ~isfield(resultSet,'isCrtRingSet') || ~resultSet.isCrtRingSet
    error('resultSet must be produced by optimize_concentric_crt_set.');
end

write_combined(resultSet, filename, false);
hasModule = false;
for rr = 1:resultSet.nRings
    hasModule = hasModule || (isfield(resultSet.rings(rr),'sequence') && ...
        isfield(resultSet.rings(rr).sequence,'G') && ...
        ~isempty(resultSet.rings(rr).sequence.G));
end
if hasModule
    [p,n,ext] = fileparts(filename);
    if isempty(ext); ext = '.csv'; end
    write_combined(resultSet,fullfile(p,[n '_full_module' ext]),true);
end
end

function write_combined(resultSet, filename, includeModule)
allRows = [];
for rr = 1:resultSet.nRings
    r = resultSet.rings(rr);
    D = size(r.G,2);
    if D < 2
        error('CRT CSV export expects at least two gradient axes.');
    end

    if includeModule && isfield(r,'sequence') && isfield(r.sequence,'G')
        G = r.sequence.G;
        t = r.sequence.time_grad;
        k = r.sequence.ktraj_actual;
        adcOn = r.sequence.adcMask;
        segmentCode = r.sequence.segmentCode;
        sampleIndex = (1:size(G,1)).';
        S = r.sequence.S;
    else
        G = r.G;
        t = r.time_grad;
        k = r.ktraj_actual;
        adcOn = ones(size(G,1),1);
        segmentCode = ones(size(G,1),1);
        sampleIndex = (0:size(G,1)-1).';
        S = r.S;
    end
    S = fit_rows(S, size(G,1), D);
    ringColumn = rr * ones(size(G,1),1);
    radiusColumn = r.ringRadius * ones(size(G,1),1);
    rows = [ringColumn,radiusColumn,sampleIndex,segmentCode,t, ...
        G(:,1:2),S(:,1:2),k(:,1:2),adcOn];
    allRows = [allRows; rows]; %#ok<AGROW>
end

varNames = {'ring_index','ring_radius_cycles_per_m','sample_index','segment_code','t_s', ...
    'Gx_T_per_m','Gy_T_per_m','Sx_T_per_m_per_s','Sy_T_per_m_per_s', ...
    'kx_cycles_per_m','ky_cycles_per_m','ADC_on'};
T = array2table(allRows, 'VariableNames', varNames);
writetable(T, filename);
fprintf('Exported CRT ring-set CSV: %s\n', filename);
end

function S = fit_rows(S, N, D)
if isempty(S)
    S = nan(N,D);
elseif size(S,1) < N
    S(end+1:N,:) = nan;
elseif size(S,1) > N
    S = S(1:N,:);
end
end
