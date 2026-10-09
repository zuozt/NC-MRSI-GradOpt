# Developer Guide

## Coding style

- MATLAB functions should use explicit units in comments.
- Public APIs should accept structures rather than long positional argument lists.
- Periodic MRSI functions should clearly distinguish `Npp`, `Nspec`, and `nADCtotal`.
- Do not silently treat `Npp*Nspec` as one nonperiodic spatial trajectory.

---

## Adding a new trajectory

Add a new generator under `trajectories/`, for example:

```matlab
function ktraj = make_periodic_mytrajectory_3d(params)
```

Recommended fields:

```matlab
params.Npp
params.Kmax
params.phi
params.beta
```

The function should return one compact period:

```matlab
ktraj  % [Npp × D], cycles/m
```

Do not include a duplicated endpoint if it is the first point of the next period.

---

## Adding a new optimizer

Add the solver under `core/` and expose it through `nc_mrsi_gradopt.m` by adding a new `opt.mode` branch.

A periodic solver should report or enforce:

```text
sum(G) = 0
cyclic slew
G boundary mismatch
slew boundary mismatch
Gmax/Smax feasibility
```

---

## Tests

Run:

```matlab
startup_nc_mrsi_gradopt
run_all_tests
```

Recommended additional tests for periodic MRSI:

```text
1. Npp preserved exactly
2. k closure from gradient moment
3. cyclic slew includes boundary term
4. full readout is repeat(G_period, Nspec)
5. no duplicated endpoint in compact target
```

---

## Common pitfalls

### Treating total ADC as target samples

Wrong:

```text
Ntarget = Npp * Nspec
```

Correct:

```text
Ntarget = Npp
NADCtotal = Npp * Nspec
```

### Using nonperiodic boundary conditions

For periodic MRSI, do not force:

```text
G(1)=0 and G(end)=0
```

unless explicit ramp-in/ramp-out blocks are added outside the repeated compact period.

### Ignoring boundary slew

Always check:

```matlab
S = [diff(G); G(1,:) - G(end,:)] / dt;
```

not only `diff(G)/dt`.
