function ktraj = make_spiral(params)
%MAKE_SPIRAL Generate a simple Archimedean spiral target trajectory.
N = getp(params, 'N', 1024);
Kmax = getp(params, 'Kmax', 100);
nTurns = getp(params, 'nTurns', 6);
phase = getp(params, 'phase', 0);

u = linspace(0, 1, N).';
r = Kmax * u;
theta = 2*pi*nTurns*u + phase;
ktraj = [r .* cos(theta), r .* sin(theta)];
end

function v = getp(s, name, defaultValue)
if isfield(s,name) && ~isempty(s.(name)); v = s.(name); else; v = defaultValue; end
end
