// SPDX-License-Identifier: GPL-2.0
/*
 * Fake IMU I2C IIO driver for QEMU testing
 */

#include <linux/module.h>
#include <linux/i2c.h>
#include <linux/iio/iio.h>
#include <linux/of.h>

struct fake_imu_data {
	struct i2c_client *client;
};

#define FAKE_IMU_ACCEL_CHANNEL(axis, index) { \
	.type = IIO_ACCEL, \
	.modified = 1, \
	.channel2 = IIO_MOD_##axis, \
	.info_mask_separate = BIT(IIO_CHAN_INFO_RAW), \
	.info_mask_shared_by_type = BIT(IIO_CHAN_INFO_SCALE), \
	.scan_index = index, \
}

static const struct iio_chan_spec fake_imu_channels[] = {
	FAKE_IMU_ACCEL_CHANNEL(X, 0),
	FAKE_IMU_ACCEL_CHANNEL(Y, 1),
	FAKE_IMU_ACCEL_CHANNEL(Z, 2),
};

static int fake_imu_read_raw(struct iio_dev *indio_dev,
			     struct iio_chan_spec const *chan,
			     int *val, int *val2, long mask)
{
	switch (mask) {
	case IIO_CHAN_INFO_RAW:
		if (chan->channel2 == IIO_MOD_Z)
			*val = 1000;
		else
			*val = 0;
		return IIO_VAL_INT;
	case IIO_CHAN_INFO_SCALE:
		*val = 0;
		*val2 = 9806;
		return IIO_VAL_INT_PLUS_MICRO;
	default:
		return -EINVAL;
	}
}

static const struct iio_info fake_imu_info = {
	.read_raw = fake_imu_read_raw,
};

static int fake_imu_probe(struct i2c_client *client,
			  const struct i2c_device_id *id)
{
	struct iio_dev *indio_dev;
	struct fake_imu_data *data;

	indio_dev = devm_iio_device_alloc(&client->dev, sizeof(*data));
	if (!indio_dev)
		return -ENOMEM;

	data = iio_priv(indio_dev);
	data->client = client;

	indio_dev->name = "fake_imu";
	indio_dev->info = &fake_imu_info;
	indio_dev->channels = fake_imu_channels;
	indio_dev->num_channels = ARRAY_SIZE(fake_imu_channels);
	indio_dev->modes = INDIO_DIRECT_MODE;

	dev_info(&client->dev, "probe OK, addr=0x%02x\n", client->addr);

	return devm_iio_device_register(&client->dev, indio_dev);
}

static void fake_imu_remove(struct i2c_client *client)
{
	dev_info(&client->dev, "remove called\n");
}

static const struct of_device_id fake_imu_of_match[] = {
	{ .compatible = "myvendor,fake-imu" },
	{ }
};
MODULE_DEVICE_TABLE(of, fake_imu_of_match);

static const struct i2c_device_id fake_imu_id[] = {
	{ "fake_imu", 0 },
	{ }
};
MODULE_DEVICE_TABLE(i2c, fake_imu_id);

static struct i2c_driver fake_imu_driver = {
	.driver = {
		.name = "fake_imu",
		.of_match_table = fake_imu_of_match,
	},
	.probe = fake_imu_probe,
	.remove = fake_imu_remove,
	.id_table = fake_imu_id,
};

module_i2c_driver(fake_imu_driver);

MODULE_AUTHOR("Felix");
MODULE_DESCRIPTION("Fake IMU I2C IIO driver");
MODULE_LICENSE("GPL");
