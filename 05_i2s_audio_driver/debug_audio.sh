#!/bin/sh
# Audio driver debug script

echo "=== Step 1: Check kernel SAI driver ==="
dmesg | grep -i "fsl.*sai\|202c000"

echo ""
echo "=== Step 2: Check device tree nodes ==="
ls -l /sys/firmware/devicetree/base/fake* 2>/dev/null || echo "No fake nodes found"
ls -l /sys/firmware/devicetree/base/soc/bus*/spba-bus*/sai@202c000/ 2>/dev/null || echo "SAI2 node not found"

echo ""
echo "=== Step 3: Load codec driver ==="
insmod /lib/modules/fake_codec.ko
sleep 1
dmesg | tail -5

echo ""
echo "=== Step 4: Load platform driver ==="
insmod /lib/modules/fake_platform.ko
if [ $? -eq 0 ]; then
    echo "insmod fake_platform.ko: SUCCESS"
else
    echo "insmod fake_platform.ko: FAILED (exit code $?)"
fi
sleep 1
dmesg | tail -5

echo ""
echo "=== Step 5: Load machine driver ==="
insmod /lib/modules/fake_audio_card.ko
sleep 1
dmesg | tail -10

echo ""
echo "=== Step 6: Check result ==="
cat /proc/asound/cards 2>/dev/null || echo "No sound cards found"

echo ""
echo "=== Step 7: Check deferred probes ==="
cat /sys/kernel/debug/devices_deferred 2>/dev/null || echo "Cannot access deferred probe list"
