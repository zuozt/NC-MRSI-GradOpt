function G = symmetric_fixed_duration_optimize(ktraj_target, opts)
%SYMMETRIC_FIXED_DURATION_OPTIMIZE Fixed-duration optimization with symmetry.
%
% This release performs full fixed-duration optimization followed by strict
% gradient symmetrization. This provides deterministic petal-to-petal behavior.
% A future version may solve the reduced half-variable QP directly.

G0 = fixed_duration_optimize(ktraj_target, opts);
G = enforce_gradient_symmetry(G0, opts.symmetry);
G = enforce_boundary_conditions(G, opts);
end
