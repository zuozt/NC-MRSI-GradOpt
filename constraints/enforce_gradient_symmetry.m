function Gsym = enforce_gradient_symmetry(G, symmetryMode)
%ENFORCE_GRADIENT_SYMMETRY Strictly enforce gradient symmetry.
%
% symmetryMode:
%   'antisymmetric_k' : k(T-t)=-k(t), therefore G(T-t)=G(t)
%   'even_k'          : k(T-t)= k(t), therefore G(T-t)=-G(t)
%   'none'            : no change

if nargin < 2 || strcmpi(symmetryMode, 'none')
    Gsym = G;
    return;
end

Gflip = flipud(G);
switch lower(symmetryMode)
    case 'antisymmetric_k'
        Gsym = 0.5 * (G + Gflip);
    case 'even_k'
        Gsym = 0.5 * (G - Gflip);
    otherwise
        error('Unknown symmetryMode: %s', symmetryMode);
end
end
