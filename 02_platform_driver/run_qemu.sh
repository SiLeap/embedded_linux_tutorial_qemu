#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../01_qemu_env_build"

KERNEL="$BUILD_DIR/linux-6.1/arch/arm/boot/zImage"
DTB="$BUILD_DIR/linux-6.1/arch/arm/boot/dts/imx6ul-14x14-evk.dtb"
[ ! -f "$DTB" ] && DTB="$BUILD_DIR/linux-6.1/arch/arm/boot/dts/nxp/imx/imx6ul-14x14-evk.dtb"
ROOTFS="$BUILD_DIR/busybox-1.36.1/rootfs.cpio.gz"

for f in "$KERNEL" "$DTB" "$ROOTFS"; do
    [ ! -f "$f" ] && echo "错误: 找不到 $f" && exit 1
done

echo "=== 启动 QEMU mcimx6ul-evk (Cortex-A7) ==="
echo "提示: 进入后执行 insmod /lib/modules/hello_pdrv.ko"
echo "退出: Ctrl+A 然后 X"
echo ""

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
