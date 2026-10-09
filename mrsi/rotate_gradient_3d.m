function Grot = rotate_gradient_3d(G, R)
%ROTATE_GRADIENT_3D Rotate a 3D gradient waveform by a 3x3 matrix.
if size(G,2) == 2
    G = [G, zeros(size(G,1),1)];
end
if ~isequal(size(R), [3 3])
    error('R must be a 3x3 rotation matrix.');
end
Grot = (R * G.').';
end
