#!/bin/bash

echo "=== Audio Driver Verification Script ==="
echo ""
echo "Step 1: Mount proc and sysfs"
mount -t proc none /proc 2>/dev/null || echo "proc already mounted"
mount -t sysfs none /sys 2>/dev/null || echo "sysfs already mounted"

echo ""
echo "Step 2: Load fake_codec module"
insmod /lib/modules/fake_codec.ko
sleep 1

echo ""
echo "Step 3: Load fake_audio_card module"
insmod /lib/modules/fake_audio_card.ko
sleep 1

echo ""
echo "Step 4: Check dmesg for driver messages"
dmesg | grep -E "fake_codec|fake.*audio|ASoC"

echo ""
echo "Step 5: Check ALSA sound cards"
cat /proc/asound/cards 2>/dev/null || echo "No sound cards found"

echo ""
echo "Step 6: Check PCM devices"
cat /proc/asound/pcm 2>/dev/null || echo "No PCM devices found"

echo ""
echo "Step 7: Unload modules"
rmmod fake_audio_card
rmmod fake_codec

echo ""
echo "Step 8: Check remove messages"
dmesg | tail -5

echo ""
echo "=== Verification Complete ==="
