function S = compute_slew(G, dtGrad)
%COMPUTE_SLEW Compute slew rate in T/m/s.
S = diff(G, 1, 1) / dtGrad;
end
