function ktraj = make_radial(params)
%MAKE_RADIAL Generate a single radial spoke trajectory.
N = getp(params, 'N', 1024);
Kmax = getp(params, 'Kmax', 100);
angle = getp(params, 'angle', 0);
centerOut = getp(params, 'centerOut', true);

if centerOut
    r = linspace(0, Kmax, N).';
else
    r = linspace(-Kmax, Kmax, N).';
end
ktraj = [r*cos(angle), r*sin(angle)];
end

function v = getp(s, name, defaultValue)
if isfield(s,name) && ~isempty(s.(name)); v = s.(name); else; v = defaultValue; end
end
