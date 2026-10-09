function A = build_integration_matrix(N, gammaBar, dt)
%BUILD_INTEGRATION_MATRIX Matrix mapping gradient to k-space samples.
% k(n) = k0 + gammaBar*dt*sum_{j=1}^{n-1} G(j)
A = tril(ones(N,N), -1) * gammaBar * dt;
end
