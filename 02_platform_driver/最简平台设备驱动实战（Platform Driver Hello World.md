# 最简平台设备驱动实战（Platform Driver Hello World）

本文从零开始，逐步完成一个最小可运行的 Platform Device Driver，覆盖 **驱动代码 → Makefile → 编译 → 修改设备树 → 打包进 rootfs → QEMU 加载验证** 全流程。

> **目标平台**：QEMU mcimx6ul-evk（i.MX6UL Cortex-A7）+ Linux 6.1 + BusyBox rootfs

---

## 1. 前置条件

确保以下环境已就绪（参考 `01_qemu_env_build/` 下的构建脚本）：

- [ ] 交叉编译器 `arm-linux-gnueabihf-gcc` 可用
- [ ] 已编译 Linux 6.1 内核源码，且包含 `modules` 目标（位于 `01_qemu_env_build/linux-6.1/`）
- [ ] QEMU mcimx6ul-evk 能正常启动 BusyBox rootfs（`01_qemu_env_build/05_run_qemu.sh`）

---

## 2. 快速开始（一键构建）

本目录已包含全部源码和自动化脚本，可直接执行：

```bash
cd 02_platform_driver

# 一键完成：编译模块 → 修改设备树 → 打包 rootfs
bash build.sh

# 启动 QEMU
bash run_qemu.sh
```

QEMU 启动后，在串口终端中验证：

```bash
insmod /lib/modules/hello_pdrv.ko
dmesg | grep hello_pdrv
# 预期: hello_pdrv hello_device: hello_pdrv: probe called!

rmmod hello_pdrv
dmesg | grep hello_pdrv
# 预期: hello_pdrv hello_device: hello_pdrv: remove called!
```

> 退出 QEMU：`Ctrl+A` 然后 `X`

如需了解每一步的原理，请继续阅读下文。

---

## 3. 目录结构

```
02_platform_driver/
├── hello_pdrv.c        # 平台设备驱动源码
├── hello-overlay.dts   # 设备树 overlay 源文件（参考）
├── Makefile            # 外部模块编译
├── build.sh            # 一键构建脚本
├── run_qemu.sh         # 启动 QEMU
└── 本文档.md
```

---

## 4. 驱动源码详解

### 4.1 平台设备驱动 — `hello_pdrv.c`

```c
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

/* 设备树匹配表 */
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
```

### 4.2 关键结构说明

| **元素** | **作用** |
| --- | --- |
| `of_device_id.compatible` | 与设备树节点的 `compatible` 字段匹配，匹配成功后内核调用 `probe` |
| `platform_driver.probe` | 设备与驱动匹配后的初始化入口 |
| `platform_driver.remove` | `rmmod` 卸载模块或设备解绑时的清理入口 |
| `module_platform_driver` | 宏展开为 `module_init` / `module_exit`，自动注册/注销 platform driver |

---

## 5. Makefile

```makefile
KERNDIR ?= $(PWD)/../01_qemu_env_build/linux-6.1
ARCH    ?= arm
CROSS   ?= arm-linux-gnueabihf-

obj-m := hello_pdrv.o

all:
	$(MAKE) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) -C $(KERNDIR) M=$(PWD) modules

clean:
	$(MAKE) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) -C $(KERNDIR) M=$(PWD) clean
```

> **注意**：`KERNDIR` 默认指向 `../01_qemu_env_build/linux-6.1`，该内核树必须已完成 `zImage dtbs modules` 三个目标的编译（`03_build_kernel.sh` 会自动完成）。仅编译 `zImage dtbs` 会导致缺少 `Module.symvers` 和 `scripts/module.lds`，外部模块编译将失败。

---

## 6. 手动编译模块

> 如果使用 `build.sh` 一键构建，可跳过第 6–9 节。

```bash
cd 02_platform_driver
make
```

编译成功后产出 `hello_pdrv.ko`，确认架构：

```bash
file hello_pdrv.ko
# 预期: ELF 32-bit LSB relocatable, ARM, ...

modinfo hello_pdrv.ko
# 预期显示 license, author, description, vermagic 等信息
```

---

## 7. 修改设备树

为使 `probe` 被调用，需要在设备树中添加一个与 `compatible = "myvendor,hello-device"` 匹配的节点。

有两种方式可以实现，对比如下：

| | **Device Tree Overlay** | **直接修改主 DTB** |
| --- | --- | --- |
| **原理** | 编译为 `.dtbo`，运行时叠加到基础 DTB 上 | 反编译 DTB → 编辑 DTS → 重新编译 |
| **优点** | 不侵入原始 DTB；可热插拔；适合量产环境按需加载不同外设 | 简单直接；无需内核/bootloader 支持 overlay 机制 |
| **缺点** | 需要 bootloader（如 U-Boot）或内核 `configfs` 支持加载；QEMU 不支持 | 每次修改需重新编译 DTB 并重启；会改动原始文件 |
| **适用场景** | 真实硬件 + U-Boot `fdt apply`；内核 `configfs` 动态加载 | QEMU 开发调试；无 overlay 支持的环境 |

> 本项目使用 QEMU，不支持 overlay 动态加载，因此采用**直接修改主 DTB** 的方式（`build.sh` 已自动完成此步骤）。

### 7.1 手动修改 DTB

```bash
cd ../01_qemu_env_build/linux-6.1
DTC=scripts/dtc/dtc
DTB=arch/arm/boot/dts/imx6ul-14x14-evk.dtb

# 反编译现有 DTB
$DTC -I dtb -O dts -o /tmp/imx6ul.dts $DTB

# 在根节点 / { ... } 的末尾 }; 前追加以下内容：
#     hello_device {
#         compatible = "myvendor,hello-device";
#         status = "okay";
#     };

# 重新编译
$DTC -I dts -O dtb -o $DTB /tmp/imx6ul.dts
```

### 7.2 设备树 Overlay 源文件（参考）

`hello-overlay.dts` 仅作为参考保留，记录标准 overlay 写法：

```dts
/dts-v1/;
/plugin/;

&{/} {
    hello_device {
        compatible = "myvendor,hello-device";
        status = "okay";
    };
};
```

---

## 8. 打包进 rootfs

```bash
cd ../01_qemu_env_build/busybox-1.36.1/_install

# 创建模块存放目录
mkdir -p lib/modules

# 复制 .ko 文件
cp ../../02_platform_driver/hello_pdrv.ko lib/modules/

# 重新打包 initramfs
find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz
```

---

## 9. QEMU 内加载验证

### 9.1 启动 QEMU

```bash
bash run_qemu.sh
```

> rcS 启动脚本已自动挂载 `/proc` 和 `/sys`，无需手动挂载。

### 9.2 加载与卸载模块

```bash
# 加载模块
insmod /lib/modules/hello_pdrv.ko

# 观察 probe 调用
dmesg | grep hello_pdrv
# 预期: hello_pdrv hello_device: hello_pdrv: probe called!

# 卸载模块
rmmod hello_pdrv
dmesg | grep hello_pdrv
# 预期新增: hello_pdrv hello_device: hello_pdrv: remove called!
```

如果只看到模块加载但**没有** `probe called!`，说明设备树中缺少匹配节点，请确认第 7 步已完成。

### 9.3 查看 sysfs 信息

```bash
# 驱动注册信息
ls /sys/bus/platform/drivers/hello_pdrv/

# 设备绑定信息
ls /sys/bus/platform/devices/ | grep hello
```

---

## 10. 验证清单

- [ ] `make` 编译无 warning，产出 `hello_pdrv.ko`
- [ ] `file hello_pdrv.ko` 显示 **ARM ELF relocatable**
- [ ] `modinfo` 输出 license、author、vermagic 信息
- [ ] 设备树中存在 `compatible = "myvendor,hello-device"` 节点
- [ ] `insmod` 后 `dmesg` 显示 **probe called!**
- [ ] `rmmod` 后 `dmesg` 显示 **remove called!**
- [ ] `/sys/bus/platform/drivers/hello_pdrv/` 目录存在

---

## 11. 常见问题排查

| **现象** | **原因** | **解决方案** |
| --- | --- | --- |
| `insmod: invalid module format` | 模块与内核 vermagic 不匹配 | 确保 Makefile 中 `KERNDIR` 指向 QEMU 启动时使用的同一内核树 |
| `Unknown symbol` 错误 | 内核未开启 `CONFIG_MODULES` 或缺少符号导出 | 内核 `menuconfig` 中启用 `Enable loadable module support` |
| insmod 成功但无 probe 输出 | 设备树中无匹配的 compatible 节点 | 重新执行 `build.sh` 或按第 7 步手动修改 DTB，然后重启 QEMU |
| `can't insert module: File exists` | 模块已加载 | 先 `rmmod hello_pdrv` 再重新 `insmod` |
| 编译报 `No rule to make target` | `KERNDIR` 路径错误或内核树未编译 | 确认 `01_qemu_env_build/linux-6.1/` 存在且已执行过 `03_build_kernel.sh` |
| 编译报 `No rule to make target 'scripts/module.lds'` | 内核树未执行 `modules_prepare` | 在内核树中执行 `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules_prepare`，或直接重新运行 `build.sh`（会自动检测并补全） |
| modpost 报大量 `undefined!` 警告 | 内核树缺少 `Module.symvers`（仅编译了 `zImage dtbs`，未编译 `modules`） | 在内核树中执行 `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) modules`，或直接重新运行 `build.sh`（会自动检测并补全） |
| `loading out-of-tree module taints kernel` | 模块通过 `M=$(PWD)` 在内核树外部编译，内核设置 taint 标志 `O`（OOT_MODULE）标记已加载非内核树模块 | 正常提示，不影响功能。所有外部编译的 `.ko` 都会触发。如需消除，需将模块源码放入内核树并在树内编译（开发阶段无此必要） |

---

## 12. 下一步扩展方向

完成本最小验证后，可逐步增加能力：

1. **读取设备树属性** — 在 `probe` 中用 `of_property_read_string` / `of_property_read_u32` 解析自定义属性
2. **注册字符设备** — 在 `probe` 中调用 `cdev_add` + `device_create`，提供 `/dev/hello` 用户态接口
3. **接入真实硬件资源** — 使用 `platform_get_resource` 获取 MMIO / IRQ，操作寄存器
4. **对接子系统** — 将平台驱动桥接到 IIO / Input / LED 等 Linux 子系统
