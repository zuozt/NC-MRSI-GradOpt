# Quick Start

本文档给出 `NC-MRSI GradOpt GUI` 的最小运行流程，适合第一次测试周期性 rosette MRSI 梯度优化。

---

## 1. 启动工具包

```matlab
cd('/path/to/NC_MRSI_GradOpt_GUI')
startup_nc_mrsi_gradopt
```

启动 GUI：

```matlab
nc_mrsi_gradopt_gui
```

---

## 2. GUI 推荐参数

周期性 31P rosette MRSI 可先用以下参数测试：

```text
Trajectory              Rosette 3D
Periodic MRSI mode      on
Mode                    periodic_fixed
Symmetry                none
Npp = points/period     96
Nspec = periods/FID     512
ADC dwell inside period 5 us
Kmax                    25 cycles/m
Phi                     0 deg
Beta                    0 deg
Radial oscillations     1
Angular rotations       1
Gmax                    80 mT/m
Smax                    200 T/m/s
Nucleus                 31P
GammaBar                17.235e6 cycles/s/T
```

其中：

```text
Npp   = 一个完整空间轨迹周期内的采样点数
Nspec = 周期重复次数，也就是谱维时间点数
```

不要把 `Npp × Nspec` 当成一个长的非周期 k-space 轨迹来优化。

---

## 3. 命令行测试

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

p = struct();
p.Npp = Npp;
p.Kmax = 25;
p.phi = 0;
p.beta = 0;
p.nRadial = 1;
p.nAngular = 1;
p.shape = 'petalute_paper';
k_target = make_periodic_rosette_3d(p);

opt = struct();
opt.mode = 'periodic_fixed';
opt.periodic = true;
opt.symmetry = 'none';
opt.forceGPeriodicEqual = true;
opt.forceSlewPeriodicEqual = true;
opt.safetyMargin = 0.95;

result = nc_mrsi_gradopt(k_target, sys, acq, opt);
plot_gradopt_result(result);
```

---

## 4. 检查周期连续性

```matlab
report = check_periodic_closure(result.ktraj_actual, result.G, result.opts);
disp(report)
```

重点看：

```text
GPeriodicJumpNorm       周期边界梯度跳变
SlewPeriodicJumpNorm    周期边界 slew 跳变
kNextStartErrorNorm     下个周期 k 起点漂移
maxCyclicSlewAxis       包含边界的最大轴向 slew
```

---

## 5. 导出

```matlab
export_csv(result, 'rosette_period.csv');
export_matlab_struct(result, 'rosette_period.mat');
```

Pulseq MATLAB 源码已作为 fallback 包含在工具箱中；如果 MATLAB path
中已有 Pulseq，则优先使用已有版本：

```matlab
export_pulseq(result, 'rosette_period.seq');
```

对于完整 CRT 六环结果，推荐同时完成 compact/full-FID 导出和读回：

```matlab
seqOpts.compatibility = '1.4.1';
seqOpts.fullRepeats = 512;
[~, manifest] = export_crt_ring_set_pulseq( ...
    resultSet, 'pulseq_export', 'CRT_1H', seqOpts);
validation = validate_crt_ring_set_pulseq(resultSet, manifest);
assert(validation.overallPass);
```
