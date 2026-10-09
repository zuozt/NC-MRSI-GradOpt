# Theory: Periodic Gradient Optimization for MRSI

## 1. MRSI 的周期性读出结构

周期性非笛卡尔 MRSI 的核心结构是：同一个空间轨迹周期在 FID 中重复播放。

```text
一个空间周期:     Npp 个点
谱维重复次数:     Nspec 次
总 ADC 点数:      NADC = Npp × Nspec
```

每个周期的长度为：

\[
T_{period} = N_{pp}\Delta t
\]

因此谱宽不是 `1/ADC dwell`，而是：

\[
SBW = \frac{1}{T_{period}} = \frac{1}{N_{pp}\Delta t}
\]

谱分辨率为：

\[
\Delta f = \frac{SBW}{N_{spec}}
\]

这一区别非常重要。若把 `Npp × Nspec` 当成一条长的非周期 k-space 轨迹优化，会破坏 MRSI 中空间维和谱维的对应关系。

---

## 2. Compact period target

对于 3D PETALUTE-like rosette，一个周期内的 target k-space 可以写成：

\[
K_{xy}(t)=K_{max}\cos(\phi)\sin(\omega_1 t)e^{i(\omega_2 t+\beta)}
\]

\[
K_z(t)=K_{max}\sin(\phi)\sin(\omega_1 t)
\]

令：

\[
u_n=\frac{n}{N_{pp}},\quad n=0,1,\ldots,N_{pp}-1
\]

且：

\[
\omega_1=\omega_2=\pi/T_{period}
\]

则离散 target 为：

\[
k_x[n]=K_{max}\cos(\phi)\sin(\pi u_n)\cos(\pi u_n+\beta)
\]

\[
k_y[n]=K_{max}\cos(\phi)\sin(\pi u_n)\sin(\pi u_n+\beta)
\]

\[
k_z[n]=K_{max}\sin(\phi)\sin(\pi u_n)
\]

不包含 `u=1`，因为 `u=1` 是下一个周期的第一个点。

---

## 3. 梯度到 k-space 的离散积分

设一个周期内的梯度为：

\[
\mathbf{G}[n] = [G_x[n],G_y[n],G_z[n]]
\]

实际 k-space 为：

\[
\mathbf{k}_{act}[n]=\mathbf{k}_0+\bar{\gamma}\Delta t\sum_{j=0}^{n-1}\mathbf{G}[j]
\]

其中 \(\bar{\gamma}\) 的单位为 cycles/s/T。

---

## 4. 周期性约束

周期性 MRSI 不只要求 k-space 闭合，还要求梯度波形能连续重复播放。

### 4.1 k-space closure

\[
\sum_{n=0}^{N_{pp}-1}\mathbf{G}[n]=0
\]

这保证下一个周期从同一个 k-space 起点开始。

### 4.2 gradient continuity

\[
\mathbf{G}[N_{pp}-1]=\mathbf{G}[0]
\]

这避免周期边界处梯度强度跳变。

### 4.3 slew continuity

\[
\mathbf{G}[1]-\mathbf{G}[0]
=
\mathbf{G}[N_{pp}-1]-\mathbf{G}[N_{pp}-2]
\]

这避免周期边界处出现 slew-rate 尖峰。

### 4.4 cyclic slew

周期性 slew 应包括边界项：

\[
\mathbf{S}[n]=\frac{\mathbf{G}[n+1]-\mathbf{G}[n]}{\Delta t}
\]

\[
\mathbf{S}[N_{pp}-1]=\frac{\mathbf{G}[0]-\mathbf{G}[N_{pp}-1]}{\Delta t}
\]

---

## 5. 固定时长优化

优化变量为一个周期内的梯度：

\[
\mathbf{G}_{period}\in\mathbb{R}^{N_{pp}\times 3}
\]

优化目标：

\[
\min_{\mathbf{G}}\sum_n\|\mathbf{k}_{act}[n]-\mathbf{k}_{tar}[n]\|_2^2
+\lambda_S R_S(\mathbf{G})+\lambda_{smooth}R_{smooth}(\mathbf{G})
\]

约束：

```text
|G| <= Gmax
|S| <= Smax
sum(G) = 0
G(end) = G(1), optional but recommended for repeated MRSI
cyclic slew continuity, optional but recommended
```

关键点是：`Npp` 不作为优化变量，因为它决定谱宽。改变 `Npp` 会改变 MRSI 的谱采样属性。

---

## 6. 为什么 actual 可能不完全等于 target

解析 PETALUTE target 只定义了理想 k-space 采样位置，并不自动保证：

```text
G(end) = G(1)
slew(end) = slew(start)
```

因此在强制周期边界连续时，优化后的 actual k 可能略偏离解析 target。这是硬件连续性和理想解析轨迹之间的折中。

如果偏差过大，可以考虑：

```text
增大 Npp
降低 Kmax
降低 radial/angular oscillation
适当放松 forceSlewPeriodicEqual
提高允许的 Gmax/Smax，仅在真实硬件允许时
```
