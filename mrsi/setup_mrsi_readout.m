function acq = setup_mrsi_readout(nADC, spectralBW, varargin)
%SETUP_MRSI_READOUT Build MRSI readout timing structure.
%
% acq = setup_mrsi_readout(nADC, spectralBW)
% acq = setup_mrsi_readout(..., 'adcDelay', 0)

p = inputParser;
addRequired(p, 'nADC', @(x) isnumeric(x) && isscalar(x) && x > 0);
addRequired(p, 'spectralBW', @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'adcDelay', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'adcStartMode', 'start', @ischar);
parse(p, nADC, spectralBW, varargin{:});

acq = struct();
acq.nADC = round(nADC);
acq.spectralBW = spectralBW;
acq.dtADC = 1 / spectralBW;
acq.readoutTime = (acq.nADC - 1) * acq.dtADC;
acq.adcDelay = p.Results.adcDelay;
acq.adcStartMode = p.Results.adcStartMode;
end
