#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../01_qemu_env_build"
KERNEL="$BUILD_DIR/linux-6.1/arch/arm/boot/zImage"
DTB="$SCRIPT_DIR/imx6ul-14x14-evk-audio.dtb"
ROOTFS="$BUILD_DIR/busybox-1.36.1/rootfs.cpio.gz"

for f in "$KERNEL" "$DTB" "$ROOTFS"; do
    if [ ! -f "$f" ]; then
        echo "Error: File not found: $f"
        exit 1
    fi
done

echo "=== Starting QEMU mcimx6ul-evk (Cortex-A7) ==="
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
