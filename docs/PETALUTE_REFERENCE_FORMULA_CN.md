# PETALUTE 3D rosette 参考公式

本工具箱周期性 rosette target 的默认形式采用 PETALUTE 31P-MRSI 文献中的公式：

\[
K_{xy}(t)=K_x(t)+iK_y(t)=K_{max}\cos(\phi)\sin(\omega_1 t)e^{i(\omega_2 t + \beta)}
\]

\[
K_z(t)=K_{max}\sin(\phi)\sin(\omega_1 t)
\]

其中：

\[
\omega_1=\omega_2=\pi \cdot SBW
\]

\[
SBW = \frac{1}{N_{pp}\Delta t}
\]

因此在一个周期内：

\[
T_{period}=N_{pp}\Delta t
\]

令：

\[
u=t/T_{period}
\]

则：

\[
\omega_1 t=\omega_2 t=\pi u
\]

程序实际实现为：

```matlab
u = (0:Npp-1).' / Npp;
radial = sin(pi*u);
theta  = pi*u + beta;

kx = Kmax*cos(phi).*radial.*cos(theta);
ky = Kmax*cos(phi).*radial.*sin(theta);
kz = Kmax*sin(phi).*radial;
```

这里没有包含 `u=1` 的重复终点，因为下一周期的第一个采样点就是 `u=0`。

## 与旧版本区别

旧版临时 target：

```matlab
radial = sin(pi*u).^2;
theta  = 2*pi*u + beta;
```

该形式不是 PETALUTE 文献公式，只是工程上平滑的 center-out-center 包络。v0.2.6 已将默认 rosette target 改回文献公式。
