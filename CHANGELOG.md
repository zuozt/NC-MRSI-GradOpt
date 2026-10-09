# Changelog

## v0.3.8 - Continuous complete-module reintegration

- Replaced all segment-wise k-space concatenation in the toolbox complete
  module with one continuous reintegration of `sequence.G`.
- Reintegrated `full.ktraj_with_module` from `full.G_with_module` on the same
  unified time convention for every full-FID expansion.
- Added explicit readout-closure indices and points at the readout-to-post
  boundary.
- Changed per-ring and aggregate return errors to use the continuously
  reintegrated complete module. The post-gradient solver residual is retained
  separately as a diagnostic.
- Updated the all-rings GUI plot so pre-gradient, ring plus closure, and
  post-gradient are sliced only from `sequence.ktraj_actual`.
- Added regression tests proving cached segment trajectories cannot affect the
  complete-module trajectory and checking full-FID continuous reintegration.

## v0.3.7 - Real CRT complete-module trajectories

- Replaced the v0.3.6 display-only origin/outward/return guide with real,
  independently solved pre-readout-post trajectories for every CRT ring.
- Added `design_post_gradient_to_origin`, which starts at the final readout
  gradient, cancels the remaining k-space moment, and ends at `k=0`, `G=0`
  under the configured axis-wise gradient and slew constraints.
- Every ring now saves `post` and `sequence` structures. `sequence` contains
  the complete gradient waveform, k-space path, time axis, ADC mask, and
  pre/ADC/post segment codes.
- Added complete-module feasibility, maximum gradient/slew, and return-error
  summaries across rings.
- Updated GUI k-space, gradient, slew, and report panels to show the real
  complete modules.
- Added `*_full_module.csv` exports.
- Corrected Pulseq post-gradient generation: it now cancels k-space moment
  instead of only ramping gradient amplitude to zero. Round-trip validation
  now requires the complete `.seq` module to end at k=0.

## v0.3.6 - CRT origin/outward/return GUI display

- Updated the GUI panel `All CRT rings: target (dashed) vs actual (solid)` to
  show the full visual order from `k=0`, through the ordered ring-start
  positions, and back to `k=0`.
- Added separate outward and return line styles, direction arrows, an origin
  marker, ring-start markers, and a legend that distinguishes ADC ring
  trajectories from non-ADC navigation guides.
- Added the CRT setting `showOriginReturnGuide`, enabled by default.
- Kept `multi_ring_set` unchanged: every ring remains an independent
  `Npp`-sample ADC period. The new guide is display-only and is not included
  in target/actual errors, closure metrics, gradient limits, or Pulseq
  round-trip metrics.
- Superseded by v0.3.7; the display-only guide is no longer used.

## v0.3.5 - Pulseq ADC-centred export and round-trip validation

- Corrected gradient units: toolbox waveforms in T/m are multiplied by the
  active nucleus-specific gamma-bar before entering Pulseq's Hz/m API.
- Added an ADC-centred conversion from the toolbox's interval-moment model to
  Pulseq's linearly interpolated gradient-centre model.
- Added Pulseq-specific pre-gradient and post-gradient design with explicit
  boundary values, moment constraints, slew checks, and safe return to zero.
- Added separate compact and full-FID exports for every CRT ring. Full-FID
  export repeats 128-sample gradient-ADC blocks rather than creating one large
  ADC event.
- Added automatic write-read validation using `Sequence.read`,
  `checkTiming`, `waveforms_and_times`, and `calculateKspacePP`.
- Added CSV, MAT, and TXT round-trip reports with waveform, k-space, closure,
  timing, hardware, and pass/fail metrics.
- Bundled the user-supplied Pulseq MATLAB source as a fallback dependency;
  an existing site Pulseq installation remains preferred.
- Default `.seq` output is Pulseq 1.4.1-compatible; current-format output is
  selectable through `seqOpts.compatibility`.

## v0.3.4 - Complete CRT multi-ring set

- Added `multi_ring_set`, in which `Npp` means samples per ring.
- Added `make_concentric_crt_set`; six rings with `Npp=128` now produce six
  independent 128-sample targets (768 total spatial samples).
- Added `optimize_concentric_crt_set` for independent per-ring optimization,
  periodic validation, zero-start pre-gradient design, and full-FID expansion.
- Added aggregate per-ring feasibility and error summaries.
- Added combined multi-ring CSV export with ring/sample identifiers.
- Added batch Pulseq export with one pre-gradient + gradient–ADC module per
  independent CRT ring.
- Updated the GUI to generate, optimize, display, save, and export a complete
  CRT ring set.
- Retained `multi_ring_period` only as an explicitly labeled diagnostic stress
  test with a shared total-Npp budget and radial connectors.
- Updated the default GUI CRT example to proton parameters
  (`gamma/2pi=42.5774789 MHz/T`), `Npp=128`, `Gmax=20 mT/m`, and
  `Smax=180 T/m/s`.
- Fixed periodic CSV export so cyclic slew arrays with N rows are not padded
  to an invalid N+1 rows.

## v0.3.3 - CRT target-fidelity mode and Npp synchronization

- Fixed periodic-GUI synchronization: in Periodic MRSI mode, `Target samples` is now an alias of `Npp`. Editing either field updates the compact-period length used for target generation and optimization. This prevents accidental runs such as `Ntarget=160` but `Npp=96`.
- Added CRT target-fidelity mode. For `Concentric CRT 2D`, hard repeated-boundary equalities `G(end)=G(1)` and C1 equality are disabled by default; k-space closure and cyclic slew limits are still enforced. This allows hardware-feasible circular rings to be tracked much more closely.
- Added CRT GUI checkbox `Hard C0/C1 equality at ring boundary` for users who intentionally want the stricter boundary condition.
- Kept zero-start CRT pre-gradient before ADC readout.

## v0.3.2 - CRT zero-start pre-gradient

- Added optional non-ADC pre-gradient for CRT single-ring readouts.
- The pre-gradient starts at zero gradient, prephases k-space to the selected ring start, and ends at the first readout gradient.
- Added GUI controls for enabling the CRT pre-gradient and choosing pre-gradient samples.
- Updated Pulseq export to write the pre-gradient before the ADC readout block.
- Updated CSV export to optionally generate a companion *_with_pre.csv file.

## v0.3.1

- Changed Concentric CRT default from `multi_ring_period` to `single_ring`.
- Clarified that one CRT compact MRSI period should normally represent one circular ring.
- Retained `multi_ring_period` as a diagnostic stress-test mode only.
- Updated the CRT settings dialog warning text and default ring index.
- Updated the CRT example to optimize a single ring and generate all-ring target sets separately.
- Added optional `ringRadius` override to `make_concentric_crt_2d`.

## v0.2.8

- Added C1-like periodic boundary handling for repeated MRSI waveforms.
- Added cyclic gradient continuity option: `G(end)=G(1)`.
- Added cyclic slew continuity option.
- Added `compute_cyclic_slew`.
- Updated periodic solver defaults for MRSI repeated readouts.

## v0.2.7

- Removed inappropriate forced `G(1)=0` and `G(end)=0` defaults for periodic MRSI.
- Added cyclic finite-difference baseline for compact periodic trajectories.
- Improved periodic k-space closure handling.

## v0.2.6

- Updated periodic 3D rosette target to use the PETALUTE-style reference formula.
- Added `beta` initial angular phase support.

## v0.2.5

- Added compact-period periodic solver.
- Stopped treating `Npp*Nspec` as one long nonperiodic target in periodic mode.

## v0.2.4

- Added explicit periodic MRSI timing definitions: `Npp`, `Nspec`, `nADCtotal`, `spectralBW`.

## v0.2.0

- Initial GUI framework with fixed-duration trajectory optimization, trajectory generators, export utilities, and examples.
