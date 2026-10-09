function ktraj = integrate_periodic_gradient_samples(G, opts, k0)
%INTEGRATE_PERIODIC_GRADIENT_SAMPLES Integrate one periodic gradient period.
%
% The output contains the N sampled k-space points inside one period:
%   k(1) = k0
%   k(i) = k0 + gamma*dt*sum_{j=1}^{i-1} G(j), i=2..N
% The final gradient sample G(N) closes the trajectory back to k0 at the
% first sample of the next period; that closure point is not duplicated.

if nargin < 3 || isempty(k0)
    k0 = zeros(1, size(G,2));
end
N = size(G,1);
D = size(G,2);
ktraj = zeros(N,D);
ktraj(1,:) = k0;
for n = 2:N
    ktraj(n,:) = ktraj(n-1,:) + opts.gammaBar * opts.dtGrad * G(n-1,:);
end
end
