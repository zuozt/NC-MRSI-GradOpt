function acq = setup_periodic_mrsi_readout(Npp, Nspec, adcDwell, varargin)
%SETUP_PERIODIC_MRSI_READOUT Build timing for periodic non-Cartesian MRSI.
%
% In periodic MRSI, the fast ADC dwell samples points within one spatial
% trajectory period. The spectral bandwidth is set by the repetition period,
% not by the ADC dwell alone:
%
%   Tperiod = Npp * adcDwell
%   spectralBW = 1 / Tperiod
%   nADCtotal = Npp * Nspec
%
% Npp is the number of ADC/trajectory samples in one complete spatial period.
% Nspec is the number of repeated periods and is the spectral/FID dimension.
%
% The optimizer should normally optimize only one compact period with nADC=Npp.

p = inputParser;
addRequired(p, 'Npp', @(x) isnumeric(x) && isscalar(x) && x >= 2);
addRequired(p, 'Nspec', @(x) isnumeric(x) && isscalar(x) && x >= 1);
addRequired(p, 'adcDwell', @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'adcDelay', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
parse(p, Npp, Nspec, adcDwell, varargin{:});

Npp = round(Npp);
Nspec = round(Nspec);

acq = struct();
acq.Npp = Npp;
acq.Nspec = Nspec;
acq.nADC = Npp;                 % compact period for optimization
acq.nADCtotal = Npp * Nspec;    % full readout ADC samples
acq.dtADC = adcDwell;
acq.adcDwell = adcDwell;
acq.periodTime = Npp * adcDwell;
acq.spectralBW = 1 / acq.periodTime;
acq.spectralResolution = acq.spectralBW / Nspec;
acq.readoutTimePeriod = Npp * adcDwell;
acq.readoutTimeTotal = acq.nADCtotal * adcDwell;
acq.readoutTime = acq.readoutTimePeriod;
acq.adcDelay = p.Results.adcDelay;
acq.adcStartMode = 'periodic_start';
acq.isPeriodic = true;
end
