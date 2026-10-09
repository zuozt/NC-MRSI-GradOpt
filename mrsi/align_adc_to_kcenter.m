function acq = align_adc_to_kcenter(ktraj_grad, opts, acq)
%ALIGN_ADC_TO_KCENTER Set adcDelay so first ADC sample aligns to nearest k center.
% This helper is useful for UTE-like MRSI sampling.
if nargin < 3 || isempty(acq)
    acq = struct();
end
r = sqrt(sum(ktraj_grad.^2, 2));
[~, idx] = min(r);
acq.adcDelay = (idx - 1) * opts.dtGrad;
end
