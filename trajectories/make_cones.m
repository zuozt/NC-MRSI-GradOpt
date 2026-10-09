function ktraj = make_cones(params)
%MAKE_CONES Generate a simple 3D cones-like target trajectory.
N = getp(params, 'N', 1024);
Kmax = getp(params, 'Kmax', 100);
nTurns = getp(params, 'nTurns', 8);
coneAngle = getp(params, 'coneAngle', pi/6);
phase = getp(params, 'phase', 0);

u = linspace(0, 1, N).';
rho = Kmax * u;
theta = 2*pi*nTurns*u + phase;
kx = rho .* sin(coneAngle) .* cos(theta);
ky = rho .* sin(coneAngle) .* sin(theta);
kz = rho .* cos(coneAngle);
ktraj = [kx, ky, kz];
end

function v = getp(s, name, defaultValue)
if isfield(s,name) && ~isempty(s.(name)); v = s.(name); else; v = defaultValue; end
end
