function ktraj = make_periodic_rosette_2d(params)
%MAKE_PERIODIC_ROSETTE_2D Generate ONE compact 2D PETALUTE rosette period.
%
% 2D projection of the PETALUTE reference formula:
%
%   Kxy(t) = Kmax * sin(omega1*t) * exp(i*(omega2*t + beta))
%
% with omega1 = omega2 = pi*SBW and SBW = 1/(Npp*dt).  In normalized one-period
% coordinates u=t/Tperiod:
%
%   kx = Kmax*sin(pi*u)*cos(pi*u + beta)
%   ky = Kmax*sin(pi*u)*sin(pi*u + beta)
%
% The Npp samples are unique samples in [0,Tperiod); the duplicated endpoint at
% u=1 is omitted because it is the first point of the next repeated period.

Npp = getp(params, 'Npp', getp(params, 'N', 96));
Kmax = getp(params, 'Kmax', 25);
nRadial = getp(params, 'nRadial', 1);
nAngular = getp(params, 'nAngular', 1);
beta = getp(params, 'beta', getp(params, 'phase', 0));
shape = getp(params, 'shape', 'petalute_paper');

Npp = round(Npp);
if Npp < 4
    error('Npp must be at least 4 for a periodic rosette period.');
end

u = (0:Npp-1).' / Npp;

switch lower(shape)
    case {'petalute_paper','paper','reference','reference_formula'}
        radial = sin(pi*nRadial*u);
        theta = pi*nAngular*u + beta;
    case {'legacy_sin2','smooth_petal','sin2','sin_squared'}
        radial = sin(pi*nRadial*u).^2;
        theta = 2*pi*nAngular*u + beta;
    case {'legacy_signed_2pi','signed_sine','paper_signed'}
        radial = sin(2*pi*nRadial*u);
        theta = 2*pi*nAngular*u + beta;
    otherwise
        error('Unknown periodic rosette shape: %s', shape);
end

kx = Kmax .* radial .* cos(theta);
ky = Kmax .* radial .* sin(theta);
ktraj = [kx, ky];
end

function v = getp(s, name, defaultValue)
if isfield(s,name) && ~isempty(s.(name)); v = s.(name); else; v = defaultValue; end
end
