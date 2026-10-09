function ktraj = make_periodic_rosette_3d(params)
%MAKE_PERIODIC_ROSETTE_3D Generate ONE compact 3D PETALUTE rosette period.
%
% This function implements the reference PETALUTE formula used for 31P-MRSI:
%
%   Kxy(t) = Kx(t) + i*Ky(t)
%          = Kmax*cos(phi) * sin(omega1*t) * exp(i*(omega2*t + beta))
%   Kz(t)  = Kmax*sin(phi) * sin(omega1*t)
%
% with omega1 = omega2 = pi*SBW and SBW = 1/(Npp*dt).  In normalized one-period
% coordinates u=t/Tperiod, the default paper formula is:
%
%   radial_phase  = pi*u
%   angular_phase = pi*u + beta
%
% The returned samples are the Npp unique ADC samples in [0,Tperiod), i.e.
% u = 0, 1/Npp, ..., (Npp-1)/Npp.  The duplicated endpoint at u=1 is not included;
% the next repeated period starts again from k-space center.
%
% params fields:
%   .Npp or .N     number of samples in one period
%   .Kmax          maximum k-space radius, cycles/m
%   .phi           z-plane angle, rad
%   .beta or .phase initial angular phase, rad
%   .nRadial       multiplier for omega1, default 1
%   .nAngular      multiplier for omega2, default 1
%   .shape         'petalute_paper' [default], 'legacy_sin2', or 'legacy_signed_2pi'

Npp = getp(params, 'Npp', getp(params, 'N', 96));
Kmax = getp(params, 'Kmax', 25);
nRadial = getp(params, 'nRadial', 1);
nAngular = getp(params, 'nAngular', 1);
phi = getp(params, 'phi', 0);
beta = getp(params, 'beta', getp(params, 'phase', 0));
shape = getp(params, 'shape', 'petalute_paper');

Npp = round(Npp);
if Npp < 4
    error('Npp must be at least 4 for a periodic rosette period.');
end

% Unique samples in one period.  Do not include u=1 because that is the first
% sample of the next repeated period.
u = (0:Npp-1).' / Npp;

switch lower(shape)
    case {'petalute_paper','paper','reference','reference_formula'}
        radial = sin(pi*nRadial*u);
        theta = pi*nAngular*u + beta;
    case {'legacy_sin2','smooth_petal','sin2','sin_squared'}
        % Older engineering envelope.  Kept only for comparison; not the paper formula.
        radial = sin(pi*nRadial*u).^2;
        theta = 2*pi*nAngular*u + beta;
    case {'legacy_signed_2pi','signed_sine','paper_signed'}
        % Older signed 2*pi implementation.  This is not the PETALUTE equation.
        radial = sin(2*pi*nRadial*u);
        theta = 2*pi*nAngular*u + beta;
    otherwise
        error('Unknown periodic rosette shape: %s', shape);
end

amp_xy = Kmax * cos(phi) .* radial;
kx = amp_xy .* cos(theta);
ky = amp_xy .* sin(theta);
kz = (Kmax * sin(phi)) .* radial;
ktraj = [kx, ky, kz];
end

function v = getp(s, name, defaultValue)
if isfield(s,name) && ~isempty(s.(name)); v = s.(name); else; v = defaultValue; end
end
