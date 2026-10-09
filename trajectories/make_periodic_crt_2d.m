function ktraj = make_periodic_crt_2d(params)
%MAKE_PERIODIC_CRT_2D Alias for compact-period concentric-ring MRSI target.
%
% This wrapper is provided for naming consistency with the periodic rosette
% generators.  See make_concentric_crt_2d for a single matrix-output period.
% For a complete set with Npp samples per ring, call
% make_concentric_crt_set(params).
ktraj = make_concentric_crt_2d(params);
end
