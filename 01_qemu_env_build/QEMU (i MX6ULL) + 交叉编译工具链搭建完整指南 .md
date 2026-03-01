# QEMU (i.MX6UL) + 交叉编译工具链搭建完整指南

> **说明**：本指南使用 QEMU 的 `mcimx6ul-evk` 机型（i.MX6UL/Cortex-A7），与 i.MX6ULL 同为 Cortex-A7 架构，适合驱动开发和内核调试。

## 1. 安装交叉编译工具链

针对 i.MX6UL 系列（ARM Cortex-A7，32位），推荐使用 **arm-linux-gnueabihf** 工具链。

### 方案A：直接 apt 安装（最快）

```bash
sudo apt update
sudo apt install gcc-arm-linux-gnueabihf \\
                 g++-arm-linux-gnueabihf \\
                 binutils-arm-linux-gnueabihf
```

验证：

```bash
arm-linux-gnueabihf-gcc --version
```

### 方案B：使用 Linaro 预编译工具链（推荐，版本可控）

```bash
# 下载 Linaro 7.5 工具链（与 i.MX6ULL 常用内核版本匹配）
wget https://releases.linaro.org/components/toolchain/binaries/7.5-2019.12/arm-linux-gnueabihf/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz

tar -xf gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz -C ~/toolchain/

# 添加到 PATH
echo 'export PATH=$PATH:~/toolchain/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf/bin' >> ~/.bashrc
source ~/.bashrc
```

---

## 2. 安装 QEMU（支持 ARM virt/sabrelite）

```bash
sudo apt install qemu-system-arm qemu-utils
```

验证：

```bash
qemu-system-arm --version
# 查看支持的 i.MX6ULL 相关机型
qemu-system-arm -machine help | grep -i imx
```

> **注意**：QEMU 对 [i.MX](http://i.mx/)6ULL 的支持机型为 `sabrelite`（imx6ul-evk），官方支持在 QEMU 5.0+ 之后逐步完善。
> 

---

## 3. 准备内核和 DTB

### 下载并交叉编译内核

```bash
# 直接下载 v6.1 源码包（比 git clone 快很多）
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.tar.xz
tar -xf linux-6.1.tar.xz
cd linux-6.1

# 使用 i.MX6 默认配置（支持 sabrelite 机型）
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- imx_v6_v7_defconfig

# 禁用 QEMU 不支持的硬件驱动（避免启动超时，详见第6节分析）
scripts/config --disable CONFIG_DRM_MXSFB           # LCDIF 显示驱动（主因，节省 ~60s）
scripts/config --disable CONFIG_FRAMEBUFFER_CONSOLE  # fbcon 控制台接管
scripts/config --disable CONFIG_MXS_DMA              # APBH DMA 控制器
scripts/config --disable CONFIG_MTD_NAND_GPMI_NAND   # GPMI NAND（依赖 MXS_DMA）
scripts/config --disable CONFIG_RTC_DRV_SNVS         # SNVS RTC
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- olddefconfig

# 如需进一步调整，可用 menuconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig
# 确保启用: Device Drivers → Character devices → Serial drivers → IMX serial port support

# 编译内核镜像 + DTB
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs
```

编译产物位于：

- 内核：`arch/arm/boot/zImage`
- DTB（mcimx6ul-evk 机型）：`arch/arm/boot/dts/imx6ul-14x14-evk.dtb`

---

## 4. 制作最小 rootfs（用 BusyBox）

```bash
# 下载编译 BusyBox
wget https://busybox.net/downloads/busybox-1.36.1.tar.bz2
tar -xf busybox-1.36.1.tar.bz2 && cd busybox-1.36.1

make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- defconfig
# 配置为静态编译（避免 .so 依赖问题）
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig
# → Settings → Build static binary (no shared libs) → 勾选

make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc)
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- install
# 安装到 ./_install/
```

打包为 initramfs：

```bash
cd _install
mkdir -p proc sys dev etc/init.d

cat > etc/init.d/rcS << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mdev -s
EOF
chmod +x etc/init.d/rcS

# 打包
find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz
```

---

## 5. 启动 QEMU 模拟 i.MX6UL

```bash
qemu-system-arm \\
  -machine mcimx6ul-evk \\
  -cpu cortex-a7 \\
  -m 512M \\
  -kernel arch/arm/boot/zImage \\
  -dtb arch/arm/boot/dts/imx6ul-14x14-evk.dtb \\
  -initrd rootfs.cpio.gz \\
  -append "console=ttymxc0,115200 root=/dev/ram rdinit=/sbin/init video=off" \\
  -nographic \\
  -serial mon:stdio
```

> **机型说明**：`mcimx6ul-evk` 对应 Freescale i.MX6UL EVK（Cortex-A7），与 i.MX6ULL 同架构，是最接近的 QEMU 机型。

> **`video=off` 说明**：必须添加此参数。QEMU 未完整模拟 i.MX6UL 的 LCDIF 显示控制器，内核 mxsfb DRM 驱动会因等待 vblank 中断反复超时（每次 10 秒，共约 60 秒），且 fbcon 会将控制台从串口切换到帧缓冲（`Console: switching to colour frame buffer device`），导致串口无输出。`video=off` 禁用帧缓冲设备，避免此问题。
>

> **退出 QEMU**：`-serial mon:stdio` 模式下，按 `Ctrl+A` 然后按 `X` 即可终止 QEMU。按 `Ctrl+A` 再按 `C` 可进入 QEMU monitor（输入 `quit` 退出）。
>

---

## 6. 启动延迟分析与优化

`imx_v6_v7_defconfig` 默认启用了大量 i.MX6 外设驱动，但 QEMU `mcimx6ul-evk` 未完整模拟这些硬件，导致驱动探测超时。未优化时启动到 init 需要 **~67s**，优化后仅需 **~5s**。

### 6.1 延迟根因：mxsfb DRM 驱动 vblank 超时

QEMU 不模拟 LCDIF vblank 中断，mxsfb DRM 驱动每次 atomic commit 等待 10s 超时，启动过程触发 6 次：

```
[  2.3s] mxsfb_probe → fbcon 接管 → vblank wait timed out WARNING
[ 12.7s] flip_done timed out (10s)
[ 22.9s] flip_done timed out (10s)
[ 33.2s] flip_done timed out (10s)
[ 43.4s] flip_done timed out (10s)
[ 53.7s] flip_done timed out (10s)
[ 63.9s] flip_done timed out (10s)
[ 64.1s] 启动继续...
```

调用链：`mxsfb_probe → drm_fbdev_generic_setup → register_framebuffer → fbcon_fb_registered → do_fbcon_takeover → drm_atomic_helper_wait_for_vblanks → 10s timeout × 6 ≈ 60s`

> **注意**：`video=off` 内核参数只影响 video mode 解析，**不阻止** DRM 驱动通过设备树匹配探测。必须在内核配置中禁用 `CONFIG_DRM_MXSFB`。

### 6.2 其他 QEMU 不支持的硬件超时

| 驱动 | 日志 | 配置项 | 耗时 |
|------|------|--------|------|
| MXS DMA (APBH) | `stmp_reset_block: module reset timeout` | `CONFIG_MXS_DMA` | ~1s |
| SNVS RTC | `snvs_rtc: probe failed -110` | `CONFIG_RTC_DRV_SNVS` | <0.1s |
| SPI NOR | `spi-nor: probe failed -110` | 设备树自动探测 | ~1s |
| mag3110 / wm8960 | I2C 设备探测失败 | 设备树自动探测 | <0.2s |

### 6.3 优化方案（已集成到第3节内核配置步骤）

```bash
scripts/config --disable CONFIG_DRM_MXSFB           # LCDIF 显示驱动（节省 ~60s）
scripts/config --disable CONFIG_FRAMEBUFFER_CONSOLE  # 阻止 fbcon 接管串口
scripts/config --disable CONFIG_MXS_DMA              # APBH DMA 控制器
scripts/config --disable CONFIG_MTD_NAND_GPMI_NAND   # GPMI NAND（依赖 MXS_DMA）
scripts/config --disable CONFIG_RTC_DRV_SNVS         # SNVS RTC
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- olddefconfig
```

优化效果：启动到 init **67s → 5s**。

---

## 7. 一键验证脚本

```bash
#!/bin/bash
# run_imx6ul_qemu.sh
KERNEL=linux-6.1/arch/arm/boot/zImage
DTB=linux-6.1/arch/arm/boot/dts/imx6ul-14x14-evk.dtb
ROOTFS=busybox-1.36.1/rootfs.cpio.gz

qemu-system-arm \\
  -machine mcimx6ul-evk \\
  -cpu cortex-a7 \\
  -m 512M \\
  -kernel $KERNEL \\
  -dtb $DTB \\
  -initrd $ROOTFS \\
  -append "console=ttymxc0,115200 rdinit=/sbin/init video=off" \\
  -nographic \\
  -serial mon:stdio
```

---

## 8. 完整工具链验证

目标：编写一个测试程序，交叉编译后打入 rootfs，在 QEMU 中执行并确认输出，形成 **编写 → 编译 → 打包 → 运行** 的完整闭环。

### 8.1 编写测试程序

```c
// hello.c
#include <stdio.h>
#include <sys/utsname.h>

int main(void)
{
    struct utsname info;
    printf("Hello from cross-compiled binary!\n");
    if (uname(&info) == 0) {
        printf("Kernel : %s %s\n", info.sysname, info.release);
        printf("Machine: %s\n", info.machine);
    }
    return 0;
}
```

### 8.2 交叉编译并检查产物

```bash
# 静态编译（rootfs 无共享库时必须 -static）
arm-linux-gnueabihf-gcc -static -o hello hello.c

# 验证目标架构
file hello
# 预期输出包含: ELF 32-bit LSB executable, ARM, ..., statically linked

# 查看依赖（应显示 "not a dynamic executable"）
arm-linux-gnueabihf-readelf -d hello || echo "静态链接，无动态依赖 ✓"
```

### 8.3 将程序打入 rootfs 并重新打包

```bash
cd busybox-1.36.1/_install

# 复制编译产物到 rootfs
cp ../../hello .

# 重新打包 initramfs
find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz
```

### 8.4 启动 QEMU 并运行

```bash
# 使用第7步的脚本启动 QEMU
bash run_imx6ul_qemu.sh

# 进入 QEMU shell 后执行
/hello
```

### 8.5 预期输出与验证清单

- [ ]  `file hello` 显示 **ELF 32-bit LSB executable, ARM**
- [ ]  QEMU 启动后能进入 BusyBox shell（`/ #` 提示符）
- [ ]  执行 `/hello` 输出 `Hello from cross-compiled binary!` 及内核信息
- [ ]  `uname -m` 在 QEMU 内返回 `armv7l`

### 8.6 常见问题排查

| **现象** | **可能原因** | **解决方案** |
| --- | --- | --- |
| `/hello: not found` | 未将 hello 打入 rootfs 或路径错误 | 确认 hello 在 `_install/` 根目录，重新 cpio 打包 |
| `Exec format error` | 使用了宿主机 gcc 而非交叉编译器 | `file hello` 确认为 ARM ELF，重新用 `arm-linux-gnueabihf-gcc` 编译 |
| `No such file or directory`（动态链接） | 编译时未加 `-static`，rootfs 缺少 ld-linux | 加 `-static` 重新编译，或将工具链 sysroot 下的 `.so` 拷入 rootfs |
| `Permission denied` | hello 缺少可执行权限 | 打包前执行 `chmod +x hello` |
| 启动极慢（60s+），串口输出中断，日志出现 `vblank wait timed out`、`flip_done timed out`、`Console: switching to colour frame buffer device` | QEMU 未完整模拟 LCDIF 显示控制器，mxsfb DRM 驱动 vblank 超时，fbcon 抢占串口控制台 | 内核启动参数加 `video=off` |

---

## 总结路径

```
安装工具链 → 编译内核+DTB → 制作 BusyBox rootfs → QEMU mcimx6ul-evk 启动
```

遇到具体报错（内核 panic、DTB 不匹配、串口无输出等），直接把错误信息发给我，我帮你定位。