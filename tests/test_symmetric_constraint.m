%% Test gradient symmetry enforcement
G = [(1:6).' (11:16).'];
Gsym = enforce_gradient_symmetry(G, 'antisymmetric_k');
GsymFlip = flipud(Gsym);
assert(max(abs(Gsym(:) - GsymFlip(:))) < 1e-12);
Ganti = enforce_gradient_symmetry(G, 'even_k');
GantiFlip = flipud(Ganti);
assert(max(abs(Ganti(:) + GantiFlip(:))) < 1e-12);
disp('test_symmetric_constraint passed');
