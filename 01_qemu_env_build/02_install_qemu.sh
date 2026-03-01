#!/bin/bash
set -e

echo "=== 安装 QEMU ==="

sudo apt install -y qemu-system-arm qemu-utils

echo "=== 验证 QEMU ==="
qemu-system-arm --version
echo "=== 支持的 i.MX 机型 ==="
qemu-system-arm -machine help | grep -i imx || echo "未找到 imx 相关机型（可能版本较低）"

echo "=== QEMU 安装完成 ==="
