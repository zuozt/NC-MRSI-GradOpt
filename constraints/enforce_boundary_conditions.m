function G = enforce_boundary_conditions(G, opts)
%ENFORCE_BOUNDARY_CONDITIONS Force start/end gradient to zero if requested.
if opts.forceGStartZero
    G(1,:) = 0;
end
if opts.forceGEndZero
    G(end,:) = 0;
end
end
