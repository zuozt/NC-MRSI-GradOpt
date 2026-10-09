# v0.3.8：CRT 完整模块连续重积分修正

## 修正的问题

v0.3.7 已求解并保存真实 post-gradient，但
`sequence.ktraj_actual` 和 `full.ktraj_with_module` 仍由 pre、readout、
post 三段局部轨迹拼接。由于三段的局部初始位置和采样时刻约定不同，
拼接结果不能严格代表完整梯度在统一时间轴上的实际轨迹。

## v0.3.8 的唯一轨迹来源

单周期完整模块：

```matlab
sequence.G = [pre.G; readout.G; post.G];
sequence.ktraj_actual = integrate_gradient( ...
    sequence.G,result.opts,kInitial);
```

full-FID 完整模块：

```matlab
full.G_with_module = [pre.G; repeatedReadout.G; post.G];
full.ktraj_with_module = integrate_gradient( ...
    full.G_with_module,result.opts,kInitial);
```

因此 GUI、CSV 和 return summary 不再依赖任何分段保存的 k-space 缓存。

## 新增诊断字段

```matlab
sequence.integrationConvention
sequence.ktraj_pre
sequence.ktraj_adc
sequence.ktraj_post
sequence.readoutClosureIndex
sequence.readoutClosurePoint
sequence.returnError
sequence.returnErrorNorm
sequence.terminalReturnError
sequence.terminalReturnErrorNorm
sequence.postSolverReturnErrorNorm

full.integrationConvention
full.readoutClosureIndex
full.readoutClosurePoint
full.returnErrorNorm
full.terminalReturnErrorNorm
```

`summary.worstReturnError` 现在表示完整 pre–readout–post 连续重积分的
最坏回零误差；原 post-gradient 局部求解残差保留在
`summary.worstPostSolverReturnError`。full-FID 的最坏连续回零误差保存于
`summary.worstFullFidReturnError`。

## GUI

`All CRT rings` 子图中的 actual ring、显式周期闭合点、pre-gradient 和
post-gradient 均只从 `sequence.ktraj_actual` 截取。六个 ring 仍是六次
独立采集，不会被连接为一次连续采集。

## 回归测试

`tests/test_crt_complete_module.m` 新增：

- `sequence.ktraj_actual` 与 `integrate_gradient(sequence.G,...)` 逐点一致；
- 人为破坏分段局部 k-space 缓存后，完整模块轨迹保持不变；
- ring→post 边界存在显式周期闭合点；
- full-FID `ktraj_with_module` 与 `G_with_module` 连续重积分逐点一致；
- 单周期与 full-FID 完整模块均回到 `k=0`。
