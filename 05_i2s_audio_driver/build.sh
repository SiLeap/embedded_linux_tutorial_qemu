#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../01_qemu_env_build"
KERNEL_DIR="$BUILD_DIR/linux-6.1"
ROOTFS_DIR="$BUILD_DIR/busybox-1.36.1/_install"
BASE_DTB="$KERNEL_DIR/arch/arm/boot/dts/imx6ul-14x14-evk.dtb"
[ ! -f "$BASE_DTB" ] && BASE_DTB="$KERNEL_DIR/arch/arm/boot/dts/nxp/imx/imx6ul-14x14-evk.dtb"
MERGED_DTB="$SCRIPT_DIR/imx6ul-14x14-evk-audio.dtb"

echo "=== Building audio modules ==="
make clean
make

[ ! -f "fake_codec.ko" ] && { echo "Error: fake_codec.ko not built"; exit 1; }
[ ! -f "fake_platform.ko" ] && { echo "Error: fake_platform.ko not built"; exit 1; }
[ ! -f "fake_audio_card.ko" ] && { echo "Error: fake_audio_card.ko not built"; exit 1; }

echo "=== Creating modified DTB with audio devices ==="
[ ! -f "$BASE_DTB" ] && { echo "Error: Base DTB not found at $BASE_DTB"; exit 1; }
dtc -I dtb -O dts "$BASE_DTB" -o base.dts

python3 << 'PYEOF'
with open('base.dts', 'r') as f:
    lines = f.readlines()

output = []
i2c_inserted = False
root_inserted = False
platform_inserted = False
sai2_labeled = False
i2c_depth = 0
in_root = False
depth = 0

for line in lines:
    # Add label to sai@202c000 node
    if 'sai@202c000 {' in line and not sai2_labeled:
        line = line.replace('sai@202c000 {', 'sai2: sai@202c000 {')
        sai2_labeled = True

    # Track root node
    if '/ {' in line:
        in_root = True
        depth = 1
        output.append(line)
        continue
    elif in_root:
        if '{' in line:
            depth += 1
        if '}' in line:
            depth -= 1
            # Insert fake_i2s_platform before fake-audio-card
            if depth == 1 and not platform_inserted:
                indent = '\t'
                output.append(f'{indent}fake_i2s_platform: fake_i2s_platform {{\n')
                output.append(f'{indent}\tcompatible = "myvendor,fake-i2s-platform";\n')
                output.append(f'{indent}\t#sound-dai-cells = <0>;\n')
                output.append(f'{indent}\tstatus = "okay";\n')
                output.append(f'{indent}}};\n\n')
                platform_inserted = True
            # Insert fake-audio-card before final root closing brace
            if depth == 0 and not root_inserted:
                indent = '\t'
                output.append(f'{indent}fake-audio-card {{\n')
                output.append(f'{indent}\tcompatible = "myvendor,fake-audio-card";\n')
                output.append(f'{indent}\taudio-cpu = <&sai2>;\n')
                output.append(f'{indent}\taudio-codec = <&fake_codec>;\n')
                output.append(f'{indent}\taudio-platform = <&fake_i2s_platform>;\n')
                output.append(f'{indent}\tstatus = "okay";\n')
                output.append(f'{indent}}};\n\n')
                root_inserted = True

    output.append(line)

    # Insert fake_codec into i2c@21a0000
    if 'i2c@21a0000' in line and '{' in line:
        i2c_depth = 1
    elif i2c_depth > 0:
        if '{' in line:
            i2c_depth += 1
        if '}' in line:
            i2c_depth -= 1
            if i2c_depth == 0 and not i2c_inserted:
                indent = '\t\t'
                output.insert(-1, f'{indent}fake_codec: fake_codec@1a {{\n')
                output.insert(-1, f'{indent}\tcompatible = "myvendor,fake-codec";\n')
                output.insert(-1, f'{indent}\treg = <0x1a>;\n')
                output.insert(-1, f'{indent}\tstatus = "okay";\n')
                output.insert(-1, f'{indent}}};\n\n')
                i2c_inserted = True

with open('base.dts', 'w') as f:
    f.writelines(output)
PYEOF

dtc -I dts -O dtb -o "$MERGED_DTB" base.dts
rm -f base.dts

echo "=== Copying modules to rootfs ==="
mkdir -p "$ROOTFS_DIR/lib/modules"
cp fake_codec.ko fake_platform.ko fake_audio_card.ko "$ROOTFS_DIR/lib/modules/"

echo "=== Repackaging rootfs ==="
cd "$ROOTFS_DIR"
find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz

echo "=== Build complete ==="
ls -lh "$SCRIPT_DIR"/*.ko
ls -lh "$MERGED_DTB"
ls -lh "$BUILD_DIR/busybox-1.36.1/rootfs.cpio.gz"
