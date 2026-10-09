function info = check_spectral_sampling(acq)
%CHECK_SPECTRAL_SAMPLING Return spectral sampling information.
info = struct();
info.nADC = acq.nADC;
info.dtADC = acq.dtADC;
info.spectralBW = 1 / acq.dtADC;
info.readoutTime = (acq.nADC - 1) * acq.dtADC;
info.nominalSpectralResolution = 1 / info.readoutTime;
end
