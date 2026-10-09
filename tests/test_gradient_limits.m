%% Test gradient and slew limit checks
G = [0; 1; 2] * 1e-3;
S = diff(G) / 10e-6;
assert(check_gradient_limits(G, 3e-3, false));
assert(~check_gradient_limits(G, 1.5e-3, false));
assert(check_slew_limits(S, 150, false));
assert(~check_slew_limits(S, 50, false));
disp('test_gradient_limits passed');
