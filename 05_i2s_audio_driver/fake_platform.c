// SPDX-License-Identifier: GPL-2.0
/*
 * Fake Platform Driver with hrtimer-based DMA simulation
 * Educational driver for demonstrating ASoC platform layer
 */

#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/hrtimer.h>
#include <linux/slab.h>
#include <sound/core.h>
#include <sound/pcm.h>
#include <sound/soc.h>

struct fake_platform_priv {
	struct device *dev;
	struct snd_pcm_substream *substream;
	struct hrtimer hrt;
	ktime_t period_time;
	unsigned int hw_ptr;
	unsigned int period_size;
	unsigned int buffer_size;
	atomic_t running;
};

static const struct snd_pcm_hardware fake_platform_hw = {
	.info = SNDRV_PCM_INFO_INTERLEAVED |
		SNDRV_PCM_INFO_MMAP |
		SNDRV_PCM_INFO_MMAP_VALID,
	.formats = SNDRV_PCM_FMTBIT_S16_LE |
		   SNDRV_PCM_FMTBIT_S24_LE |
		   SNDRV_PCM_FMTBIT_S32_LE,
	.rates = SNDRV_PCM_RATE_8000_48000,
	.rate_min = 8000,
	.rate_max = 48000,
	.channels_min = 1,
	.channels_max = 2,
	.buffer_bytes_max = 65536,
	.period_bytes_min = 256,
	.period_bytes_max = 16384,
	.periods_min = 2,
	.periods_max = 16,
};

static enum hrtimer_restart fake_platform_hrtimer_callback(struct hrtimer *hrt)
{
	struct fake_platform_priv *priv = container_of(hrt, struct fake_platform_priv, hrt);

	if (!atomic_read(&priv->running))
		return HRTIMER_NORESTART;

	priv->hw_ptr += priv->period_size;
	if (priv->hw_ptr >= priv->buffer_size)
		priv->hw_ptr = 0;

	snd_pcm_period_elapsed(priv->substream);
	hrtimer_forward_now(hrt, priv->period_time);

	return HRTIMER_RESTART;
}

static int fake_platform_open(struct snd_soc_component *component,
			       struct snd_pcm_substream *substream)
{
	struct fake_platform_priv *priv;

	priv = kzalloc(sizeof(*priv), GFP_KERNEL);
	if (!priv)
		return -ENOMEM;

	priv->dev = component->dev;
	priv->substream = substream;
	hrtimer_init(&priv->hrt, CLOCK_MONOTONIC, HRTIMER_MODE_REL);
	priv->hrt.function = fake_platform_hrtimer_callback;
	atomic_set(&priv->running, 0);

	snd_soc_set_runtime_hwparams(substream, &fake_platform_hw);
	substream->runtime->private_data = priv;

	return 0;
}

static int fake_platform_close(struct snd_soc_component *component,
				struct snd_pcm_substream *substream)
{
	struct fake_platform_priv *priv = substream->runtime->private_data;

	hrtimer_cancel(&priv->hrt);
	kfree(priv);

	return 0;
}

static int fake_platform_hw_params(struct snd_soc_component *component,
				    struct snd_pcm_substream *substream,
				    struct snd_pcm_hw_params *params)
{
	struct fake_platform_priv *priv = substream->runtime->private_data;
	unsigned int rate = params_rate(params);

	priv->period_size = params_period_size(params);
	priv->buffer_size = params_buffer_size(params);
	priv->hw_ptr = 0;
	priv->period_time = ktime_set(0, (priv->period_size * NSEC_PER_SEC) / rate);

	dev_info(priv->dev, "DMA buffer allocated: %u frames @ %u Hz, period %u frames\n",
		 priv->buffer_size, rate, priv->period_size);

	return 0;
}

static int fake_platform_hw_free(struct snd_soc_component *component,
				  struct snd_pcm_substream *substream)
{
	struct fake_platform_priv *priv = substream->runtime->private_data;

	if (atomic_read(&priv->running))
		hrtimer_cancel(&priv->hrt);

	return 0;
}

static int fake_platform_trigger(struct snd_soc_component *component,
				  struct snd_pcm_substream *substream, int cmd)
{
	struct fake_platform_priv *priv = substream->runtime->private_data;

	switch (cmd) {
	case SNDRV_PCM_TRIGGER_START:
	case SNDRV_PCM_TRIGGER_RESUME:
		atomic_set(&priv->running, 1);
		hrtimer_start(&priv->hrt, priv->period_time, HRTIMER_MODE_REL);
		dev_info(priv->dev, "hrtimer started\n");
		break;
	case SNDRV_PCM_TRIGGER_STOP:
	case SNDRV_PCM_TRIGGER_SUSPEND:
		atomic_set(&priv->running, 0);
		hrtimer_cancel(&priv->hrt);
		dev_info(priv->dev, "hrtimer stopped\n");
		break;
	default:
		return -EINVAL;
	}

	return 0;
}

static snd_pcm_uframes_t fake_platform_pointer(struct snd_soc_component *component,
						struct snd_pcm_substream *substream)
{
	struct fake_platform_priv *priv = substream->runtime->private_data;

	return priv->hw_ptr;
}

static int fake_platform_pcm_construct(struct snd_soc_component *component,
					struct snd_soc_pcm_runtime *rtd)
{
	return snd_pcm_set_managed_buffer_all(rtd->pcm, SNDRV_DMA_TYPE_VMALLOC,
					       NULL, 65536, 65536);
}

static const struct snd_soc_component_driver fake_platform_component = {
	.name = "fake-platform",
	.open = fake_platform_open,
	.close = fake_platform_close,
	.hw_params = fake_platform_hw_params,
	.hw_free = fake_platform_hw_free,
	.trigger = fake_platform_trigger,
	.pointer = fake_platform_pointer,
	.pcm_construct = fake_platform_pcm_construct,
};

static int fake_platform_probe(struct platform_device *pdev)
{
	dev_info(&pdev->dev, "fake_platform probe\n");
	return devm_snd_soc_register_component(&pdev->dev,
					       &fake_platform_component,
					       NULL, 0);
}

static const struct of_device_id fake_platform_of_match[] = {
	{ .compatible = "myvendor,fake-i2s-platform" },
	{ }
};
MODULE_DEVICE_TABLE(of, fake_platform_of_match);

static struct platform_driver fake_platform_driver = {
	.driver = {
		.name = "fake-i2s-platform",
		.of_match_table = fake_platform_of_match,
	},
	.probe = fake_platform_probe,
};

module_platform_driver(fake_platform_driver);

MODULE_AUTHOR("Felix");
MODULE_DESCRIPTION("Fake Platform Driver with hrtimer DMA simulation");
MODULE_LICENSE("GPL");
MODULE_ALIAS("platform:fake-i2s-platform");

