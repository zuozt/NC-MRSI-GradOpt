function ktraj = integrate_gradient(G, opts, k0)
%INTEGRATE_GRADIENT Integrate gradient waveform into k-space trajectory.
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
