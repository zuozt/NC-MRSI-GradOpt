# Public release readiness checklist (v0.3.8 review)

## Blocking items
- [ ] Replace `CITATION.cff` placeholder author with verified author names; set correct release date and matching license SPDX identifier.
- [ ] Choose an actual public redistribution license for proprietary original code **before** open publication. Current `LICENSE.txt` contains a disclaimer but does not grant clear usage/redistribution rights.
- [ ] Verify upstream origin, license, version/commit and attribution of bundled `third_party/pulseq`; obtain institutional approval for redistribution and preserve all required notices.
- [ ] Freeze final TBME manuscript/figure numbering, provide original figure scripts and benchmark input data, and fill every missing row in `FIGURE_MANIFEST.csv` / `TABLE_MANIFEST.csv`.
- [ ] Establish required MATLAB release, toolbox dependencies, external solver/toolbox dependencies and known output tolerances; test on a clean installation.
- [ ] Verify intended periodic closure, G/S constraints, Pulseq ADC-centre timing, safety margins, and actual sequence export against fixed acceptance thresholds.
- [ ] Resolve all known solver/figure mismatches, including PETALUTE reference formula versus legacy sin-squared construction.

## Strongly recommended
- [ ] Add MATLAB GitHub Actions tests after a clean licensed runner or compatible MATLAB CI environment is available.
- [ ] Add machine-readable benchmark CSVs and comparison environment files with checksums.
- [ ] Make each paper figure a no-GUI single entrypoint and include SVG/TIFF exports and MAT/CSV source data.
- [ ] Separate core repository from optional large figures/reconstruction inputs via Zenodo versioned archive, DOI, and checksums.
- [ ] Use Git tag `v0.4.0` only after scientific testing; attach release notes and archive DOI.
- [ ] Document software use limitations, units, and hardware validation responsibilities.
