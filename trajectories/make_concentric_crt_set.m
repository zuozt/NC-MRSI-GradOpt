function crtSet = make_concentric_crt_set(params)
%MAKE_CONCENTRIC_CRT_SET Generate a complete CRT set with Npp samples per ring.
%
% crtSet = make_concentric_crt_set(params)
%
% A normal concentric-ring MRSI acquisition uses one compact spectral period
% per circular ring.  Therefore Npp is interpreted as samples PER RING, not
% as a budget shared by all rings.  For nRings rings, the complete spatial
% encoding set contains nRings*Npp ADC samples distributed over nRings
% independent compact-period modules.
%
% Required/commonly used params fields are the same as for
% make_concentric_crt_2d:
%   .Npp, .Kmax, .nRings, .rMin, .nTurnsPerRing, .phase
%   .alternateDirection
%
% Output fields:
%   .mode                'multi_ring_set'
%   .NppPerRing          samples in each compact period
%   .nRings              number of independent ring modules
%   .totalSpatialSamples NppPerRing*nRings
%   .radii               [nRings x 1] ring radii, cycles/m
%   .targets             {nRings x 1}, each [Npp x 2]
%   .targetStack         [Npp x 2 x nRings]
%
% No radial connectors are inserted between rings.  Entry to each ring is
% handled separately by its own non-ADC pre-gradient.

if nargin < 1 || isempty(params)
    params = struct();
end

Npp = round(getp(params, 'Npp', getp(params, 'N', 96)));
nRings = max(1, round(getp(params, 'nRings', 6)));
Kmax = getp(params, 'Kmax', 25);
rMin = getp(params, 'rMin', Kmax / nRings);

if Npp < 8
    error('Npp must be at least 8 for concentric CRT generation.');
end
if Kmax < 0
    error('Kmax must be nonnegative.');
end
if rMin < 0 || rMin > Kmax
    error('rMin must be between 0 and Kmax.');
end

if nRings == 1
    radii = Kmax;
else
    radii = linspace(rMin, Kmax, nRings).';
end

targets = cell(nRings,1);
targetStack = zeros(Npp, 2, nRings);
for rr = 1:nRings
    pRing = params;
    pRing.Npp = Npp;
    pRing.nRings = nRings;
    pRing.mode = 'single_ring';
    pRing.ringIndex = rr;
    pRing.ringRadius = radii(rr);
    if logical(getp(params, 'alternateDirection', false)) && mod(rr,2)==0
        pRing.nTurnsPerRing = -abs(getp(params, 'nTurnsPerRing', getp(params, 'nTurns', 1)));
    end
    targets{rr} = make_concentric_crt_2d(pRing);
    targetStack(:,:,rr) = targets{rr};
end

crtSet = struct();
crtSet.mode = 'multi_ring_set';
crtSet.NppPerRing = Npp;
crtSet.nRings = nRings;
crtSet.totalSpatialSamples = Npp * nRings;
crtSet.radii = radii(:);
crtSet.targets = targets;
crtSet.targetStack = targetStack;
crtSet.params = params;
end

function v = getp(s, name, defaultValue)
if isfield(s,name) && ~isempty(s.(name))
    v = s.(name);
else
    v = defaultValue;
end
end
