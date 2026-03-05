// SPDX-License-Identifier: GPL-2.0
/*
 * Fake I2C ASoC Codec Driver
 * Educational driver for demonstrating ASoC codec layer
 */

#include <linux/module.h>
#include <linux/i2c.h>
#include <linux/of.h>
#include <sound/soc.h>
#include <sound/pcm_params.h>

struct fake_codec_priv {
	struct device *dev;
};

static int fake_codec_hw_params(struct snd_pcm_substream *substream,
				struct snd_pcm_hw_params *params,
				struct snd_soc_dai *dai)
{
	struct snd_soc_component *component = dai->component;
	struct fake_codec_priv *priv = snd_soc_component_get_drvdata(component);

	dev_info(priv->dev, "hw_params: rate=%u, format=%u, channels=%u\n",
		 params_rate(params), params_format(params), params_channels(params));

	return 0;
}

static int fake_codec_set_fmt(struct snd_soc_dai *dai, unsigned int fmt)
{
	struct snd_soc_component *component = dai->component;
	struct fake_codec_priv *priv = snd_soc_component_get_drvdata(component);

	dev_info(priv->dev, "set_fmt: fmt=0x%x\n", fmt);

	return 0;
}

static const struct snd_soc_dai_ops fake_codec_dai_ops = {
	.hw_params = fake_codec_hw_params,
	.set_fmt = fake_codec_set_fmt,
};

static int fake_codec_component_probe(struct snd_soc_component *component)
{
	dev_info(component->dev, "ASoC component probe OK\n");
	return 0;
}

static const struct snd_soc_component_driver fake_codec_component_driver = {
	.probe = fake_codec_component_probe,
};

static struct snd_soc_dai_driver fake_codec_dai = {
	.name = "fake-codec-dai",
	.playback = {
		.stream_name = "Playback",
		.channels_min = 1,
		.channels_max = 2,
		.rates = SNDRV_PCM_RATE_8000_48000,
		.formats = SNDRV_PCM_FMTBIT_S16_LE |
			   SNDRV_PCM_FMTBIT_S24_LE |
			   SNDRV_PCM_FMTBIT_S32_LE,
	},
	.capture = {
		.stream_name = "Capture",
		.channels_min = 1,
		.channels_max = 2,
		.rates = SNDRV_PCM_RATE_8000_48000,
		.formats = SNDRV_PCM_FMTBIT_S16_LE |
			   SNDRV_PCM_FMTBIT_S24_LE |
			   SNDRV_PCM_FMTBIT_S32_LE,
	},
	.ops = &fake_codec_dai_ops,
};

static int fake_codec_i2c_probe(struct i2c_client *client)
{
	struct fake_codec_priv *priv;
	int ret;

	priv = devm_kzalloc(&client->dev, sizeof(*priv), GFP_KERNEL);
	if (!priv)
		return -ENOMEM;

	priv->dev = &client->dev;
	i2c_set_clientdata(client, priv);

	ret = devm_snd_soc_register_component(&client->dev,
					      &fake_codec_component_driver,
					      &fake_codec_dai, 1);
	if (ret < 0) {
		dev_err(&client->dev, "Failed to register component: %d\n", ret);
		return ret;
	}

	dev_info(&client->dev, "fake_codec I2C probe OK, addr=0x%x\n", client->addr);

	return 0;
}

static void fake_codec_i2c_remove(struct i2c_client *client)
{
	dev_info(&client->dev, "remove called\n");
}

static const struct of_device_id fake_codec_of_match[] = {
	{ .compatible = "myvendor,fake-codec" },
	{ }
};
MODULE_DEVICE_TABLE(of, fake_codec_of_match);

static const struct i2c_device_id fake_codec_id[] = {
	{ "fake_codec", 0 },
	{ }
};
MODULE_DEVICE_TABLE(i2c, fake_codec_id);

static struct i2c_driver fake_codec_driver = {
	.driver = {
		.name = "fake-codec",
		.of_match_table = fake_codec_of_match,
	},
	.probe_new = fake_codec_i2c_probe,
	.remove = fake_codec_i2c_remove,
	.id_table = fake_codec_id,
};

module_i2c_driver(fake_codec_driver);

MODULE_AUTHOR("Felix");
MODULE_DESCRIPTION("Fake I2C ASoC Codec Driver");
MODULE_LICENSE("GPL");
