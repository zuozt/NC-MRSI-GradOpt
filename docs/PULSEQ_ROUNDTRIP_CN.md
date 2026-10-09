# CRT Pulseq 导出与 round-trip 验证

## 1. 适用对象

本流程适用于 `multi_ring_set` 结果。每个 CRT ring 是一个独立的
compact period，每环具有固定 `Npp` 个 ADC 样本。对于当前质子示例：

- `nRings = 6`
- `Npp = 128`
- `dwell = 5 µs`
- `Nspec = 512`
- 每环 compact period = 640 µs
- 每环 full-FID ADC = 65536 samples

## 2. 为什么需要 ADC-centred 转换

NC-MRSI-GradOpt 原始离散模型把 `G(i)` 解释为从 `k(i)` 推进到
`k(i+1)` 的区间梯度矩。Pulseq arbitrary gradient 则把波形值放在
gradient raster 中心，并在相邻点间线性插值；ADC 样本位于 dwell
中心。因此不能把 T/m 数组直接交给 `mr.makeArbitraryGrad`。

v0.3.5 求解：

```text
k(i+1)-k(i) = gammaBar × dt × [Gpulseq(i)+Gpulseq(i+1)]/2
```

并重新设计 Pulseq 专用 pre-gradient，使第一个 ADC 中心准确落在
目标 ring 起点；post-gradient 则同时回到 `k=0` 和 `G=0`。

## 3. 执行步骤

```matlab
startup_nc_mrsi_gradopt;
S = load('gradopt_periodic_mrsi_CRT_multi_ring_result.mat');
resultSet = S.result;

seqOpts = struct();
seqOpts.compatibility = '1.4.1';
seqOpts.fullRepeats = 512;
seqOpts.exportCompact = true;
seqOpts.exportFull = true;

[compactFiles, manifest] = export_crt_ring_set_pulseq( ...
    resultSet, 'pulseq_export', 'CRT_1H', seqOpts);

validation = validate_crt_ring_set_pulseq(resultSet, manifest);
disp(validation.overallPass);
```

也可以直接执行：

```matlab
output = run_crt_pulseq_roundtrip( ...
    'gradopt_periodic_mrsi_CRT_multi_ring_result.mat', ...
    'pulseq_export');
assert(output.validation.overallPass);
```

## 4. 输出文件

```text
pulseq_export/
├── compact/
│   ├── CRT_1H_ring01_compact.seq
│   └── ... ring06 ...
├── fullFID/
│   ├── CRT_1H_ring01_full512.seq
│   └── ... ring06 ...
├── crt_pulseq_roundtrip_summary.csv
├── crt_pulseq_roundtrip_details.mat
└── crt_pulseq_roundtrip_report.txt
```

## 5. Pass 条件

默认阈值：

```matlab
tolG_Tm       = 1e-9;
tolK_cpm      = 1e-6;
tolClosure_cpm = 1e-6;
tolDuration_s = 1e-9;
tolPeriod_s   = 1e-10;
```

三级判定：

```text
modulePass  = timing + waveform + fixed timing + duration
readoutPass = ADC count + ADC-centred k-space + closure
returnPass  = full module ends at k=0
overallPass = modulePass + readoutPass + returnPass + hardware
```

## 6. 格式兼容性

默认使用 `seq.write_v141` 写出 1.4.1 文件，适合需要旧解释器兼容的
扫描仪。若扫描仪和解释器明确支持当前 Pulseq 格式：

```matlab
seqOpts.compatibility = 'current';
```

Pulseq 专用 pre-gradient 的硬件约束求解需要 MATLAB Optimization
Toolbox 的 `quadprog`。若缺少该函数，工具箱只生成用于诊断的等式
fallback，并拒绝写出不可行的 `.seq`。

正式上机前仍需使用扫描仪厂商的 sequence safety、PNS、梯度和 RF
检查流程；本工具包的 round-trip 通过不等于自动获得上机许可。
