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
[ ! -f "fake_cpu_dai.ko" ] && { echo "Error: fake_cpu_dai.ko not built"; exit 1; }
[ ! -f "fake_platform.ko" ] && { echo "Error: fake_platform.ko not built"; exit 1; }
[ ! -f "fake_audio_card.ko" ] && { echo "Error: fake_audio_card.ko not built"; exit 1; }

echo "=== Creating modified DTB with audio devices ==="
[ ! -f "$BASE_DTB" ] && { echo "Error: Base DTB not found at $BASE_DTB"; exit 1; }
dtc -I dtb -O dts "$BASE_DTB" -o base.dts

python3 << 'PYEOF'
with open('base.dts', 'r') as f:
    content = f.read()

# Insert fake_cpu_dai and fake_i2s_platform into /soc node
soc_start = content.find('soc {')
if soc_start == -1:
    soc_start = content.find('soc@')
if soc_start != -1:
    depth = 0
    i = soc_start
    while i < len(content):
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
            if depth == 0:
                nodes = '''\t\tfake_cpu_dai: fake_cpu_dai {
\t\t\tcompatible = "myvendor,fake-cpu-dai";
\t\t\t#sound-dai-cells = <0>;
\t\t};

\t\tfake_i2s_platform: fake_i2s_platform {
\t\t\tcompatible = "myvendor,fake-i2s-platform";
\t\t\t#sound-dai-cells = <0>;
\t\t};

\t'''
                content = content[:i] + nodes + content[i:]
                break
        i += 1

# Insert fake_codec into i2c@21a0000
i2c_start = content.find('i2c@21a0000 {')
if i2c_start != -1:
    depth = 0
    i = i2c_start
    while i < len(content):
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
            if depth == 0:
                codec_node = '''\t\t\tfake_codec: fake_codec@1b {
\t\t\t\tcompatible = "myvendor,fake-codec";
\t\t\t\treg = <0x1b>;
\t\t\t};

\t\t\t'''
                content = content[:i] + codec_node + content[i:]
                break
        i += 1

# Insert fake-audio-card at root level (before final };)
last_brace = content.rfind('\n};')
if last_brace != -1:
    card_node = '''\n\tfake-audio-card {
\t\tcompatible = "myvendor,fake-audio-card";
\t\taudio-cpu = <&fake_cpu_dai>;
\t\taudio-codec = <&fake_codec>;
\t\taudio-platform = <&fake_i2s_platform>;
\t};
'''
    content = content[:last_brace] + card_node + content[last_brace:]

with open('base.dts', 'w') as f:
    f.write(content)
PYEOF

dtc -I dts -O dtb -o "$MERGED_DTB" base.dts
rm -f base.dts

echo "=== Copying modules to rootfs ==="
mkdir -p "$ROOTFS_DIR/lib/modules"
cp fake_codec.ko fake_cpu_dai.ko fake_platform.ko fake_audio_card.ko load_audio.sh "$ROOTFS_DIR/lib/modules/"

echo "=== Repackaging rootfs ==="
cd "$ROOTFS_DIR"
find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz

echo "=== Build complete ==="
ls -lh "$SCRIPT_DIR"/*.ko
ls -lh "$MERGED_DTB"
ls -lh "$BUILD_DIR/busybox-1.36.1/rootfs.cpio.gz"
