# GUI User Guide

## v0.3.8 连续重积分显示

`All CRT rings` 中的 pre、ADC ring、周期闭合点和 post 均直接截取自
`result.rings(i).sequence.ktraj_actual`。该轨迹由完整
`sequence.G` 从统一初始位置连续重积分得到，GUI 不读取或拼接
`pre.ktraj_actual`、单周期 `ktraj_actual` 与 `post.ktraj_actual`。

## v0.3.7 CRT 真实完整模块显示

`All CRT rings` 子图同时显示每个 ring 独立的真实模块：

- 从 `k=0` 出发的真实 pre-gradient；
- 每个 ring 的 target（虚线）和 actual（实线）ADC 轨迹；
- 由该 ring 边界返回 `k=0` 的真实 post-gradient；
- `k=0` 起点/终点标记。

`CRT settings...` 提供：

```text
Add zero-start pre-gradient before ring
Pre-gradient samples (0=auto)
Add return-to-origin post-gradient
Post-gradient samples (0=auto)
```

pre/post 都位于 ADC 之外，但是真实参与完整模块的梯度、slew、矩和
回零验证。每个 ring 仍保持固定的 `Npp` 个 ADC 样本。

## v0.3.5 Pulseq verify

完成 `multi_ring_set` 优化后，点击右下角 `Pulseq verify`：

1. 选择输出目录；
2. GUI 逐环写出 compact 和 full-FID Pulseq 1.4.1 文件；
3. 自动重新读取全部文件；
4. 在输出目录生成 CSV、MAT 和 TXT round-trip 报告；
5. 状态栏显示最终 PASS/FAILED。

## v0.3.4 CRT multi-ring set

选择 `Concentric CRT 2D` 后，点击 `CRT settings...`，推荐使用：

```text
CRT mode = multi_ring_set
Number of rings = 6
Npp = 128
```

GUI 会生成并独立优化 6 个 compact-period ring；每个 ring 均有 128 个
ADC/trajectory samples。主图叠加显示全部真实 pre/target/actual/post
轨迹，并显示各 ring 完整模块的 gradient、slew 和 ADC-window k-space
error。保存 MAT 时，所有结果位于 `result.rings(1:6)`。

`multi_ring_period` 仍表示所有环和径向连接段共用一个总 Npp，仅用于
stress test。

## 启动

```matlab
startup_nc_mrsi_gradopt
nc_mrsi_gradopt_gui
```

---

## 主要参数说明

### `Npp = points/period`

一个完整空间轨迹周期内的点数。周期性 rosette MRSI 中常用：

```text
Npp = 96
```

### `Nspec = periods/FID`

FID 中重复的周期数，对应谱维时间点数。例如：

```text
Nspec = 512
```

### `ADC dwell inside period`

周期内部相邻空间采样点之间的时间间隔。例如：

```text
5 us
```

### Derived spectral bandwidth

GUI 自动计算：

```text
SBW = 1 / (Npp × ADC dwell)
```

### `ADC samples total`

GUI 自动计算：

```text
NADC = Npp × Nspec
```

---

## 推荐周期性 MRSI 设置

```text
Periodic MRSI mode      on
Mode                    periodic_fixed
Symmetry                none
Force G periodic        on
Force slew periodic     on
Force G start/end zero  off
```

不要对周期性 rosette 默认使用 `symmetric_fixed` 或强制 `G(1)=0, G(end)=0`，否则可能破坏周期连续性或使 actual k 偏离 target。

---

## 主图解释

GUI 主界面应重点查看：

```text
kx / ky / kz target vs actual
Gx / Gy / Gz
slew_x / slew_y / slew_z
k error
```

如果 actual k 明显偏离 target，优先检查：

```text
Npp 是否太小
Kmax 是否太大
Gmax/Smax 是否过低
forceSlewPeriodicEqual 是否过严
lambdaSlew / lambdaSmooth 是否过大
```

---

## Period diagnostics

诊断窗口用于只显示一个周期内的：

```text
k target vs actual
G waveform
cyclic slew
k error
```

对于周期性 MRSI，不建议把 49152 个 ADC 点全部画在同一张空间轨迹图中；应首先检查 compact period。

---

## K error popup

显示：

```text
Δkx = kx_actual - kx_target
Δky = ky_actual - ky_target
Δkz = kz_actual - kz_target
|Δk|
```

用于判断优化后的轨迹偏差是否可接受。
