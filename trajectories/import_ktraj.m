function ktraj = import_ktraj(filename)
%IMPORT_KTRAJ Import k-space trajectory from CSV/TXT/MAT.
[~,~,ext] = fileparts(filename);
switch lower(ext)
    case '.mat'
        s = load(filename);
        if isfield(s, 'ktraj')
            ktraj = s.ktraj;
        elseif isfield(s, 'ktraj_target')
            ktraj = s.ktraj_target;
        else
            error('MAT file must contain variable ktraj or ktraj_target.');
        end
    otherwise
        ktraj = readmatrix(filename);
end
if size(ktraj,2) > 3
    ktraj = ktraj(:,1:3);
end
end
