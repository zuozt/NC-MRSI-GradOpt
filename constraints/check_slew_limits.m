function ok = check_slew_limits(S, Smax, useNorm)
%CHECK_SLEW_LIMITS Check slew-rate limits.
if nargin < 3
    useNorm = false;
end
if useNorm
    ok = all(sqrt(sum(S.^2,2)) <= Smax * (1 + 1e-9));
else
    ok = all(abs(S(:)) <= Smax * (1 + 1e-9));
end
end
