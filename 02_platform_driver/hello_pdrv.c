// hello_pdrv.c — 最简 platform driver 示例
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/of.h>

static int hello_probe(struct platform_device *pdev)
{
	dev_info(&pdev->dev, "hello_pdrv: probe called!\n");
	return 0;
}

static int hello_remove(struct platform_device *pdev)
{
	dev_info(&pdev->dev, "hello_pdrv: remove called!\n");
	return 0;
}

static const struct of_device_id hello_of_match[] = {
	{ .compatible = "myvendor,hello-device" },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, hello_of_match);

static struct platform_driver hello_driver = {
	.probe  = hello_probe,
	.remove = hello_remove,
	.driver = {
		.name           = "hello_pdrv",
		.of_match_table = hello_of_match,
	},
};
module_platform_driver(hello_driver);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Felix");
MODULE_DESCRIPTION("Minimal platform driver demo");
