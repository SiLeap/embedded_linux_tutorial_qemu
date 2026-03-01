# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Linux kernel and driver development experiments using QEMU emulation for i.MX6UL/i.MX6ULL (ARM Cortex-A7).

- **Kernel**: Linux 6.1 at `01_qemu_env_build/linux-6.1/`
- **Toolchain**: arm-linux-gnueabihf
- **QEMU Machine**: mcimx6ul-evk
- **Rootfs**: BusyBox 1.36.1 (static)

## Quick Start

Run scripts in `01_qemu_env_build/` sequentially:
```bash
cd 01_qemu_env_build
bash 01_install_toolchain.sh  # Install arm-linux-gnueabihf
bash 02_install_qemu.sh        # Install QEMU
bash 03_build_kernel.sh        # Build kernel + DTB
bash 04_build_rootfs.sh        # Build BusyBox rootfs
bash 05_run_qemu.sh            # Launch QEMU
```

## Kernel Development

**Rebuild kernel**:
```bash
cd 01_qemu_env_build/linux-6.1
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs
```

**Rebuild rootfs** (after adding files to `_install/`):
```bash
cd 01_qemu_env_build/busybox-1.36.1/_install
find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz
```

**Add test programs to rootfs**:
```bash
arm-linux-gnueabihf-gcc -static -o mytest mytest.c
cp mytest 01_qemu_env_build/busybox-1.36.1/_install/
# Then rebuild rootfs (see above)
```

## Important Notes

- **Always use `-static`** when cross-compiling programs (rootfs has no shared libraries)
- **Kernel parameter `video=off`** is required to avoid 60s boot delay (QEMU LCDIF emulation issue)
- **QEMU exit**: `Ctrl+A` then `X`
- **DTB location** varies by kernel version: `arch/arm/boot/dts/imx6ul-14x14-evk.dtb` or `arch/arm/boot/dts/nxp/imx/imx6ul-14x14-evk.dtb`

