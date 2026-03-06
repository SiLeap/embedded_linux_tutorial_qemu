#!/bin/sh
# Load I2S audio drivers in correct dependency order

echo "Loading fake_codec (codec layer)..."
insmod /lib/modules/fake_codec.ko
if [ $? -ne 0 ]; then
    echo "Failed to load fake_codec.ko"
    exit 1
fi

echo "Loading fake_cpu_dai (CPU DAI layer)..."
insmod /lib/modules/fake_cpu_dai.ko
if [ $? -ne 0 ]; then
    echo "Failed to load fake_cpu_dai.ko"
    exit 1
fi

echo "Loading fake_platform (platform layer)..."
insmod /lib/modules/fake_platform.ko
if [ $? -ne 0 ]; then
    echo "Failed to load fake_platform.ko"
    exit 1
fi

echo "Loading fake_audio_card (machine layer)..."
insmod /lib/modules/fake_audio_card.ko
if [ $? -ne 0 ]; then
    echo "Failed to load fake_audio_card.ko"
    exit 1
fi

echo ""
echo "=== Audio card registration status ==="
cat /proc/asound/cards
