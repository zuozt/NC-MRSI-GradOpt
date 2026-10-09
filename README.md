# NC-MRSI GradOpt GUI

**NC-MRSI GradOpt GUI** is a MATLAB toolbox for designing and optimizing fixed-duration non-Cartesian MRSI gradient waveforms.  The current version focuses on **periodic MRSI trajectories**, where one compact spatial trajectory period is repeated during the FID to encode the spectral dimension.

The toolbox supports:

- periodic 2D/3D rosette target generation;
- periodic concentric-ring / CRT target generation, including complete
  multi-ring sets with fixed `Npp` per ring;
- fixed `Npp` samples per spatial period;
- fixed-duration gradient optimization;
- gradient amplitude and slew-rate constraints;
- cyclic k-space closure;
- cyclic gradient and slew continuity across repeated periods;
- real per-ring pre- and post-gradients for complete
  `k=0 -> ring -> k=0` module trajectories;
- GUI-based visualization of `kx/ky/kz`, `Gx/Gy/Gz`, and `slew_x/slew_y/slew_z`;
- export to CSV, MATLAB struct, Siemens IDEA text, and Pulseq;
- Pulseq write-read round-trip verification at physical ADC-centre times.

> The toolbox is intended for research sequence prototyping. Always validate exported waveforms with the scanner vendor’s sequence safety tools before scanner execution.

---

## Why this toolbox

Periodic MRSI trajectories should not be optimized as one long nonperiodic ADC readout.  For a periodic readout, the same compact spatial trajectory is repeated many times during the FID:

```text
ADC samples total = Npp × Nspec
```

where:

- `Npp` = samples per spatial trajectory period;
- `Nspec` = number of repeated periods, corresponding to the spectral/FID dimension;
- `Npp × dwell` determines the spectral bandwidth.

This toolbox optimizes only the compact period and then repeats it to build the full readout.  This preserves the MRSI spectral sampling structure and exposes hidden discontinuities at the period boundary.

---

## Repository layout

```text
NC_MRSI_GradOpt_GUI/
├── core/                  # Core gradient optimization solvers
├── constraints/           # Gradient/slew/boundary constraints
├── trajectories/          # Target k-space trajectory generators
├── mrsi/                  # MRSI-specific periodic readout utilities
├── gui/                   # MATLAB GUI
├── export/                # CSV, MAT, IDEA, Pulseq export helpers
├── visualization/         # Plotting utilities
├── examples/              # Example scripts
├── tests/                 # Basic validation tests
├── validation/            # Pulseq write-read round-trip validation
├── docs/                  # Theory, API, GUI and comparison documentation
├── third_party/pulseq/    # Bundled Pulseq MATLAB fallback
├── startup_nc_mrsi_gradopt.m
├── launch_gui.m
└── nc_mrsi_gradopt.m      # Main public API
```

---

## Installation

1. Clone or download this repository.
2. Open MATLAB.
3. Run:

```matlab
cd('/path/to/NC_MRSI_GradOpt_GUI')
startup_nc_mrsi_gradopt
```

To launch the GUI:

```matlab
nc_mrsi_gradopt_gui
```

or:

```matlab
launch_gui
```

---

## Quick start: periodic 3D rosette MRSI

```matlab
startup_nc_mrsi_gradopt;

% Periodic MRSI timing
Npp      = 96;       % samples per spatial period
Nspec    = 512;      % repeated periods / spectral points
adcDwell = 5e-6;     % dwell inside one period, s

% Hardware system
sys.Gmax     = 80e-3;       % T/m
sys.Smax     = 200;         % T/m/s
sys.dtGrad   = adcDwell;    % gradient raster, s
sys.gammaBar = 17.235e6;    % 31P, cycles/s/T

% Acquisition structure
acq = setup_periodic_mrsi_readout(Npp, Nspec, adcDwell);

% PETALUTE-like compact 3D rosette period
p.Npp      = Npp;
p.Kmax     = 25;        % cycles/m
p.phi      = 0;         % radians
p.beta     = 0;         % radians
p.nRadial  = 1;
p.nAngular = 1;
p.shape    = 'petalute_paper';
ktraj_period = make_periodic_rosette_3d(p);

% Alternative: one compact-period concentric-ring / CRT target
% p = struct('Npp', Npp, 'Kmax', 25, 'nRings', 6, ...
%            'ringIndex', 6, 'nTurnsPerRing', 1, 'mode', 'single_ring');
% ktraj_period = make_periodic_crt_2d(p);

% Periodic fixed-duration optimization
opt.mode = 'periodic_fixed';
opt.periodic = true;
opt.symmetry = 'none';
opt.safetyMargin = 0.95;
opt.forceGPeriodicEqual = true;
opt.forceSlewPeriodicEqual = true;

result = nc_mrsi_gradopt(ktraj_period, sys, acq, opt);

% Inspect result
plot_gradopt_result(result);
closure = check_periodic_closure(result.ktraj_actual, result.G, result.opts);
disp(closure);

% Expand to full MRSI readout if needed
full = expand_periodic_readout(result, Nspec);
```

## Complete CRT acquisition: fixed Npp per ring

Use `multi_ring_set` when the intended acquisition contains several
concentric rings. `Npp` applies independently to every ring:

```matlab
Npp = 128;
Nspec = 512;
adcDwell = 5e-6;

sys.Gmax = 20e-3;
sys.Smax = 180;
sys.dtGrad = adcDwell;
sys.gammaBar = 42.57747892e6; % 1H
acq = setup_periodic_mrsi_readout(Npp, Nspec, adcDwell);

p = struct('Npp',Npp, 'Kmax',25, 'nRings',6, ...
    'rMin',1/0.240, 'nTurnsPerRing',1, 'mode','multi_ring_set');

opt.mode = 'periodic_fixed';
opt.periodic = true;
opt.symmetry = 'none';
opt.safetyMargin = 0.95;
opt.forceGPeriodicEqual = false;
opt.forceSlewPeriodicEqual = false;

setOpts.usePreGradient = true;
setOpts.preGradientSamples = 0;
setOpts.usePostGradient = true;
setOpts.postGradientSamples = 0;
setOpts.Nspec = Nspec;

resultSet = optimize_concentric_crt_set(p, sys, acq, opt, setOpts);
```

For six rings and `Npp=128`, `resultSet.rings(1:6)` contains six independent
128-sample compact periods (768 spatial samples in the complete encoding set).
`multi_ring_period` remains available only for intentionally packing every ring
and connector into one shared `Npp`-sample stress-test period.

### Real all-rings complete-module trajectories

The GUI all-rings panel plots every independently acquired ring as

```text
k=0 -> real pre-gradient -> ADC ring -> real post-gradient -> k=0
```

The pre- and post-gradients are solved waveforms rather than display guides.
They are saved in `resultSet.rings(i).pre`, `.post`, and `.sequence`, and
participate in complete-module gradient, slew, moment, and return-to-origin
checks. They remain outside the fixed `Npp` ADC window. Since v0.3.8,
`sequence.ktraj_actual` is continuously reintegrated from the complete
`sequence.G` waveform on one time convention; segment-local trajectories are
not concatenated. The full-FID path follows the same rule through
`full.G_with_module` and `full.ktraj_with_module`.

## CRT Pulseq compact/full-FID round-trip

```matlab
seqOpts.compatibility = '1.4.1';
seqOpts.fullRepeats = 512;
[compactFiles, manifest] = export_crt_ring_set_pulseq( ...
    resultSet, 'pulseq_export', 'CRT_1H', seqOpts);
validation = validate_crt_ring_set_pulseq(resultSet, manifest);
assert(validation.overallPass);
```

For every ring, the exporter writes one 128-sample compact file and one
`128 × 512 = 65536`-sample full-FID file. The validator reads each `.seq`
back through Pulseq and checks gradient waveform fidelity, ADC-centred
k-space, period closure, dwell/period timing, hardware limits, and sample
counts, including the final return to `k=0`. See
[Pulseq round-trip guide](docs/PULSEQ_ROUNDTRIP_CN.md).

For the above parameters:

```text
Tperiod = Npp × adcDwell = 128 × 5 µs = 640 µs
SBW     = 1 / Tperiod    = 1562.5 Hz
Δf      = SBW / Nspec    = 3.0518 Hz
NADC    = Npp × Nspec    = 65536
```

---

## Documentation

- [Quick start](docs/QUICKSTART_CN.md)
- [API reference](docs/API_CN.md)
- [Periodic MRSI theory](docs/THEORY_CN.md)
- [GUI user guide](docs/GUI_CN.md)
- [Examples](docs/EXAMPLES_CN.md)
- [Comparison with other methods](docs/COMPARISON_CN.md)
- [Developer guide](docs/DEVELOPER_GUIDE_CN.md)
- [Changelog](CHANGELOG.md)

---

## Main design principle

The toolbox separates the **compact spatial period** from the **full spectral readout**:

```text
compact period:     k_period[Npp, 3], G_period[Npp, 3]
full readout:       repeat(G_period, Nspec)
raw data structure: data[petal, spectral_time, point_within_period, coil]
```

This is the key difference from generic non-Cartesian MRI optimization tools.

---

## License

See [LICENSE.txt](LICENSE.txt).

The bundled Pulseq MATLAB fallback remains under the Pulseq license; see
`third_party/pulseq/LICENSE` and `third_party/pulseq/AUTHORS`.


## Reproducibility release candidate

See [`reproducibility/README.md`](reproducibility/README.md), [`GITHUB_RELEASE_CHECKLIST.md`](GITHUB_RELEASE_CHECKLIST.md), and [`ENVIRONMENT_TEMPLATE.md`](ENVIRONMENT_TEMPLATE.md). Demo plots are **not** substitutes for manuscript figures.
