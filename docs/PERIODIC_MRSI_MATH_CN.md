# 周期性 MRSI 轨迹数学结构

对于周期性非笛卡尔 MRSI，空间编码轨迹不是一个连续不重复的长轨迹，而是一个短周期轨迹的重复。

## 1. 基本定义

令一个周期内有 `Npp` 个采样点，周期内部 ADC dwell 为 `dtADC`：

```math
T_{period} = N_{pp} \cdot dt_{ADC}
```

如果该周期重复 `Nspec` 次，则总 ADC 点数为：

```math
N_{ADC,total} = N_{pp} \cdot N_{spec}
```

谱宽由周期重复频率决定：

```math
SBW = \frac{1}{T_{period}} = \frac{1}{N_{pp} dt_{ADC}}
```

谱分辨率为：

```math
\Delta f = \frac{SBW}{N_{spec}}
```

## 2. 轨迹与梯度关系

单周期目标轨迹为：

```math
k_p[n],\quad n=0,1,\dots,N_{pp}-1
```

梯度满足：

```math
G(t) = \frac{1}{\bar{\gamma}} \frac{dk(t)}{dt}
```

离散形式：

```math
k[n] = k[0] + \bar{\gamma}\,dt\sum_{i=0}^{n}G[i]
```

其中 `gamma_bar = gamma / 2pi`，单位为 Hz/T，因此 `k` 的单位为 cycles/m。

## 3. 周期性约束

一个可重复周期应满足：

```math
G_p[0] \approx 0,\quad G_p[N_{pp}-1] \approx 0
```

并且每周期净 k 位移应接近零：

```math
\Delta k_p = \bar{\gamma} dt \sum_{n=0}^{N_{pp}-1}G_p[n] \approx 0
```

如果该条件不满足，重复 512 次后会产生 k-space drift，导致不同谱维时间点对应的空间轨迹不一致。

## 4. 工程算法

推荐算法是：

```text
1. 用户指定 Npp 和 Nspec
2. 只生成一个 compact target period: k_period[Npp]
3. 只优化一个 compact gradient period: G_period[Npp]
4. 检查 Gmax、Smax、周期闭合和净 moment
5. 完整读出通过 G_full = repmat(G_period, [Nspec, 1]) 得到
```

不要把 `Npp × Nspec` 个 ADC 点直接当成一个非周期长轨迹优化。

