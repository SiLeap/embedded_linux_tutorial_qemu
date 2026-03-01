#!/bin/bash
WORKDIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL_VER="6.1"

KERNEL="$WORKDIR/linux-${KERNEL_VER}/arch/arm/boot/zImage"
# DTB 路径兼容不同内核版本的目录结构
DTB="$WORKDIR/linux-${KERNEL_VER}/arch/arm/boot/dts/imx6ul-14x14-evk.dtb"
[ ! -f "$DTB" ] && DTB="$WORKDIR/linux-${KERNEL_VER}/arch/arm/boot/dts/nxp/imx/imx6ul-14x14-evk.dtb"
ROOTFS="$WORKDIR/busybox-1.36.1/rootfs.cpio.gz"

for f in "$KERNEL" "$DTB" "$ROOTFS"; do
    if [ ! -f "$f" ]; then
        echo "错误: 找不到 $f"
        exit 1
    fi
done

echo "=== 启动 QEMU mcimx6ul-evk (Cortex-A7) ==="
qemu-system-arm \
  -machine mcimx6ul-evk \
  -cpu cortex-a7 \
  -m 512M \
  -kernel "$KERNEL" \
  -dtb "$DTB" \
  -initrd "$ROOTFS" \
  -append "console=ttymxc0,115200 root=/dev/ram rdinit=/sbin/init video=off" \
  -nographic \
  -serial mon:stdio
