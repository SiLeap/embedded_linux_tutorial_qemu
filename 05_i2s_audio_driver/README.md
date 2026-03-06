# I2S Audio 驱动实战（ASoC 子系统 + I2C Codec）

基于 ASoC 框架实现 I2S 音频驱动，演示 Codec/Platform/Machine 三层架构。

## 学习目标

- 理解 ASoC 三层架构及各层职责
- 掌握 I2C 音频 Codec 驱动开发
- 学习 SAI2 接口配置与 DAI link 绑定
- 实践设备树中音频设备的配置方法

**目标平台**: QEMU mcimx6ul-evk + Linux 6.1
**硬件**: fake_codec (模拟 I2C 地址 0x1a 的音频编解码器)

## 前置条件

- [ ] 交叉编译器 arm-linux-gnueabihf-gcc 可用
- [ ] Linux 6.1 内核已编译，包含 ASoC 支持 (CONFIG_SND_SOC=y)
- [ ] QEMU mcimx6ul-evk 能正常启动
- [ ] Python 3 可用（用于 DTB 修改脚本）

## 快速开始

```bash
cd 05_i2s_audio_driver
bash build.sh      # 编译模块 + DTB 注入 + rootfs 打包
bash run_qemu.sh   # 启动 QEMU
```

QEMU 内验证:

```bash
sh /lib/modules/verify_audio.sh
# 或手动验证:
insmod /lib/modules/fake_codec.ko
insmod /lib/modules/fake_platform.ko
insmod /lib/modules/fake_audio_card.ko
cat /proc/asound/cards
cat /proc/asound/pcm
```

退出 QEMU: `Ctrl+A` 然后按 `X`

## 目录结构

```
05_i2s_audio_driver/
├── fake_codec.c           # I2C ASoC Codec 驱动
├── fake_platform.c        # ASoC Platform 驱动（hrtimer DMA 模拟）
├── fake_audio_card.c      # ASoC Machine 驱动
├── Makefile               # 外部模块编译配置
├── overlay.dts            # 设备树 overlay（参考）
├── build.sh               # 一键构建脚本
├── run_qemu.sh            # 启动 QEMU
├── verify_audio.sh        # 手动验证脚本
├── auto_verify.sh         # 自动化验证脚本（Expect）
├── auto_verify.py         # 自动化验证脚本（Python pexpect）
└── README.md              # 本文档
```

## ASoC 三层架构

### 架构概览

```
┌─────────────────────────────────────┐
│   User Space (ALSA API)             │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│   ASoC Core (snd_soc_card)          │
└─────────────────────────────────────┘
       ↓          ↓          ↓
┌──────────┐ ┌──────────┐ ┌──────────┐
│ Machine  │ │ Platform │ │  Codec   │
│  Layer   │ │  Layer   │ │  Layer   │
└──────────┘ └──────────┘ └──────────┘
     ↓            ↓            ↓
  DAI Link     DMA/PCM      I2C Bus
(fake_audio) (fake_platform) (fake_codec)
```

### 三层职责

**Codec Layer (fake_codec.c)**
- 管理音频编解码器硬件（本例为 I2C 设备）
- 实现 `snd_soc_component_driver` 和 `snd_soc_dai_driver`
- 提供 DAI 操作回调：`hw_params`, `set_fmt`
- 定义支持的音频格式、采样率、通道数

**Platform Layer (fake_platform.c)**
- 管理 DMA 缓冲区和 PCM 操作
- 使用 hrtimer 模拟 DMA period elapsed 中断
- 实现 `snd_pcm_ops`：open/close/hw_params/trigger/pointer
- 提供 VMALLOC 类型的音频缓冲区（QEMU 无真实 DMA）

**Machine Layer (fake_audio_card.c)**
- 连接 Codec 和 Platform
- 定义 DAI link 配置（I2S 格式、时钟主从）
- 通过设备树解析 `audio-cpu`、`audio-codec` 和 `audio-platform` phandle
- 注册 `snd_soc_card` 到 ASoC 核心

## 驱动源码详解

### Codec 驱动 (fake_codec.c)

**DAI 驱动定义:**
```c
static struct snd_soc_dai_driver fake_codec_dai = {
    .name = "fake-codec-dai",
    .playback = {
        .channels_min = 1,
        .channels_max = 2,
        .rates = SNDRV_PCM_RATE_8000_48000,
        .formats = SNDRV_PCM_FMTBIT_S16_LE | SNDRV_PCM_FMTBIT_S24_LE,
    },
    .capture = { /* 同上 */ },
    .ops = &fake_codec_dai_ops,
};
```

**I2C 探测流程:**
1. `devm_kzalloc` 分配私有数据
2. `devm_snd_soc_register_component` 注册 component + DAI
3. 内核自动创建 `/sys/devices/.../fake-codec/` 目录

### Machine 驱动 (fake_audio_card.c)

**DAI Link 配置:**
```c
.dai_fmt = SND_SOC_DAIFMT_I2S |      // I2S 格式
           SND_SOC_DAIFMT_NB_NF |    // 正常位时钟/帧时钟
           SND_SOC_DAIFMT_CBS_CFS,   // Codec 为 Slave
```

**Probe 流程:**
1. 解析设备树 `audio-cpu` phandle → SAI2 节点
2. 解析 `audio-codec` phandle → fake_codec 节点
3. 配置 DAI link 的 cpus/codecs/platforms
4. 设置 `codec_dai_name = "fake-codec-dai"`（必须与 codec 驱动匹配）
5. `devm_snd_soc_register_card` 注册声卡

## 设备树集成

需要添加三个节点:

**1. I2C Codec 设备:**
```dts
&i2c1 {
    fake_codec: fake_codec@1a {
        compatible = "myvendor,fake-codec";
        reg = <0x1a>;
        status = "okay";
    };
};
```

**2. Machine 设备 (根节点):**
```dts
/ {
    fake-audio-card {
        compatible = "myvendor,fake-audio-card";
        audio-cpu = <&sai2>;
        audio-codec = <&fake_codec>;
        status = "okay";
    };
};
```

**DTB 修改方案:**

由于 QEMU 不支持 .dtbo 运行时加载，`build.sh` 使用 Python 脚本:
1. `dtc -I dtb -O dts` 反编译基础 DTB
2. Python 脚本注入节点到 i2c@21a0000 和根节点
3. `dtc -I dts -O dtb` 重新编译
4. 输出 `imx6ul-14x14-evk-audio.dtb`

## Makefile 说明

```makefile
KERNELDIR ?= ../01_qemu_env_build/linux-6.1
obj-m := fake_codec.o fake_audio_card.o
```

编译产出: `fake_codec.ko`, `fake_audio_card.ko`

## QEMU 内验证

参考 Notion 教程 §9

### 加载模块

```bash
insmod /lib/modules/fake_codec.ko
insmod /lib/modules/fake_audio_card.ko
```

### 检查 dmesg

```bash
dmesg | grep -E "fake_codec|fake.*audio"
```

预期输出:
```
fake_codec 0-001a: fake_codec I2C probe OK, addr=0x1a
fake-audio-card fake-audio-card: Fake-Audio-Card registered OK
```

### 验证 ALSA 声卡

```bash
cat /proc/asound/cards
```

预期输出:
```
 0 [FakeAudioCard ]: FakeAudioCard - FakeAudioCard
                      FakeAudioCard
```

### 验证 PCM 设备

```bash
cat /proc/asound/pcm
```

预期输出:
```
00-00: Fake-Audio-HiFi fake-codec-dai-0 : : playback 1 : capture 1
```

### 卸载模块

```bash
rmmod fake_audio_card
rmmod fake_codec
```

## 验证清单

参考 Notion 教程 §9

- [ ] `make` 编译无 warning，产出两个 .ko 文件
- [ ] `insmod fake_codec.ko` 后 dmesg 显示 "probe OK, addr=0x1a"
- [ ] `insmod fake_audio_card.ko` 后 dmesg 显示 "registered OK"
- [ ] `/proc/asound/cards` 显示 FakeAudioCard
- [ ] `/proc/asound/pcm` 显示 Fake-Audio-HiFi 设备
- [ ] 卸载顺序正确（先 machine 后 codec）
- [ ] `rmmod` 后 dmesg 显示 remove 日志

## 常见问题排查

参考 Notion 教程 §10

| 现象 | 原因 | 解决方案 |
|------|------|----------|
| insmod fake_audio_card 失败 "No such device" | Codec 未加载或 DTB 缺少节点 | 先加载 fake_codec.ko，检查 dmesg |
| /proc/asound/cards 为空 | Machine 驱动 probe 失败 | `dmesg \| grep fake` 查看错误 |
| "asoc-audio-graph-card" 相关错误 | DAI link 配置错误 | 确认 codec_dai_name 设置正确 |
| "Failed to parse audio-cpu phandle" | DTB 中缺少 sai2 标签 | 检查 build.sh 是否成功添加标签 |
| rmmod 时 "Device or resource busy" | 声卡正在使用 | 先卸载 machine 驱动 |
| Python 脚本报错 | DTB 路径不正确 | 检查 BASE_DTB 变量 |
| QEMU 启动 60s 延迟 | LCDIF 驱动问题 | 确认使用 `video=off` 内核参数 |

## 迁移到真实硬件

参考 Notion 教程 §11

### 替换为真实 Codec (以 WM8960 为例)

**1. 修改 compatible 字符串:**
```c
// fake_codec.c
{ .compatible = "wlf,wm8960" }
```

**2. 添加寄存器映射:**
```c
static const struct regmap_config wm8960_regmap = {
    .reg_bits = 7,
    .val_bits = 9,
    .max_register = WM8960_CACHEREGNUM,
};

// In probe:
priv->regmap = devm_regmap_init_i2c(client, &wm8960_regmap);
```

**3. 实现真实的 hw_params:**
```c
static int wm8960_hw_params(...) {
    // 配置 PLL、采样率寄存器、MCLK/BCLK 分频
    regmap_update_bits(priv->regmap, WM8960_IFACE1, ...);
    return 0;
}
```

**4. 添加音量控制:**
```c
static const struct snd_kcontrol_new wm8960_controls[] = {
    SOC_DOUBLE_R("Headphone Playback Volume", WM8960_LOUT1, WM8960_ROUT2, 0, 127, 0),
};
```

**5. 设备树修改:**
```dts
&i2c1 {
    wm8960: wm8960@1a {
        compatible = "wlf,wm8960";
        reg = <0x1a>;
        clocks = <&clks IMX6UL_CLK_SAI2>;
        clock-names = "mclk";
    };
};
```

**参考真实驱动:**
- `sound/soc/codecs/wm8960.c` - Wolfson WM8960
- `sound/soc/fsl/imx-wm8960.c` - i.MX + WM8960 machine 驱动

## 总结

本实战实现了基于 ASoC 框架的 I2S 音频驱动，涵盖:

- ASoC 三层架构的职责与交互
- I2C Codec 驱动的标准开发流程
- 设备树中音频设备的配置方法
- QEMU 环境下的音频驱动调试技巧

**下一步建议:**
- 尝试修改 DAI 格式（Left-Justified/DSP Mode A）
- 添加音量控制 kcontrol
- 在真实硬件上测试（如 i.MX6UL EVK + WM8960）
