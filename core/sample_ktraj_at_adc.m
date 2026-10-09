function k_adc = sample_ktraj_at_adc(ktraj_grad, opts)
%SAMPLE_KTRAJ_AT_ADC Interpolate actual k-space trajectory at ADC sample times.
time_grad = (0:size(ktraj_grad,1)-1).' * opts.dtGrad;
time_adc = opts.adcDelay + (0:opts.nADC-1).' * opts.dtADC;
D = size(ktraj_grad,2);
k_adc = zeros(numel(time_adc), D);
for d = 1:D
    k_adc(:,d) = interp1(time_grad, ktraj_grad(:,d), time_adc, 'linear', 'extrap');
end
end
