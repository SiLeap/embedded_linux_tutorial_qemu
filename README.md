# embedded_linux_tutorial_qemu

嵌入式 Linux 驱动开发教程（QEMU 环境）

## 目录结构

- `01_qemu_env_build/` - QEMU 环境搭建（内核、rootfs、工具链）
- `02_platform_driver/` - 平台设备驱动入门（Platform Driver Hello World）
- `03_i2c_imu_driver/` - I2C IMU 驱动实战（IIO 子系统 + I2C 总线）

## 快速开始

1. 构建 QEMU 环境：`cd 01_qemu_env_build && bash 01-05 脚本`
2. 选择模块进入对应目录，执行 `bash build.sh && bash run_qemu.sh`
3. 在 QEMU 中验证驱动功能

## 环境要求

- 交叉编译器：arm-linux-gnueabihf-gcc
- QEMU：支持 mcimx6ul-evk 机器类型
- Linux 内核：6.1
