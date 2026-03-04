#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../01_qemu_env_build"
KERNEL_DIR="$BUILD_DIR/linux-6.1"
ROOTFS_DIR="$BUILD_DIR/busybox-1.36.1/_install"
BASE_DTB="$KERNEL_DIR/arch/arm/boot/dts/imx6ul-14x14-evk.dtb"
[ ! -f "$BASE_DTB" ] && BASE_DTB="$KERNEL_DIR/arch/arm/boot/dts/nxp/imx/imx6ul-14x14-evk.dtb"
MERGED_DTB="$SCRIPT_DIR/imx6ul-14x14-evk-imu.dtb"

echo "=== Building fake_imu module ==="
make clean
make

[ ! -f "fake_imu.ko" ] && { echo "Error: fake_imu.ko not built"; exit 1; }

echo "=== Creating modified DTB with fake_imu device ==="
[ ! -f "$BASE_DTB" ] && { echo "Error: Base DTB not found at $BASE_DTB"; exit 1; }
dtc -I dtb -O dts "$BASE_DTB" -o base.dts

python3 << 'PYEOF'
with open('base.dts', 'r') as f:
    lines = f.readlines()

output = []
i2c_depth = 0
inserted = False

for line in lines:
    output.append(line)
    if 'i2c@21a0000' in line and '{' in line:
        i2c_depth = 1
    elif i2c_depth > 0:
        if '{' in line:
            i2c_depth += 1
        if '}' in line:
            i2c_depth -= 1
            if i2c_depth == 0 and not inserted:
                indent = '\t\t'
                output.insert(-1, f'{indent}fake_imu@68 {{\n')
                output.insert(-1, f'{indent}\tcompatible = "myvendor,fake-imu";\n')
                output.insert(-1, f'{indent}\treg = <0x68>;\n')
                output.insert(-1, f'{indent}\tstatus = "okay";\n')
                output.insert(-1, f'{indent}}};\n\n')
                inserted = True

with open('base.dts', 'w') as f:
    f.writelines(output)
PYEOF

dtc -I dts -O dtb -o "$MERGED_DTB" base.dts
rm -f base.dts

echo "=== Copying module to rootfs ==="
mkdir -p "$ROOTFS_DIR/lib/modules"
cp fake_imu.ko "$ROOTFS_DIR/lib/modules/"

echo "=== Repackaging rootfs ==="
cd "$ROOTFS_DIR"
find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz

echo "=== Build complete ==="
ls -lh "$SCRIPT_DIR/fake_imu.ko"
ls -lh "$MERGED_DTB"
ls -lh "$BUILD_DIR/busybox-1.36.1/rootfs.cpio.gz"
