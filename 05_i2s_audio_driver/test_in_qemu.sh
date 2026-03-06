#!/bin/bash
# Test script to run inside QEMU

echo "=== Loading audio modules ==="
insmod /lib/modules/fake_codec.ko
sleep 1
insmod /lib/modules/fake_platform.ko
sleep 1
insmod /lib/modules/fake_audio_card.ko
sleep 2

echo ""
echo "=== Checking dmesg for driver messages ==="
dmesg | grep -E "fake_codec|fake.*platform|fake.*audio" | tail -20

echo ""
echo "=== Checking ALSA cards ==="
cat /proc/asound/cards

echo ""
echo "=== Checking PCM devices ==="
cat /proc/asound/pcm

echo ""
echo "=== Unloading modules ==="
rmmod fake_audio_card
rmmod fake_platform
rmmod fake_codec

echo ""
echo "=== Final dmesg check ==="
dmesg | tail -10
