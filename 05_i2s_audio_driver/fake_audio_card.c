// SPDX-License-Identifier: GPL-2.0
/*
 * Fake Audio Card Machine Driver
 * Educational driver for demonstrating ASoC machine layer
 */

#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <sound/soc.h>

SND_SOC_DAILINK_DEFS(fake_audio_hifi,
	DAILINK_COMP_ARRAY(COMP_EMPTY()),
	DAILINK_COMP_ARRAY(COMP_EMPTY()),
	DAILINK_COMP_ARRAY(COMP_EMPTY()));

static struct snd_soc_dai_link fake_audio_dai_link = {
	.name = "Fake-Audio-HiFi",
	.stream_name = "Fake-Audio-HiFi",
	.dai_fmt = SND_SOC_DAIFMT_I2S |
		   SND_SOC_DAIFMT_NB_NF |
		   SND_SOC_DAIFMT_CBS_CFS,
	SND_SOC_DAILINK_REG(fake_audio_hifi),
};

static struct snd_soc_card fake_audio_card = {
	.name = "FakeAudioCard",
	.owner = THIS_MODULE,
	.dai_link = &fake_audio_dai_link,
	.num_links = 1,
};

static int fake_audio_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct device_node *cpu_np, *codec_np;
	struct snd_soc_dai_link *dai_link = &fake_audio_dai_link;
	int ret;

	fake_audio_card.dev = dev;

	cpu_np = of_parse_phandle(dev->of_node, "audio-cpu", 0);
	if (!cpu_np) {
		dev_err(dev, "Failed to parse audio-cpu phandle\n");
		return -EINVAL;
	}

	codec_np = of_parse_phandle(dev->of_node, "audio-codec", 0);
	if (!codec_np) {
		dev_err(dev, "Failed to parse audio-codec phandle\n");
		of_node_put(cpu_np);
		return -EINVAL;
	}

	dai_link->cpus->of_node = cpu_np;
	dai_link->codecs->of_node = codec_np;
	dai_link->platforms->of_node = cpu_np;

	ret = devm_snd_soc_register_card(dev, &fake_audio_card);
	if (ret) {
		dev_err(dev, "Failed to register card: %d\n", ret);
		of_node_put(cpu_np);
		of_node_put(codec_np);
		return ret;
	}

	dev_info(dev, "Fake-Audio-Card registered OK\n");

	of_node_put(cpu_np);
	of_node_put(codec_np);

	return 0;
}

static const struct of_device_id fake_audio_of_match[] = {
	{ .compatible = "myvendor,fake-audio-card" },
	{ }
};
MODULE_DEVICE_TABLE(of, fake_audio_of_match);

static struct platform_driver fake_audio_driver = {
	.driver = {
		.name = "fake-audio-card",
		.of_match_table = fake_audio_of_match,
	},
	.probe = fake_audio_probe,
};

module_platform_driver(fake_audio_driver);

MODULE_AUTHOR("Felix");
MODULE_DESCRIPTION("Fake Audio Card Machine Driver");
MODULE_LICENSE("GPL");
