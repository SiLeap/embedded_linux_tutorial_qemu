#!/bin/bash
set -e

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL_VER="6.1"
KERNEL_DIR="$WORKDIR/linux-${KERNEL_VER}"

echo "=== 下载 Linux 内核 v${KERNEL_VER} ==="

cd "$WORKDIR"
if [ ! -f "linux-${KERNEL_VER}.tar.xz" ]; then
    wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VER}.tar.xz
fi

if [ ! -d "$KERNEL_DIR" ]; then
    echo "=== 解压内核源码 ==="
    tar -xf linux-${KERNEL_VER}.tar.xz
fi

cd "$KERNEL_DIR"

echo "=== 配置内核（imx_v6_v7_defconfig）==="
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- imx_v6_v7_defconfig

echo "=== 禁用 QEMU 不支持的硬件驱动（避免启动超时）==="
scripts/config --disable CONFIG_DRM_MXSFB
scripts/config --disable CONFIG_FRAMEBUFFER_CONSOLE
scripts/config --disable CONFIG_MXS_DMA
scripts/config --disable CONFIG_MTD_NAND_GPMI_NAND
scripts/config --disable CONFIG_RTC_DRV_SNVS
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- olddefconfig

echo "=== 编译内核 zImage + DTB + 模块 ==="
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs modules

echo "=== 验证编译产物 ==="
ls -lh arch/arm/boot/zImage
ls -lh arch/arm/boot/dts/nxp/imx/imx6ul-14x14-evk.dtb 2>/dev/null || \
ls -lh arch/arm/boot/dts/imx6ul-14x14-evk.dtb 2>/dev/null || \
echo "警告: 未找到 imx6ul-14x14-evk.dtb，请检查 dts 目录结构"

echo "=== 内核编译完成 ==="
