function ktraj_out = preprocess_ktraj(ktraj_in, opts)
%PREPROCESS_KTRAJ Resample target trajectory to the gradient raster length.
Nin = size(ktraj_in, 1);
Nout = opts.nGrad;
D = size(ktraj_in, 2);

if Nin == Nout
    ktraj_out = ktraj_in;
    return;
end

uIn = linspace(0, 1, Nin).';
uOut = linspace(0, 1, Nout).';
ktraj_out = zeros(Nout, D);
for d = 1:D
    ktraj_out(:,d) = interp1(uIn, ktraj_in(:,d), uOut, opts.resampleMethod, 'extrap');
end
end
