function ktraj = make_rosette_2d(params)
%MAKE_ROSETTE_2D Generate a simple 2D rosette target trajectory.
%
% params fields:
%   .N        number of samples
%   .Kmax     maximum k-space radius, cycles/m
%   .nRadial  radial oscillations
%   .nAngular angular rotations
%   .phase    optional phase, rad

N = getp(params, 'N', 1024);
Kmax = getp(params, 'Kmax', 100);
nRadial = getp(params, 'nRadial', 4);
nAngular = getp(params, 'nAngular', 1);
phase = getp(params, 'phase', 0);

u = linspace(0, 1, N).';
r = Kmax * sin(2*pi*nRadial*u);
theta = 2*pi*nAngular*u + phase;
ktraj = [r .* cos(theta), r .* sin(theta)];
end

function v = getp(s, name, defaultValue)
if isfield(s,name) && ~isempty(s.(name)); v = s.(name); else; v = defaultValue; end
end
