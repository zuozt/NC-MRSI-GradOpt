function G = k2grad_direct(ktraj, opts)
%K2GRAD_DIRECT Direct differentiation from time-parameterized k-space.
% ktraj is assumed to be sampled at the gradient raster.
N = size(ktraj,1);
D = size(ktraj,2);
G = zeros(N,D);
G(1:N-1,:) = diff(ktraj,1,1) / (opts.gammaBar * opts.dtGrad);
G(N,:) = G(N-1,:);
end
