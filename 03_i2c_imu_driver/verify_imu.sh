#!/bin/sh
echo "=== fake_imu Verification ==="
insmod /lib/modules/fake_imu.ko
sleep 1
echo "[1] Probe:"
dmesg | grep "fake_imu.*probe"
echo "[2] Device name:"
cat /sys/bus/iio/devices/iio:device0/name
echo "[3] Accel X:"
cat /sys/bus/iio/devices/iio:device0/in_accel_x_raw
echo "[4] Accel Y:"
cat /sys/bus/iio/devices/iio:device0/in_accel_y_raw
echo "[5] Accel Z:"
cat /sys/bus/iio/devices/iio:device0/in_accel_z_raw
echo "[6] Scale:"
cat /sys/bus/iio/devices/iio:device0/in_accel_scale
echo "[7] Remove:"
rmmod fake_imu
dmesg | grep "fake_imu.*remove"
echo "=== Complete ==="
