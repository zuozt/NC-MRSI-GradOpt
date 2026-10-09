# Examples

## 1. GUI example

```matlab
startup_nc_mrsi_gradopt
nc_mrsi_gradopt_gui
```

使用推荐参数：

```text
Trajectory = Rosette 3D
Periodic MRSI mode = on
Mode = periodic_fixed
Npp = 96
Nspec = 512
ADC dwell = 5 us
Kmax = 25 cycles/m
```

---

## 2. API example: periodic rosette

```matlab
startup_nc_mrsi_gradopt;

Npp = 96;
Nspec = 512;
adcDwell = 5e-6;

sys.Gmax = 80e-3;
sys.Smax = 200;
sys.dtGrad = adcDwell;
sys.gammaBar = 17.235e6;

acq = setup_periodic_mrsi_readout(Npp, Nspec, adcDwell);

params.Npp = Npp;
params.Kmax = 25;
params.phi = 0;
params.beta = 0;
params.nRadial = 1;
params.nAngular = 1;
params.shape = 'petalute_paper';
k_period = make_periodic_rosette_3d(params);

opt.mode = 'periodic_fixed';
opt.periodic = true;
opt.symmetry = 'none';
opt.forceGPeriodicEqual = true;
opt.forceSlewPeriodicEqual = true;
opt.safetyMargin = 0.95;

result = nc_mrsi_gradopt(k_period, sys, acq, opt);
plot_gradopt_result(result);
```

---

## 3. Expand compact period to full readout

```matlab
full = expand_periodic_readout(result, Nspec);
```

This creates:

```matlab
full.G              % [Npp*Nspec × D]
full.ktraj_actual   % full integrated k trajectory
```

---

## 4. Export

```matlab
export_csv(result, 'period_result.csv');
export_matlab_struct(result, 'period_result.mat');
export_siemens_idea_txt(result, 'period_result_idea');
```

Pulseq export:

```matlab
export_pulseq(result, 'period_result.seq');
```

---

## 5. Custom trajectory import

```matlab
ktraj = import_ktraj('my_target_k.csv');
result = nc_mrsi_gradopt(ktraj, sys, acq, opt);
```

For periodic MRSI, the imported trajectory should contain exactly one compact period with `Npp` rows.
