# Comparison with Other Approaches

本文档总结本工具包与常见轨迹/梯度设计方法的差别。

---

## 1. 与解析 rosette / PETALUTE 公式的差别

| 项目 | 解析公式 | 本工具包 |
|---|---|---|
| 输出 | 理想 k-space 点 | 可播放的梯度波形和实际 k-space |
| 硬件限制 | 通常不直接处理 | 显式检查 Gmax/Smax |
| 周期边界 | 公式本身不保证 G/slew 连续 | 显式加入 cyclic G/slew 约束 |
| MRSI 谱维 | 给出采样结构 | 明确分离 Npp 与 Nspec |
| 适用阶段 | 轨迹设计 | 序列工程实现前的梯度验证 |

解析公式适合定义 target trajectory，但不能替代硬件可播放的梯度优化。

---

## 2. 与普通 finite-difference 梯度计算的差别

普通方法：

```matlab
G = diff(k) / (gamma * dt)
```

问题：

```text
1. 只看相邻点，不处理周期边界；
2. 最后一个点到下一个周期第一个点可能产生跳变；
3. 不保证 Gmax/Smax；
4. 不保证 G(end)=G(1) 或 cyclic slew continuity。
```

本工具包使用 cyclic finite difference 和周期约束：

```matlab
G(end) = (k(1) - k(end)) / (gamma * dt)
S(end) = (G(1) - G(end)) / dt
```

并在优化中显式加入边界连续性。

---

## 3. 与常规 non-Cartesian MRI 梯度优化的差别

常规 MRI 轨迹优化通常把完整 readout 视为一条连续空间轨迹：

```text
k[1], k[2], ..., k[NADC]
```

但周期性 MRSI 的结构是：

```text
k_period[1:Npp] repeated Nspec times
```

本工具包的核心区别：

```text
只优化 compact period，不优化 Npp×Nspec 的长 readout。
```

这避免了把谱维重复误认为新的空间编码轨迹。

---

## 4. 与时间最优梯度设计的差别

时间最优方法通常会在硬件限制下尽量缩短读出时间，或者在约束不满足时自动延长时间。

对于 MRSI，这可能带来问题：

```text
Tperiod 改变 → spectral bandwidth 改变
Npp 改变     → 谱维采样结构改变
```

本工具包采用固定 `Npp` 和固定 dwell：

```text
Tperiod = Npp × dwell 固定
SBW = 1 / Tperiod 固定
```

因此更适合 MRSI 序列参数设计。

---

## 5. 与 Pulseq / PyPulseq 的差别

Pulseq/PyPulseq 是序列描述和导出工具，不是轨迹优化器。

| 功能 | Pulseq/PyPulseq | 本工具包 |
|---|---|---|
| 写 `.seq` | 支持 | 通过 export helper 支持 |
| 任意梯度播放 | 支持 | 生成任意梯度波形 |
| k-space 目标优化 | 不作为核心功能 | 核心功能 |
| 周期 MRSI Npp/Nspec 建模 | 需用户自行实现 | 内置 |
| 周期边界 G/slew 检查 | 需用户自行实现 | 内置 |

推荐流程是：

```text
本工具包优化并验证 G/k/slew → Pulseq 导出 → scanner/vendor safety check
```

---

## 6. 与变量密度投影/传统投影方法的差别

传统变量密度或投影方法更关注采样密度和重建质量，经常以目标采样分布为核心。

本工具包更关注：

```text
固定周期长度
周期性 MRSI 谱维采样
硬件可播放梯度
周期边界连续性
```

两者可以互补：变量密度方法可用于设计目标 k-space 分布，本工具包用于把目标分布转换为周期连续且硬件受限的梯度波形。

---

## 7. 主要创新点总结

1. **把周期性 MRSI 优化建模为 compact-period problem**，而不是长 readout problem。
2. **显式引入 Npp 和 Nspec 的分离**，保留谱宽和谱分辨率的物理含义。
3. **加入 cyclic gradient 和 cyclic slew 约束**，检查周期边界处的真实硬件连续性。
4. **固定 Npp / 固定时长优化**，避免通过延长轨迹破坏 MRSI 谱采样。
5. **同时提供 GUI 和 API**，便于从方法开发过渡到序列实现。
