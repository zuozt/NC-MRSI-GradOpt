function ktraj = validate_ktraj_input(ktraj)
%VALIDATE_KTRAJ_INPUT Validate and normalize k-space trajectory matrix.
if isempty(ktraj) || ~isnumeric(ktraj)
    error('ktraj_target must be a non-empty numeric array.');
end
if isvector(ktraj)
    ktraj = ktraj(:);
end
if size(ktraj,2) > 3
    error('ktraj_target must have 1, 2, or 3 columns.');
end
if any(~isfinite(ktraj(:)))
    error('ktraj_target contains NaN or Inf.');
end
end
