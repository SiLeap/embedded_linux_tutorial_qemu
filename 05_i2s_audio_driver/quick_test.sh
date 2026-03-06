#!/bin/bash
# Quick automated test for audio drivers

cd /home/felix/linux_kernel_develop_qemu/05_i2s_audio_driver

# Create test commands
cat > /tmp/test_cmds.txt << 'TESTEOF'
sleep 3
echo "=== Checking platform devices ==="
ls /sys/bus/platform/devices/ | grep fake
echo ""
echo "=== Loading modules ==="
sh /lib/modules/load_audio.sh
echo ""
echo "=== Checking dmesg ==="
dmesg | grep -i fake | tail -20
echo ""
echo "=== Test complete, exiting ==="
poweroff -f
TESTEOF

# Run QEMU with automated commands
timeout 30 bash run_qemu.sh < /tmp/test_cmds.txt 2>&1 | tee /tmp/qemu_output.log

echo ""
echo "=== Test Results ==="
grep -E "(fake.*probe|Failed to register|platform.*fake)" /tmp/qemu_output.log | tail -15
