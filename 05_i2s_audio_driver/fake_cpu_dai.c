// SPDX-License-Identifier: GPL-2.0
/*
 * Fake CPU DAI Driver
 * Replaces real SAI driver for QEMU testing
 */

#include <linux/module.h>
#include <linux/platform_device.h>
#include <sound/soc.h>
#include <sound/pcm_params.h>

static int fake_cpu_dai_hw_params(struct snd_pcm_substream *substream,
				   struct snd_pcm_hw_params *params,
				   struct snd_soc_dai *dai)
{
	dev_info(dai->dev, "hw_params: rate=%u, channels=%u\n",
		 params_rate(params), params_channels(params));
	return 0;
}

static int fake_cpu_dai_set_fmt(struct snd_soc_dai *dai, unsigned int fmt)
{
	dev_info(dai->dev, "set_fmt: 0x%x\n", fmt);
	return 0;
}

static const struct snd_soc_dai_ops fake_cpu_dai_ops = {
	.hw_params = fake_cpu_dai_hw_params,
	.set_fmt = fake_cpu_dai_set_fmt,
};

static struct snd_soc_dai_driver fake_cpu_dai_driver = {
	.name = "fake-cpu-dai",
	.playback = {
		.channels_min = 1,
		.channels_max = 2,
		.rates = SNDRV_PCM_RATE_8000_48000,
		.formats = SNDRV_PCM_FMTBIT_S16_LE | SNDRV_PCM_FMTBIT_S24_LE,
	},
	.capture = {
		.channels_min = 1,
		.channels_max = 2,
		.rates = SNDRV_PCM_RATE_8000_48000,
		.formats = SNDRV_PCM_FMTBIT_S16_LE | SNDRV_PCM_FMTBIT_S24_LE,
	},
	.ops = &fake_cpu_dai_ops,
};

static const struct snd_soc_component_driver fake_cpu_component = {
	.name = "fake-cpu",
};

static int fake_cpu_dai_probe(struct platform_device *pdev)
{
	int ret;

	ret = devm_snd_soc_register_component(&pdev->dev, &fake_cpu_component,
					      &fake_cpu_dai_driver, 1);
	if (ret)
		return ret;

	dev_info(&pdev->dev, "fake_cpu_dai probe OK\n");
	return 0;
}

static const struct of_device_id fake_cpu_dai_of_match[] = {
	{ .compatible = "myvendor,fake-cpu-dai" },
	{ }
};
MODULE_DEVICE_TABLE(of, fake_cpu_dai_of_match);

static struct platform_driver fake_cpu_dai_driver_platform = {
	.driver = {
		.name = "fake-cpu-dai",
		.of_match_table = fake_cpu_dai_of_match,
	},
	.probe = fake_cpu_dai_probe,
};

module_platform_driver(fake_cpu_dai_driver_platform);

MODULE_AUTHOR("Felix");
MODULE_DESCRIPTION("Fake CPU DAI Driver");
MODULE_LICENSE("GPL");
