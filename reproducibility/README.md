# Reproducibility / 可复现性

## Important scope
`make_demo_figures.m` generates **deterministic trajectory demo figures only**. They are **not** asserted to reproduce the manuscript figures, comparison benchmarks, or numerical results. `FIGURE_MANIFEST.csv` and `TABLE_MANIFEST.csv` enumerate missing paper-level reproduction assets.

## Software prerequisites
- MATLAB with `exportgraphics` and `writematrix` (R2020a+ is a practical starting requirement, **not verified**).
- Optimization Toolbox may be necessary for some optimization routines; confirm with `which quadprog`.
- Pulseq round-trip testing needs compatible Pulseq MATLAB functions and appropriate sequence configuration.
- Numerical equality of optimized trajectories may vary by MATLAB release, optimizer, and hardware. Record all three.

## Commands (from repository root)

```matlab
startup_nc_mrsi_gradopt
make_demo_figures
run_reproducibility_checks
```

For a clean MATLAB batch invocation from a shell (MATLAB on PATH):

```bash
matlab -batch "cd('/absolute/path/to/repo'); startup_nc_mrsi_gradopt; run_reproducibility_checks"
```

Output is written to `reproducibility/outputs/demo/`. Each variant exports original trajectory CSV, parameter/result MAT, 300 dpi PNG, and (when supported) vector SVG. `test_log.txt` logs each test and terminates with a nonzero error if any fails.

## Paper figure standard (must be completed before claiming paper reproduction)
For **every** panel: attach the committed script name, exact input file and SHA-256, full optimization parameter struct, software version, deterministic seed when applicable, quantitative expected metric/tolerance, final SVG/TIFF path, and a command callable without GUI interaction. The multi-toolbox benchmark needs the source datasets, scripts for each toolbox, pinned versions and a defined environment. Figures created through editorial design software require source artwork and an explicit statement that they are conceptual and not numerically generated.

The original authors must reconcile `MAIN-FIG-*` and `SUPP-FIG-*` entries against the final accepted manuscript. Do not label current demos as manuscript figures.
