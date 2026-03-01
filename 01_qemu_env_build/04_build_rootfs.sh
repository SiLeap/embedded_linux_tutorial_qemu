#!/bin/bash
set -e

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
BUSYBOX_VER="1.36.1"
BUSYBOX_DIR="$WORKDIR/busybox-${BUSYBOX_VER}"

echo "=== 下载 BusyBox ==="

cd "$WORKDIR"
if [ ! -f "busybox-${BUSYBOX_VER}.tar.bz2" ]; then
    wget https://busybox.net/downloads/busybox-${BUSYBOX_VER}.tar.bz2
fi

if [ ! -d "$BUSYBOX_DIR" ]; then
    tar -xf busybox-${BUSYBOX_VER}.tar.bz2
fi

cd "$BUSYBOX_DIR"

echo "=== 配置 BusyBox（静态编译）==="
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- defconfig
# 启用静态编译，跳过 menuconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config

echo "=== 编译 BusyBox ==="
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc)
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- install

echo "=== 制作 initramfs ==="
cd _install
mkdir -p proc sys dev etc/init.d

cat > etc/init.d/rcS << 'RCEOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mdev -s
RCEOF
chmod +x etc/init.d/rcS

find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz

echo "=== rootfs 打包完成 ==="
ls -lh ../rootfs.cpio.gz
