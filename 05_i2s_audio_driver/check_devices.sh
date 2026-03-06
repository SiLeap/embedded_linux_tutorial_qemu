#!/bin/sh
# Detailed device tree and driver check

echo "=== Check fake_i2s_platform device node ==="
ls -l /sys/firmware/devicetree/base/ | grep fake

echo ""
echo "=== Check if fake_i2s_platform device exists in /sys/devices ==="
find /sys/devices -name "*fake*" 2>/dev/null

echo ""
echo "=== Check platform devices ==="
ls /sys/bus/platform/devices/ | grep -E "fake|202c000"

echo ""
echo "=== Check if fake_platform driver is registered ==="
ls /sys/bus/platform/drivers/ | grep fake

echo ""
echo "=== Load fake_platform.ko and check result ==="
insmod /lib/modules/fake_platform.ko
echo "insmod exit code: $?"
lsmod | grep fake

echo ""
echo "=== Check dmesg for fake_platform ==="
dmesg | grep -i "fake.*platform"

echo ""
echo "=== Check SAI2 status ==="
dmesg | grep -i "202c000\|fsl.*sai"
