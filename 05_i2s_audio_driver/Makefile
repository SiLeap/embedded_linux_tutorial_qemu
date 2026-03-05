KERNDIR := $(shell pwd)/../01_qemu_env_build/linux-6.1
ARCH := arm
CROSS_COMPILE := arm-linux-gnueabihf-

obj-m := fake_codec.o fake_audio_card.o

all:
	$(MAKE) -C $(KERNDIR) M=$(shell pwd) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules

clean:
	$(MAKE) -C $(KERNDIR) M=$(shell pwd) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) clean
