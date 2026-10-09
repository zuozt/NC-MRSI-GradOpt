# NC_MRSI_GradOpt_GUI v0.2.7 periodic boundary fix

本版本基于 v0.2.6，修正 PETALUTE 3D rosette target 与 periodic solver 边界条件不一致的问题。

详见 `PATCH_NOTES_PERIODIC_BOUNDARY_v0.2.7_CN.md`。

# NC-MRSI-GradOpt

**NC-MRSI-GradOpt** 是一个面向非笛卡尔 MRSI 的 MATLAB 梯度波形优化工具箱原型。其目标是将任意二维或三维 k-space 轨迹转换为满足 MRI 硬件约束的梯度波形，并输出实际积分后的 k-space 轨迹、ADC 采样轨迹和约束验证报告。新版包含传统 MATLAB GUI，可通过界面调节轨迹、硬件、MRSI timing 和优化参数，并实时展示 k-space、gradient 和 slew rate。

## 主要功能

1. 输入任意 1D/2D/3D k-space 轨迹，单位为 cycles/m。
2. 支持固定读出时长的梯度优化，适合 MRSI 的 ADC dwell、spectral bandwidth 和 readout duration 约束。
3. 支持梯度强度和 slew rate 轴向约束。
4. 支持起始和结束梯度强制为 0。
5. 支持中心反对称 k-space 对应的梯度对称约束。
6. 支持单个 base petal 优化后通过三维旋转生成多 petal 轨迹。
7. 自动重新积分梯度得到 actual k-space，用于闭环验证。
8. 提供 CSV、MAT、Siemens IDEA 中间格式和 Pulseq 辅助导出函数。
9. 提供 rosette、spiral、radial、cones 等示例轨迹生成函数。
10. 提供 GUI 界面，支持参数调节、目标轨迹生成、一键优化、k-space/gradient/slew-rate 显示、CSV/MAT 导出。

## 快速开始

```matlab
cd NC_MRSI_GradOpt
startup_nc_mrsi_gradopt

sys.Gmax = 80e-3;          % T/m
sys.Smax = 200;            % T/m/s
sys.dtGrad = 10e-6;        % s
sys.gammaBar = 17.235e6;   % Hz/T, 31P

acq = setup_mrsi_readout(1024, 5000);  % 1024 ADC points, 5 kHz spectral BW

opt.mode = 'symmetric_fixed';
opt.symmetry = 'antisymmetric_k';
opt.forceGStartZero = true;
opt.forceGEndZero = true;
opt.safetyMargin = 0.95;
opt.maxControlPoints = 2048;   % 避免 1024 ADC + 10 us raster 形成超大 QP

params.N = acq.nADC;
params.Kmax = 100;
params.nRadial = 4;
params.nAngular = 1;
params.phi = pi/9;
ktraj = make_rosette_3d(params);

result = nc_mrsi_gradopt(ktraj, sys, acq, opt);
plot_gradopt_result(result);
export_csv(result, 'rosette31P_gradient.csv');
```


## GUI 使用方式

推荐先启动 GUI 检查参数和波形：

```matlab
cd NC_MRSI_GradOpt
startup_nc_mrsi_gradopt
nc_mrsi_gradopt_gui
```

也可以运行：

```matlab
launch_gui
% 或
run examples/example_launch_gui.m
```

GUI 左侧可调节：

- 轨迹类型：Rosette 2D、Rosette 3D、Spiral 2D、Radial 2D、Cones 3D，或从 workspace/CSV 导入任意 k-space 轨迹；
- 硬件参数：Gmax、Smax、gradient raster、核素对应的 gamma/2pi；
- MRSI timing：ADC samples、spectral bandwidth、ADC delay；
- 优化参数：fixed_duration、symmetric_fixed、direct、symmetry、safety margin、control points 和正则化参数。

GUI 右侧显示：

- target 与 actual k-space trajectory；
- k-space error；
- gradient waveform；
- slew-rate waveform；
- feasibility report。

默认 GUI 使用较小的 ADC samples 和 control points，便于快速测试。用于真实序列前应增加采样点和控制点，并检查输出报告。

## 推荐开发流程

第一阶段建议优先使用：

```matlab
examples/example_2d_rosette_fixed_duration.m
examples/example_3d_rosette_mrsi.m
```

运行基础测试：

```matlab
cd tests
run_all_tests
```

## 核心设计思想

MRSI 中 readout duration 通常由 ADC dwell、谱宽和谱点数决定，不能像普通非笛卡尔成像那样只追求最短时间。因此，本工具箱的核心模式是：

```text
任意目标 k-space 轨迹
→ 固定读出时长内的约束梯度优化
→ 重新积分得到 actual k-space
→ ADC sampling 与约束闭环验证
```

对于 rosette/petal 类轨迹，推荐只优化一个 base petal，然后通过旋转矩阵生成多个 petal：

```matlab
base = design_single_petal(ktraj, sys, acq, opt);
petals = generate_multipetal_readout(base, rotations);
```

这样可以保证各个 petal 的梯度幅值、slew rate 和 timing 完全一致，避免独立优化带来的微小差异。

## 重要限制

1. 当前版本的固定时间优化使用 component-wise 约束，即分别限制 Gx/Gy/Gz 和 Sx/Sy/Sz。部分扫描仪也按轴限制；如果需要严格矢量范数约束，需要用 nonlinear programming、SOCP 或自定义优化器扩展。
2. 默认 `opt.maxControlPoints=2048`，当 gradient raster 点数很大时先在控制点网格优化，再插值到 gradient raster 并重新积分验证。需要更高精度时可增大该值，但内存和计算时间会增加。
3. 如果 MATLAB 没有 Optimization Toolbox，则 `quadprog` 不可用，工具箱会使用 projected fallback。fallback 主要用于保持可运行，不建议作为最终扫描方案。
4. `export_pulseq` 需要 Pulseq MATLAB 工具箱；如果没有安装，会自动导出 CSV fallback。
5. Siemens IDEA 导出目前是中间 CSV/TXT 格式，不是可直接编译的 IDEA C++ 代码。
6. 所有扫描前都需要在目标平台上重新检查 gradient raster、单位、最大梯度、最大 slew、ADC delay 和实际 k-space 积分。

## 文件结构

```text
core/           核心优化、积分、验证函数
constraints/    梯度、slew、边界和对称约束
trajectories/   rosette、spiral、radial、cones 和导入函数
mrsi/           MRSI timing、petal 旋转和谱采样检查
export/         CSV、MAT、Pulseq、Siemens IDEA 中间格式导出
visualization/  k-space、gradient、slew 和 error 绘图
gui/            MATLAB 图形界面
docs/           理论和接口说明
examples/       示例脚本
tests/          基础测试
```

## 建议引用/说明

该工具箱目前是研究原型，适合用于非笛卡尔 MRSI 梯度波形设计、仿真和序列开发前期验证。实际上机前，需要由序列工程师根据具体 MRI 平台进行安全校验。

---

## v0.2.4 周期性 MRSI 核心修正

本版本重新梳理了周期性 MRSI 的数学计算。关键原则是：

```text
Npp = 一个完整空间轨迹周期内的点数
Nspec = 周期重复次数，也就是谱维/FID 点数
ADC samples total = Npp × Nspec
ADC dwell = 周期内部空间采样间隔
spectral BW = 1 / (Npp × ADC dwell)
```

例如 PETALUTE-like 31P rosette：

```text
Npp = 96
Nspec = 512
ADC dwell = 5 us
ADC samples total = 49152
Tperiod = 480 us
spectral BW = 2083.33 Hz
spectral resolution = 4.069 Hz
```

GUI 中应使用：

```text
Periodic MRSI mode = enabled
Target samples/period = 96
Npp = points/period = 96
Nspec = periods/FID = 512
ADC dwell inside period = 5 us
```

优化只针对一个 compact period。完整 readout 由该周期重复得到：

```matlab
G_full = repmat(G_period, [Nspec, 1]);
```

更多细节见：

```text
docs/PERIODIC_MRSI_MATH_CN.md
PATCH_NOTES_PERIODIC_CORE_v0.2.4_CN.md
```


## v0.2.8 periodic C1 boundary fix

周期性 MRSI 模式现在不仅检查 k-space 闭合，还默认强制周期边界的梯度强度连续 `G(end)=G(1)`，并强制首末 slew 连续 `G(2)-G(1)=G(end)-G(end-1)`。求解器同时使用 cyclic slew 限制，包含从本周期末端到下周期起点的切换率。

## v0.3.0 CRT GUI 参数入口

GUI 左侧新增 `CRT settings...` 按钮。选择 `Concentric CRT 2D` 后，可用该按钮设置 CRT 专用参数，包括 ring 数、single-ring index、turns per ring、inner radius、transition fraction、alternate direction，以及基于 FOV/nominal resolution 自动推导 Kmax 和 ring 数。


## v0.3.1 CRT 使用建议

Concentric CRT 2D 的推荐 compact-period 定义已经改为：

```text
one compact MRSI period = one circular ring
```

也就是说，在 GUI 中建议选择 `Concentric CRT 2D` 后点击 `CRT settings...`，使用：

```text
CRT mode = single_ring
```

不同 ring 半径应通过不同 `ringIndex` 分别生成/优化/采集，而不是在一个 480 us compact period 内同时走完所有 rings。`multi_ring_period` 仍保留，但仅建议作为 stress-test 使用；它会把多个 rings 和 connector 放入同一个 period，通常会导致 direct gradient/slew 需求过高，优化结果偏离 target。

推荐初始参数：

```text
FOV = 240 mm
Nominal resolution = 20 mm
Npp = 96
Nspec = 512
dwell = 5 us
CRT mode = single_ring
ringIndex = 6
nRings = 6
turns/ring = 1
```

如果 outer ring 优化效果差，先把 `ringIndex` 改为 3 或降低 `Kmax`。


## v0.3.2 CRT pre-gradient 使用说明

对于 Concentric CRT 2D 的 single_ring 模式，建议启用 `Add zero-start pre-gradient before ring`。该 pre-gradient 不在 ADC 内采样，作用是从 `G=0` 出发，将 k-space 预相位到 ring 起点，并在 ADC 开始前达到 readout 的第一个梯度值。

推荐设置：

```text
CRT mode = single_ring
Add zero-start pre-gradient before ring = checked
Pre-gradient samples = 0   # auto
```

如果 pre-gradient 不可行或 slew 超限，可将 pre-gradient samples 增加到 24、32、48 或 64。

## v0.3.3 CRT target-fidelity mode

对于 Concentric CRT single-ring，默认不再强制 hard `G(end)=G(1)` 和 C1 boundary equality。工具箱仍然检查 zero moment closure 和 cyclic slew，包括 last-to-first boundary transition。这个默认设置更适合圆形 CRT ring 的 target tracking。

在 Periodic MRSI mode 中，`Target samples` 与 `Npp` 自动同步。若需要把外环 ringIndex=6 从 96 点改为 160 点，只需要设置 `Npp = 160` 或在 `Target samples` 输入 160，两者会保持一致。

## v0.3.4 完整 CRT multi-ring set

新增 `multi_ring_set` 模式，修正 `Npp` 在完整 CRT 中的含义：

```text
one ring = one compact period = Npp samples
```

例如 `nRings=6`、`Npp=128` 时，工具箱现在生成 6 个独立的 128 点圆环，共 768 个空间采样点，而不是把 128 点分给全部圆环和连接段。

GUI 默认使用质子参数：

```text
Nucleus = 1H
gamma/2pi = 42.5774789 MHz/T
Npp = 128
Gmax = 20 mT/m
Smax = 180 T/m/s
CRT mode = multi_ring_set
```

批量 API：

```matlab
p.mode = 'multi_ring_set';
crtSet = make_concentric_crt_set(p);
result = optimize_concentric_crt_set(p, sys, acq, opt, setOpts);
```

结果通过 `result.rings(1:nRings)` 保存，每个 ring 都有独立的 target、
actual trajectory、gradient、cyclic slew、真实 pre-gradient、真实
return-to-origin post-gradient、periodic closure 和 full-FID 展开结果。
旧 `multi_ring_period` 保留为共享总 `Npp` 的 stress test，不代表正常
完整 CRT 采集。

## v0.3.8 连续重积分的完整模块轨迹

完整模块轨迹现在严格由完整梯度连续重积分：

```matlab
k = integrate_gradient(sequence.G,result.opts,kInitial);
```

不再把 `pre.ktraj_actual`、单周期 `ktraj_actual` 和
`post.ktraj_actual` 分段拼接。GUI、完整模块 CSV、逐环 return summary
均读取 `sequence.ktraj_actual`；full-FID 则从 `G_with_module` 独立连续
重积分生成 `ktraj_with_module`。`readoutClosureIndex` 明确保留了
ring→post 边界的周期闭合点。

## v0.3.7 CRT 真实完整模块轨迹

GUI 的 `All CRT rings` 子图不再使用概念性的径向 guide。每个 ring
显示一条独立、真实计算并保存的完整模块轨迹：

```text
k=0 → pre-gradient → ADC ring → post-gradient → k=0
```

- target ring：彩色虚线；
- actual ring：彩色实线；
- real pre-gradient：与 ring 同色的点线；
- real post-gradient：与 ring 同色的点划线；
- `k=0`：绿色起点/终点标记；

每个 `result.rings(i)` 保存：

```matlab
result.rings(i).pre
result.rings(i).post
result.rings(i).sequence
```

`post` 同时约束起始梯度、末端零梯度、返回零点所需的梯度矩以及
逐轴 gradient/slew。`sequence` 保存完整波形、时间、ADC mask、分段
编码及真实完整模块 k-space。六个 ring 仍是六次独立采集，不会连接
成一次连续的 R1→R2→…→R6 采集。

## v0.3.5 Pulseq 导出与 round-trip

v0.3.5 使用 Pulseq 的真实时间模型完成转换和验证：

- 工具箱的 T/m 梯度按当前核种的 `gammaBar` 转换为 Pulseq 的 Hz/m；
- 将区间梯度矩模型转换为 Pulseq 的梯度栅格中心、线性插值模型；
- ADC 按 dwell 中心时刻比较，不再按数组下标假定零偏移；
- 每个 ring 分别导出 compact 和 full-FID 文件；
- full-FID 使用 512 个独立的 128 点 gradient-ADC block；
- 文件写出后重新读入，自动检查波形、k-space、闭合、时序和硬件限制；
- 默认写出 Pulseq 1.4.1 兼容格式。

```matlab
seqOpts.compatibility = '1.4.1';
seqOpts.fullRepeats = 512;
[compactFiles, manifest] = export_crt_ring_set_pulseq( ...
    result, 'pulseq_export', 'CRT_1H', seqOpts);
validation = validate_crt_ring_set_pulseq(result, manifest);
assert(validation.overallPass);
```

详细步骤见 `docs/PULSEQ_ROUNDTRIP_CN.md`。

随包提供的 Pulseq MATLAB fallback 保持其原始许可证，见
`third_party/pulseq/LICENSE` 和 `third_party/pulseq/AUTHORS`。
