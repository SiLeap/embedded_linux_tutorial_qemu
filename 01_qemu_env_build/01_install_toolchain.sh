#!/bin/bash
set -e

echo "=== 安装交叉编译工具链 ==="

sudo apt update
sudo apt install -y gcc-arm-linux-gnueabihf \
                    g++-arm-linux-gnueabihf \
                    binutils-arm-linux-gnueabihf

echo "=== 验证工具链 ==="
arm-linux-gnueabihf-gcc --version

echo "=== 工具链安装完成 ==="
