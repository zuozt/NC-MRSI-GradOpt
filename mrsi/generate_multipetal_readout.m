function petals = generate_multipetal_readout(baseResult, rotations)
%GENERATE_MULTIPETAL_READOUT Generate multiple petals by rotating one base petal.
%
% rotations can be [3 x 3 x P] or a cell array of 3x3 matrices.
if iscell(rotations)
    P = numel(rotations);
else
    P = size(rotations, 3);
end
petals = cell(P,1);
for p = 1:P
    if iscell(rotations)
        R = rotations{p};
    else
        R = rotations(:,:,p);
    end
    petals{p} = rotate_petal_3d(baseResult, R);
end
end
