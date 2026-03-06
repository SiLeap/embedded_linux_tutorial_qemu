#!/bin/bash
echo "=== Verifying Device Tree Structure ==="
DTB="imx6ul-14x14-evk-audio.dtb"

echo -e "\n1. Checking fake_cpu_dai location:"
dtc -I dtb -O dts "$DTB" 2>/dev/null | grep -B 3 "fake_cpu_dai {" | head -6

echo -e "\n2. Checking fake_i2s_platform location:"
dtc -I dtb -O dts "$DTB" 2>/dev/null | grep -B 3 "fake_i2s_platform {" | head -6

echo -e "\n3. Checking fake_codec in i2c:"
dtc -I dtb -O dts "$DTB" 2>/dev/null | grep -A 2 "fake_codec@1a {" | head -5

echo -e "\n4. Checking fake-audio-card:"
dtc -I dtb -O dts "$DTB" 2>/dev/null | grep -A 4 "fake-audio-card {" | head -7

echo -e "\n=== Verification Complete ==="
