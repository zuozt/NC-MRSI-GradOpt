# Contributing

Suggested workflow:

1. Create a branch for one feature or bug fix.
2. Add or update a minimal example under `examples/`.
3. Add a validation script under `tests/` when possible.
4. Run:

```matlab
startup_nc_mrsi_gradopt
run_all_tests
```

For periodic MRSI changes, include checks for:

```text
Npp preservation
k-space closure
cyclic gradient continuity
cyclic slew continuity
Gmax/Smax feasibility
```
