function ok = check_gradient_limits(G, Gmax, useNorm)
%CHECK_GRADIENT_LIMITS Check gradient amplitude limits.
if nargin < 3
    useNorm = false;
end
if useNorm
    ok = all(sqrt(sum(G.^2,2)) <= Gmax * (1 + 1e-9));
else
    ok = all(abs(G(:)) <= Gmax * (1 + 1e-9));
end
end
