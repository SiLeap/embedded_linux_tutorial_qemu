#!/bin/bash
cd /home/felix/linux_kernel_develop_qemu/05_i2s_audio_driver

cat > /tmp/i2c_check.txt << 'TESTEOF'
sleep 3
echo "=== Checking I2C buses ==="
ls /sys/bus/i2c/devices/
echo ""
echo "=== Checking i2c-1 devices ==="
ls /sys/bus/i2c/devices/i2c-1/ 2>/dev/null || echo "i2c-1 not found"
echo ""
echo "=== Checking for fake_codec in device tree ==="
ls /sys/firmware/devicetree/base/soc/bus@2000000/i2c@21a0000/ | grep fake
poweroff -f
TESTEOF

timeout 30 bash run_qemu.sh < /tmp/i2c_check.txt 2>&1 | grep -A 20 "Checking I2C"
