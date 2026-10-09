# API Reference

本文档列出工具包的主要公开接口。单位约定如下：

```text
k-space         cycles/m
Gradient G      T/m
Slew rate S     T/m/s
Time            s
GammaBar        cycles/s/T, i.e. gamma / 2π
```

---

## 1. Main API

### `nc_mrsi_gradopt`

```matlab
result = nc_mrsi_gradopt(ktraj_target, sys, acq, opt)
```

优化非笛卡尔 MRSI 梯度波形。

#### Inputs

`ktraj_target`

```matlab
[N × D] matrix, D = 1, 2, or 3
```

目标 k-space 轨迹，单位 `cycles/m`。周期性 MRSI 模式下，`N` 应等于 `Npp`，即一个 compact period 的点数。

`sys`

```matlab
sys.Gmax      % maximum gradient amplitude, T/m
sys.Smax      % maximum slew rate, T/m/s
sys.dtGrad    % gradient raster, s
sys.gammaBar  % gamma / 2π, cycles/s/T
```

示例：

```matlab
sys.Gmax = 80e-3;
sys.Smax = 200;
sys.dtGrad = 5e-6;
sys.gammaBar = 17.235e6;  % 31P
```

`acq`

普通固定读出：

```matlab
acq.nADC
acq.dtADC
acq.spectralBW
acq.readoutTime
acq.adcDelay
```

周期性 MRSI：

```matlab
acq.Npp                 % samples per period
acq.Nspec               % repeated periods / spectral points
acq.nADC                % Npp, compact period for optimization
acq.nADCtotal           % Npp * Nspec
acq.dtADC               % dwell inside period
acq.periodTime          % Npp * dtADC
acq.spectralBW          % 1 / periodTime
acq.spectralResolution  % spectralBW / Nspec
```

建议通过 `setup_periodic_mrsi_readout` 创建。

`opt`

```matlab
opt.mode                    % 'direct', 'fixed_duration', 'symmetric_fixed', 'periodic_fixed'
opt.periodic                % true/false
opt.symmetry                % 'none', 'antisymmetric_k', 'even_k'
opt.safetyMargin            % e.g. 0.95
opt.lambdaSlew              % slew smoothness regularization
opt.lambdaSmooth            % second-difference smoothness regularization
opt.forceGStartZero         % force G(1)=0
opt.forceGEndZero           % force G(end)=0
opt.forceGPeriodicEqual     % force G(end)=G(1)
opt.forceSlewPeriodicEqual  % force cyclic slew continuity
opt.maxControlPoints        % control points for nonperiodic solvers
```

周期性 MRSI 推荐：

```matlab
opt.mode = 'periodic_fixed';
opt.periodic = true;
opt.symmetry = 'none';
opt.forceGStartZero = false;
opt.forceGEndZero = false;
opt.forceGPeriodicEqual = true;
opt.forceSlewPeriodicEqual = true;
```

#### Outputs

`result` fields:

```matlab
result.G              % [N × D] gradient waveform, T/m
result.S              % slew waveform, T/m/s; cyclic in periodic mode
result.ktraj_actual   % actual k-space from gradient integration
result.ktraj_target   % target k-space on gradient raster
result.ktraj_adc      % ADC-sampled k-space trajectory
result.time_grad      % gradient sample time vector
result.time_adc       % ADC sample time vector
result.opts           % merged options
result.report         % validation report
```

---

## 2. Periodic MRSI timing

### `setup_periodic_mrsi_readout`

```matlab
acq = setup_periodic_mrsi_readout(Npp, Nspec, adcDwell)
acq = setup_periodic_mrsi_readout(..., 'adcDelay', 0)
```

构建周期性 MRSI timing structure。

#### Definition

```text
Npp      = points per spatial period
Nspec    = number of repeated periods / spectral points
adcDwell = dwell time inside one period
```

Derived values:

```matlab
acq.nADCtotal          = Npp * Nspec
acq.periodTime         = Npp * adcDwell
acq.spectralBW         = 1 / acq.periodTime
acq.spectralResolution = acq.spectralBW / Nspec
```

---

## 3. Trajectory generation

### `make_periodic_rosette_3d`

```matlab
ktraj = make_periodic_rosette_3d(params)
```

生成一个 compact 3D PETALUTE-like rosette period。

#### Parameters

```matlab
params.Npp       % samples per period
params.Kmax      % cycles/m
params.phi       % polar angle, rad
params.beta      % initial angular phase, rad
params.nRadial   % radial frequency multiplier, default 1
params.nAngular  % angular frequency multiplier, default 1
params.shape     % 'petalute_paper', 'legacy_sin2', 'legacy_signed_2pi'
```

默认公式：

```matlab
u = (0:Npp-1).' / Npp;
radial = sin(pi * nRadial * u);
theta  = pi * nAngular * u + beta;

kx = Kmax*cos(phi).*radial.*cos(theta);
ky = Kmax*cos(phi).*radial.*sin(theta);
kz = Kmax*sin(phi).*radial;
```

注意：不包含 `u=1`，因为该点是下一个周期的第一个点。

### `make_periodic_rosette_2d`

```matlab
ktraj = make_periodic_rosette_2d(params)
```

生成一个 compact 2D rosette period。参数与 3D 类似，但输出为 `[Npp × 2]`。

### `make_concentric_crt_set`

```matlab
crtSet = make_concentric_crt_set(params)
```

生成完整 CRT acquisition target set。这里 `Npp` 是每个 ring 的采样点数：

```matlab
params.Npp = 128;
params.Kmax = 25;
params.nRings = 6;
params.rMin = 1/0.240;
params.mode = 'multi_ring_set';
```

输出：

```matlab
crtSet.targets{rr}       % [Npp x 2], 第 rr 个独立 compact period
crtSet.targetStack       % [Npp x 2 x nRings]
crtSet.NppPerRing
crtSet.totalSpatialSamples % Npp*nRings
```

### `optimize_concentric_crt_set`

```matlab
resultSet = optimize_concentric_crt_set(params, sys, acq, opt, setOpts)
```

逐环独立优化完整 CRT set。`resultSet.rings(rr)` 是标准
`nc_mrsi_gradopt` 结果，并额外包含：

```matlab
resultSet.rings(rr).ringIndex
resultSet.rings(rr).ringRadius
resultSet.rings(rr).pre
resultSet.rings(rr).post
resultSet.rings(rr).sequence
resultSet.rings(rr).full
resultSet.summary.allFeasible
```

`post` 保存真实 return-to-origin 梯度及其局部求解诊断；`sequence` 保存
pre + ADC ring + post 的完整模块、ADC mask 和 segment code。自 v0.3.8
起，`sequence.ktraj_actual` 只由 `sequence.G` 在统一时间轴上连续重积分
得到，不再拼接三个分段各自保存的 k-space。完整模块回零误差使用：

```matlab
resultSet.rings(rr).sequence.returnErrorNorm
resultSet.summary.worstReturnError
```

full-FID 使用相同规则：

```matlab
resultSet.rings(rr).full.G_with_module
resultSet.rings(rr).full.ktraj_with_module
resultSet.rings(rr).full.returnErrorNorm
```

`multi_ring_period` 与 `multi_ring_set` 不同：前者是所有环共用总 Npp
并带径向连接段的 stress test；后者才是每环固定 Npp 的正常 CRT 采集。

### `design_post_gradient_to_origin`

```matlab
post = design_post_gradient_to_origin(kStart,GStart,opts,Npost)
```

求解 ADC 外的 post-gradient，使其从末端读出梯度开始，产生
`-kStart` 梯度矩，并以 `k=0`、`G=0` 结束，同时满足逐轴 gradient
和 slew 限制。

### Other trajectory functions

```matlab
make_rosette_2d(params)
make_rosette_3d(params)
make_spiral(params)
make_radial(params)
make_cones(params)
import_ktraj(filename)
```

这些函数主要用于非周期或常规 fixed-duration trajectory 测试。

---

## 4. Periodic solver internals

### `periodic_fixed_duration_optimize`

```matlab
G = periodic_fixed_duration_optimize(ktraj_target, opts)
```

只优化一个 compact period。一般不需要直接调用，推荐通过 `nc_mrsi_gradopt` 调用。

周期约束包括：

```text
sum(G) = 0                      k-space closure
G(end) = G(1)                   optional gradient continuity
slew(end boundary)=slew(start)  optional slew continuity
cyclic slew limit               includes G(1)-G(end)
```

### `integrate_periodic_gradient_samples`

```matlab
ktraj = integrate_periodic_gradient_samples(G, opts, k0)
```

使用周期性 MRSI 的离散积分模型，从一个 compact period 的梯度计算实际 k-space。

### `compute_cyclic_slew`

```matlab
S = compute_cyclic_slew(G, dt)
```

计算周期性 slew：

```matlab
S = [diff(G); G(1,:) - G(end,:)] / dt;
```

最后一行是周期边界从本周期末端到下一周期起点的 slew。

---

## 5. MRSI utilities

### `check_periodic_closure`

```matlab
report = check_periodic_closure(ktraj, G, opts)
```

检查周期闭合与边界连续性。

常用字段：

```matlab
report.GPeriodicJumpNorm
report.SlewPeriodicJumpNorm
report.kNextStartErrorNorm
report.maxCyclicSlewAxis
report.maxCyclicSlewNorm
report.deltaKFromMomentNorm
```

### `expand_periodic_readout`

```matlab
full = expand_periodic_readout(resultPeriod, Nspec)
```

将一个 compact period 结果扩展为完整 FID readout：

```matlab
full.G = repmat(resultPeriod.G, [Nspec, 1]);
```

---

## 6. Export APIs

### `export_csv`

```matlab
export_csv(result, filename)
```

导出 `time, G, S, k` 到 CSV。

### `export_matlab_struct`

```matlab
export_matlab_struct(result, filename)
```

保存完整 `result` 结构到 `.mat`。

### `export_siemens_idea_txt`

```matlab
export_siemens_idea_txt(result, outPrefix)
```

导出 Siemens IDEA-friendly text waveform。

### `export_pulseq`

```matlab
export_pulseq(result, filename, seqOpts)
```

导出 Pulseq arbitrary gradients。周期结果会自动转换到 Pulseq 的
ADC 中心时间模型，并正确完成 T/m 到 Hz/m 的核种相关转换。

### `export_crt_ring_set_pulseq`

```matlab
[compactFiles, manifest] = export_crt_ring_set_pulseq( ...
    resultSet, outputDir, baseName, seqOpts)
```

逐环导出 compact 和 full-FID `.seq` 文件。`manifest` 保存文件名、
转换后的 Pulseq 模块和写出时序信息。

### `validate_crt_ring_set_pulseq`

```matlab
validation = validate_crt_ring_set_pulseq(resultSet, manifest)
```

重新读取全部 `.seq`，调用 Pulseq 的 `checkTiming`、
`waveforms_and_times` 和 `calculateKspacePP`，并生成 CSV、MAT、TXT
验证报告，并要求完整 Pulseq 模块最终回到 `k=0`。

---

## 7. GUI entry points

```matlab
startup_nc_mrsi_gradopt
nc_mrsi_gradopt_gui
launch_gui
```

`startup_nc_mrsi_gradopt` 会将工具包子目录加入 MATLAB path。
