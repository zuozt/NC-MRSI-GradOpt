%% Test compact-period concentric-ring trajectory generator

p = struct();
p.Npp = 96;
p.Kmax = 25;
p.nRings = 6;
p.rMin = 1/0.240;
p.nTurnsPerRing = 1;

% Recommended CRT MRSI unit: one compact period = one ring.
p.mode = 'single_ring';
p.ringIndex = 6;
ktraj = make_periodic_crt_2d(p);
assert(size(ktraj,1) == p.Npp, 'Single-ring CRT trajectory should contain Npp samples.');
assert(size(ktraj,2) == 2, 'Single-ring CRT trajectory should be 2D.');
assert(all(isfinite(ktraj(:))), 'Single-ring CRT trajectory contains non-finite values.');
assert(max(abs(ktraj(:))) <= p.Kmax + 1e-9, 'Single-ring CRT trajectory exceeds Kmax.');

% Optional direct radius override.
p2 = p;
p2.ringRadius = 10;
ktraj2 = make_periodic_crt_2d(p2);
radius2 = sqrt(sum(ktraj2.^2,2));
assert(max(abs(radius2 - p2.ringRadius)) < 1e-10, 'ringRadius override failed.');

% Multi-ring mode is retained only as a diagnostic stress test.
p3 = p;
p3.mode = 'multi_ring_period';
p3.transitionFraction = 0.25;
ktraj3 = make_periodic_crt_2d(p3);
assert(size(ktraj3,1) == p3.Npp, 'Multi-ring CRT trajectory should contain Npp samples.');
assert(size(ktraj3,2) == 2, 'Multi-ring CRT trajectory should be 2D.');
assert(all(isfinite(ktraj3(:))), 'Multi-ring CRT trajectory contains non-finite values.');
assert(max(abs(ktraj3(:))) <= p3.Kmax + 1e-9, 'Multi-ring CRT trajectory exceeds Kmax.');

% Correct complete CRT acquisition: Npp applies to every independent ring.
p4 = p;
p4.mode = 'multi_ring_set';
crtSet = make_concentric_crt_set(p4);
assert(crtSet.nRings == p4.nRings, 'CRT set ring count mismatch.');
assert(crtSet.NppPerRing == p4.Npp, 'CRT set must preserve Npp per ring.');
assert(crtSet.totalSpatialSamples == p4.nRings*p4.Npp, ...
    'Complete CRT set must contain nRings*Npp samples.');
assert(isequal(size(crtSet.targetStack), [p4.Npp 2 p4.nRings]), ...
    'CRT target stack must be [Npp x 2 x nRings].');
for rr = 1:p4.nRings
    kr = crtSet.targets{rr};
    assert(isequal(size(kr), [p4.Npp 2]), ...
        'Every CRT ring must contain exactly Npp 2D samples.');
    radius = sqrt(sum(kr.^2,2));
    assert(max(abs(radius - crtSet.radii(rr))) < 1e-10, ...
        'CRT ring samples must remain on the requested radius.');
end

% The matrix-output generator must reject multi_ring_set explicitly so that
% callers cannot accidentally treat nRings periods as one period.
didError = false;
try
    make_concentric_crt_2d(p4);
catch ME
    didError = ~isempty(strfind(ME.message, 'make_concentric_crt_set')); %#ok<STREMP>
end
assert(didError, 'make_concentric_crt_2d should direct multi_ring_set callers to the set API.');

disp('test_concentric_crt_trajectory passed.');
