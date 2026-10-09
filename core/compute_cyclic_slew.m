function S = compute_cyclic_slew(G, dtGrad)
%COMPUTE_CYCLIC_SLEW Compute cyclic slew for one repeated periodic waveform.
%
% For a compact period G(1:N), the next sample after G(N) is G(1) from the
% next repeated period.  The returned slew has N rows; the final row is the
% cyclic boundary transition (G(1)-G(N))/dtGrad.

if isempty(G)
    S = G;
    return;
end
S = [diff(G, 1, 1); G(1,:) - G(end,:)] / dtGrad;
end
