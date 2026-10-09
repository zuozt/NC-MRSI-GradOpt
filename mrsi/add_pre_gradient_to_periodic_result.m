function result = add_pre_gradient_to_periodic_result(result, Npre)
%ADD_PRE_GRADIENT_TO_PERIODIC_RESULT Add a zero-start pre-gradient before ADC.
%
% result = add_pre_gradient_to_periodic_result(result, Npre)
%
% The optimized compact readout period may start with nonzero gradient,
% especially for a circular CRT ring.  This is correct for the ADC window,
% but a scanner sequence needs a non-ADC pre-gradient before the ring starts.
% This helper designs that pre-gradient from G=0 to result.G(1,:) while
% moving k-space from the origin to result.ktraj_actual(1,:).

if nargin < 2
    Npre = [];
end
if ~isfield(result,'G') || isempty(result.G)
    error('result.G is required.');
end
if ~isfield(result,'ktraj_actual') || isempty(result.ktraj_actual)
    error('result.ktraj_actual is required.');
end
if ~isfield(result,'opts') || isempty(result.opts)
    error('result.opts is required.');
end

kStart = result.ktraj_actual(1,:);
GEnd = result.G(1,:);
pre = design_pre_gradient_to_kstart(kStart, GEnd, result.opts, Npre);
result.pre = pre;

% Convenience sequence waveform: pre-gradient before ADC plus the periodic
% readout period.  ADC is intended to start at index pre.Npre+1.
result.sequence = struct();
result.sequence.G = [pre.G; result.G];
result.sequence.time_grad = [pre.time_grad; result.time_grad];
result.sequence.adcStartIndex = pre.Npre + 1;
result.sequence.adcStartTime = 0;
result.sequence.preDuration = pre.duration;
end
