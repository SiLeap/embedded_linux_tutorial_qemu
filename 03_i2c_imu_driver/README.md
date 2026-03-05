# I2C IMU 驱动实战（IIO 子系统 + I2C 总线）

本文实现一个基于 IIO（Industrial I/O）子系统的 I2C IMU 驱动，演示如何：
- 使用 IIO 框架暴露加速度计数据
- 通过 I2C 总线与传感器通信
- 在 QEMU 环境中验证驱动功能

> **目标平台**：QEMU mcimx6ul-evk（i.MX6UL Cortex-A7）+ Linux 6.1
> **传感器**：fake_imu（模拟 I2C 地址 0x68 的 3 轴加速度计）

---

## 1. 前置条件

确保以下环境已就绪（参考 `01_qemu_env_build/` 下的构建脚本）：

- [ ] 交叉编译器 `arm-linux-gnueabihf-gcc` 可用
- [ ] 已编译 Linux 6.1 内核源码，且包含 `modules` 目标（位于 `01_qemu_env_build/linux-6.1/`）
- [ ] 内核配置启用 IIO 子系统（`CONFIG_IIO=y`）
- [ ] QEMU mcimx6ul-evk 能正常启动 BusyBox rootfs（`01_qemu_env_build/05_run_qemu.sh`）

---

## 2. 快速开始

本目录已包含全部源码和自动化脚本，可直接执行：

```bash
cd 03_i2c_imu_driver

# 一键完成：编译模块 → 合并设备树 → 打包 rootfs
bash build.sh

# 启动 QEMU
bash run_qemu.sh
```

QEMU 启动后，在串口终端中验证：

```bash
insmod /lib/modules/fake_imu.ko
dmesg | grep fake_imu
# 预期: fake_imu 0-0068: probe OK, addr=0x68

cat /sys/bus/iio/devices/iio:device0/in_accel_z_raw
# 预期: 1000

rmmod fake_imu
dmesg | grep fake_imu
# 预期: fake_imu 0-0068: remove called
```

> 退出 QEMU：`Ctrl+A` 然后 `X`

如需了解每一步的原理，请继续阅读下文。

---

## 3. 目录结构

```
03_i2c_imu_driver/
├── fake_imu.c              # I2C IIO 驱动源码（110 行）
├── Makefile                # 外部模块编译配置
├── fake-imu-overlay.dts    # 设备树 overlay 源文件（参考，QEMU 不支持运行时加载）
├── build.sh                # 一键构建脚本（编译 + DTB 合并 + rootfs 打包）
├── run_qemu.sh             # 启动 QEMU（使用合并后的 DTB）
├── verify_imu.sh           # 自动化验证脚本
└── README.md               # 本文档
```

---

## 4. 驱动源码详解

### 4.1 核心数据结构

```c
struct fake_imu_data {
    struct i2c_client *client;
};
```

驱动私有数据结构，保存 I2C 客户端指针。通过 `iio_priv()` 从 IIO 设备中获取。

### 4.2 IIO 通道定义

```c
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
```

**关键字段说明：**
- `type = IIO_ACCEL`：通道类型为加速度计
- `modified = 1`：使用 `channel2` 字段指定轴向
- `channel2 = IIO_MOD_X/Y/Z`：X/Y/Z 轴标识
- `info_mask_separate`：每个通道独立的属性（raw 原始值）
- `info_mask_shared_by_type`：同类型通道共享的属性（scale 缩放因子）

这些定义会自动生成 sysfs 属性：
- `in_accel_x_raw`、`in_accel_y_raw`、`in_accel_z_raw`
- `in_accel_scale`（三个通道共享）

### 4.3 read_raw 回调

```c
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
```

**返回值说明：**

| Mask | 通道 | 返回值 | 含义 |
|------|------|--------|------|
| RAW | X | 0 | X 轴无加速度 |
| RAW | Y | 0 | Y 轴无加速度 |
| RAW | Z | 1000 | Z 轴 1g（重力加速度） |
| SCALE | 全部 | 0.009806 | 缩放因子（m/s² per LSB） |

实际加速度 = raw × scale = 1000 × 0.009806 = 9.806 m/s²（标准重力加速度）

### 4.4 probe/remove 流程

```c
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
```

**关键步骤：**
1. `devm_iio_device_alloc`：分配 IIO 设备 + 私有数据，自动管理内存
2. `iio_priv`：获取私有数据指针
3. 配置 IIO 设备属性（name、info、channels）
4. `devm_iio_device_register`：注册 IIO 设备，自动创建 sysfs 接口

**remove 函数：**
```c
static void fake_imu_remove(struct i2c_client *client)
{
    dev_info(&client->dev, "remove called\n");
}
```

由于使用 `devm_*` 系列函数，无需手动清理资源，remove 函数仅打印日志。

---

## 5. IIO 子系统关键概念

### 5.1 设备类型对比

| 方面 | 字符设备 | 平台设备 | IIO 设备 |
|------|----------|----------|----------|
| 用户接口 | /dev/xxx | sysfs only | /sys/bus/iio/devices/ |
| 数据访问 | read/write/ioctl | N/A | sysfs 属性 |
| 适用场景 | 通用设备 | 内存映射外设 | 传感器/ADC/DAC |
| 内核框架 | 手动管理 | Platform Bus | IIO 子系统 |

### 5.2 sysfs 接口结构

```
/sys/bus/iio/devices/iio:device0/
├── name                    # "fake_imu"
├── in_accel_x_raw          # X 轴原始值
├── in_accel_y_raw          # Y 轴原始值
├── in_accel_z_raw          # Z 轴原始值
└── in_accel_scale          # 缩放因子
```

用户空间通过读取这些文件获取传感器数据，无需编写 ioctl 或字符设备接口。

---

## 6. 设备树集成

### 6.1 设备节点结构

驱动需要在设备树中添加 I2C 设备节点：

```dts
&i2c1 {
    fake_imu@68 {
        compatible = "myvendor,fake-imu";
        reg = <0x68>;
        status = "okay";
    };
};
```

**字段说明：**
- `@68`：I2C 设备地址（7 位地址）
- `compatible`：必须与驱动的 `of_device_id` 匹配
- `reg`：I2C 地址寄存器
- `status`：设备状态（okay 表示启用）

### 6.2 compatible 字符串匹配

驱动中的匹配表：

```c
static const struct of_device_id fake_imu_of_match[] = {
    { .compatible = "myvendor,fake-imu" },
    { }
};
MODULE_DEVICE_TABLE(of, fake_imu_of_match);
```

内核通过 `compatible` 字符串将设备树节点与驱动绑定。

### 6.3 QEMU 环境的特殊处理

QEMU 不支持运行时加载设备树 overlay（.dtbo），因此 `build.sh` 采用以下方案：

1. 提取基础 DTB：`dtc -I dtb -O dts imx6ul-14x14-evk.dtb`
2. 使用 Python 脚本注入 `fake_imu@68` 节点到 `i2c@21a0000`
3. 重新编译 DTB：`dtc -I dts -O dtb`
4. 将合并后的 DTB 传递给 QEMU

详细实现参考 `build.sh` 中的 DTB 处理逻辑。

---

## 7. Makefile 说明

```makefile
KERNELDIR ?= ../01_qemu_env_build/linux-6.1
ARCH ?= arm
CROSS_COMPILE ?= arm-linux-gnueabihf-

obj-m := fake_imu.o

all:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules

clean:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) clean
```

**关键变量：**
- `KERNELDIR`：内核源码路径
- `ARCH=arm`：目标架构
- `CROSS_COMPILE`：交叉编译工具链前缀
- `obj-m`：编译为外部模块（.ko）

---

## 8. 手动构建步骤（可选）

如需了解 `build.sh` 内部流程，可手动执行以下步骤：

### 8.1 编译内核模块

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- M=$(pwd) modules
# 产出: fake_imu.ko
```

### 8.2 合并设备树

```bash
# 提取基础 DTB
cd ../01_qemu_env_build
dtc -I dtb -O dts -o base.dts arch/arm/boot/dts/nxp/imx/imx6ul-14x14-evk.dtb

# 使用 Python 脚本注入 fake_imu 节点（参考 build.sh）
# 重新编译 DTB
dtc -I dts -O dtb -o imx6ul-14x14-evk-imu.dtb base.dts
```

### 8.3 打包到 rootfs

```bash
# 复制模块到 rootfs
mkdir -p rootfs/lib/modules
cp fake_imu.ko rootfs/lib/modules/
cp verify_imu.sh rootfs/lib/modules/

# 重新打包 cpio
cd rootfs
find . | cpio -o -H newc | gzip > ../rootfs.cpio.gz
```

---

## 9. QEMU 内验证

### 9.1 启动与加载

```bash
bash run_qemu.sh
# 等待启动完成，出现登录提示符

# 加载模块
insmod /lib/modules/fake_imu.ko

# 检查 dmesg
dmesg | tail
# 预期输出: fake_imu 0-0068: probe OK, addr=0x68
```

### 9.2 验证 IIO 设备

```bash
# 检查 IIO 设备列表
ls /sys/bus/iio/devices/
# 预期: iio:device0

# 查看设备名称
cat /sys/bus/iio/devices/iio:device0/name
# 预期: fake_imu
```

### 9.3 读取传感器数据

```bash
cd /sys/bus/iio/devices/iio:device0/

# 读取 X 轴原始值
cat in_accel_x_raw
# 预期: 0

# 读取 Y 轴原始值
cat in_accel_y_raw
# 预期: 0

# 读取 Z 轴原始值
cat in_accel_z_raw
# 预期: 1000

# 读取缩放因子
cat in_accel_scale
# 预期: 0.009806
```

**计算实际加速度：**
```
Z 轴加速度 = 1000 × 0.009806 = 9.806 m/s²（标准重力加速度）
```

### 9.4 自动化验证

```bash
sh /lib/modules/verify_imu.sh
```

该脚本会自动执行上述所有验证步骤并输出结果。

### 9.5 卸载模块

```bash
rmmod fake_imu
dmesg | tail
# 预期: fake_imu 0-0068: remove called
```

---

## 10. 验证清单

完成以下检查项以确保驱动正常工作：

- [ ] `make` 编译无 warning，产出 `fake_imu.ko`
- [ ] `file fake_imu.ko` 显示 ARM ELF relocatable
- [ ] `insmod` 后 dmesg 显示 "probe OK, addr=0x68"
- [ ] `/sys/bus/iio/devices/iio:device0` 目录存在
- [ ] `cat name` 输出 "fake_imu"
- [ ] `in_accel_z_raw` 返回 1000
- [ ] `in_accel_scale` 返回 0.009806
- [ ] `rmmod` 后 dmesg 显示 "remove called"

---

## 11. 常见问题排查

| 现象 | 原因 | 解决方案 |
|------|------|----------|
| insmod 成功但无 iio:device0 | probe 未被调用 | 检查 DTB 是否包含 fake_imu@68 节点，重新运行 build.sh |
| "No such device" on I2C | I2C 总线未启用 | 检查内核配置 CONFIG_I2C=y，确认 i2c1 节点 status="okay" |
| 设备编号不是 device0 | 系统中有其他 IIO 设备 | 用 `dmesg \| grep iio` 查看实际设备号 |
| Permission denied 读取 sysfs | 权限不足 | 使用 root 用户或 `chmod 644 /sys/bus/iio/devices/iio:device0/*` |
| Module taint warning | 外部模块标记 | 正常现象，不影响功能 |
| in_accel_z_raw 返回 0 | read_raw 逻辑错误 | 检查驱动代码 channel2 判断（应为 IIO_MOD_Z） |
| 编译报 "No such file" | KERNELDIR 路径错误 | 确认 ../01_qemu_env_build/linux-6.1 存在且已编译 |
| QEMU 启动 60s 延迟 | LCDIF 驱动问题 | 确认 run_qemu.sh 使用 `video=off` 内核参数 |

---

## 12. 迁移到真实硬件

将 fake_imu 改造为真实 IMU 驱动的步骤：

### 12.1 替换数据读取逻辑

**当前（fake）：**
```c
case IIO_CHAN_INFO_RAW:
    if (chan->channel2 == IIO_MOD_Z)
        *val = 1000;
    else
        *val = 0;
    return IIO_VAL_INT;
```

**真实硬件（以 MPU6050 为例）：**
```c
case IIO_CHAN_INFO_RAW:
    ret = i2c_smbus_read_word_data(data->client, MPU6050_REG_ACCEL_XOUT_H + chan->scan_index * 2);
    if (ret < 0)
        return ret;
    *val = (s16)be16_to_cpu(ret);
    return IIO_VAL_INT;
```

### 12.2 添加设备 ID 检测

在 probe 中读取 WHO_AM_I 寄存器验证设备：

```c
ret = i2c_smbus_read_byte_data(client, MPU6050_REG_WHO_AM_I);
if (ret < 0)
    return ret;
if (ret != MPU6050_DEVICE_ID) {
    dev_err(&client->dev, "Invalid device ID: 0x%02x\n", ret);
    return -ENODEV;
}
```

### 12.3 实现校准与偏移

添加 `IIO_CHAN_INFO_OFFSET` 和 `IIO_CHAN_INFO_CALIBBIAS` 支持：

```c
.info_mask_separate = BIT(IIO_CHAN_INFO_RAW) | BIT(IIO_CHAN_INFO_OFFSET),
```

### 12.4 中断支持（可选）

使用 `devm_request_threaded_irq()` 处理 data-ready 信号：

```c
ret = devm_request_threaded_irq(&client->dev, client->irq,
                                NULL, mpu6050_irq_handler,
                                IRQF_TRIGGER_RISING | IRQF_ONESHOT,
                                "mpu6050", indio_dev);
```

实现 IIO triggered buffer 以支持高速数据采集。

### 12.5 参考真实驱动

- `drivers/iio/imu/inv_mpu6050/` - MPU6050/6500 系列
- `drivers/iio/accel/mma8452.c` - Freescale 加速度计
- `drivers/iio/imu/bmi160/` - Bosch BMI160

---

## 13. 总结

本文实现了一个基于 IIO 子系统的 I2C IMU 驱动，涵盖：

- **IIO 框架**：通道定义、read_raw 回调、sysfs 接口
- **I2C 总线**：设备树绑定、I2C 客户端管理
- **QEMU 验证**：DTB 合并、模块加载、数据读取

通过本实战，你已掌握：
- IIO 子系统的基本使用方法
- I2C 驱动的标准开发流程
- QEMU 环境下的驱动调试技巧

**下一步建议：**
- 尝试修改返回值模拟不同的传感器数据
- 添加陀螺仪通道（`IIO_ANGL_VEL`）
- 参考真实驱动实现 I2C 寄存器读写
- 在真实硬件上测试（如树莓派 + MPU6050）

