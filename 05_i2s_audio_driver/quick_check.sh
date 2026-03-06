#!/bin/sh
# Quick diagnostic

echo "=== Check loaded modules ==="
lsmod

echo ""
echo "=== Check dmesg for all fake drivers ==="
dmesg | grep -i fake

echo ""
echo "=== Check platform devices ==="
ls /sys/bus/platform/devices/ | grep fake

echo ""
echo "=== Check platform drivers ==="
ls /sys/bus/platform/drivers/ | grep fake
