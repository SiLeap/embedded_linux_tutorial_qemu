# CLAUDE.md — embedded_linux_tutorial_qemu

## Context
Linux kernel driver dev on QEMU (i.MX6UL, Cortex-A7).
- Kernel 6.1 @ 01_qemu_env_build/linux-6.1/
- Toolchain: arm-linux-gnueabihf
- Machine: mcimx6ul-evk / BusyBox 1.36.1 (static)
- All user programs MUST use -static linking.

## Build
- Env setup: run 01-05 scripts in 01_qemu_env_build/ sequentially
- Out-of-tree module: make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- M=$(pwd) modules
- QEMU run: bash 01_qemu_env_build/05_run_qemu.sh

## Project Rules
- Naming: module_action_object (e.g. imu_read_accel)
- Every probe() MUST have matching remove() cleanup
- DT compatible string MUST exactly match driver of_match_table
- No dynamic allocation inside IRQ handlers
- I2C/SPI transfer return values MUST be checked

## Known Issues
- QEMU needs video=off kernel param → otherwise LCDIF causes 60s boot delay
- DTB path varies: .../imx6ul-14x14-evk.dtb OR .../nxp/imx/imx6ul-14x14-evk.dtb
- QEMU exit: Ctrl+A then X
- QEMU overlay: .dtbo 无法运行时加载 → 使用 fdtoverlay 预先合并到 DTB
- Notion MCP: 创建页面报错 MCP -32603 → 使用 parent.database_id 而非 data_source_id