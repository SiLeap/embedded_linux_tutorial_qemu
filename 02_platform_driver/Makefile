KERNDIR ?= $(PWD)/../01_qemu_env_build/linux-6.1
ARCH    ?= arm
CROSS   ?= arm-linux-gnueabihf-

obj-m := hello_pdrv.o

all:
	$(MAKE) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) -C $(KERNDIR) M=$(PWD) modules

clean:
	$(MAKE) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) -C $(KERNDIR) M=$(PWD) clean
