#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../01_qemu_env_build"
KERNEL_DIR="$BUILD_DIR/linux-6.1"
ROOTFS_INSTALL="$BUILD_DIR/busybox-1.36.1/_install"
DTC="$KERNEL_DIR/scripts/dtc/dtc"

# DTB 路径兼容不同内核版本目录结构
DTB="$KERNEL_DIR/arch/arm/boot/dts/imx6ul-14x14-evk.dtb"
[ ! -f "$DTB" ] && DTB="$KERNEL_DIR/arch/arm/boot/dts/nxp/imx/imx6ul-14x14-evk.dtb"

# ===== 0. 确保内核树支持外部模块编译 =====
if [ ! -f "$KERNEL_DIR/scripts/module.lds" ]; then
    echo "=== [0] 内核树缺少 module.lds，执行 modules_prepare ==="
    make -C "$KERNEL_DIR" ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules_prepare
fi
if [ ! -f "$KERNEL_DIR/Module.symvers" ]; then
    echo "=== [0] 内核树缺少 Module.symvers，编译内核模块（首次较慢）==="
    make -C "$KERNEL_DIR" ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) modules
fi

# ===== 1. 编译内核模块 =====
echo "=== [1/4] 编译内核模块 ==="
make -C "$SCRIPT_DIR"
file "$SCRIPT_DIR/hello_pdrv.ko"

# ===== 2. 修改设备树（幂等） =====
echo "=== [2/4] 修改设备树 ==="
TMP_DTS=$(mktemp /tmp/imx6ul-XXXXXX.dts)
"$DTC" -I dtb -O dts -o "$TMP_DTS" "$DTB" 2>/dev/null

if grep -q "myvendor,hello-device" "$TMP_DTS"; then
    echo "hello_device 节点已存在，跳过"
else
    LINE=$(grep -n '^};' "$TMP_DTS" | tail -1 | cut -d: -f1)
    sed -i "${LINE}i\\
\\thello_device {\\
\\t\\tcompatible = \"myvendor,hello-device\";\\
\\t\\tstatus = \"okay\";\\
\\t};" "$TMP_DTS"
    "$DTC" -I dts -O dtb -o "$DTB" "$TMP_DTS" 2>/dev/null
    echo "hello_device 节点已添加到 DTB"
fi
rm -f "$TMP_DTS"

# ===== 3. 复制模块到 rootfs =====
echo "=== [3/4] 复制模块到 rootfs ==="
mkdir -p "$ROOTFS_INSTALL/lib/modules"
cp "$SCRIPT_DIR/hello_pdrv.ko" "$ROOTFS_INSTALL/lib/modules/"

# ===== 4. 重新打包 rootfs =====
echo "=== [4/4] 打包 rootfs ==="
cd "$ROOTFS_INSTALL"
find . | cpio -H newc -o 2>/dev/null | gzip > ../rootfs.cpio.gz
echo "=== 构建完成！执行 bash run_qemu.sh 启动 QEMU ==="
