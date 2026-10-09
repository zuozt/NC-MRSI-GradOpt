function ktraj = make_rosette_3d(params)
%MAKE_ROSETTE_3D Generate a simple rotated-plane 3D rosette/petal trajectory.
%
% params fields:
%   .N        number of samples
%   .Kmax     maximum k-space radius, cycles/m
%   .nRadial  radial oscillations
%   .nAngular angular rotations in the transverse plane
%   .phi      out-of-plane angle, rad
%   .phase    angular phase, rad

N = getp(params, 'N', 1024);
Kmax = getp(params, 'Kmax', 100);
nRadial = getp(params, 'nRadial', 4);
nAngular = getp(params, 'nAngular', 1);
phi = getp(params, 'phi', 0);
phase = getp(params, 'phase', 0);

u = linspace(0, 1, N).';
r = Kmax * sin(2*pi*nRadial*u);
theta = 2*pi*nAngular*u + phase;
kx = r .* cos(phi) .* cos(theta);
ky = r .* cos(phi) .* sin(theta);
kz = r .* sin(phi);
ktraj = [kx, ky, kz];
end

function v = getp(s, name, defaultValue)
if isfield(s,name) && ~isempty(s.(name)); v = s.(name); else; v = defaultValue; end
end
