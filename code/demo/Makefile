.PHONY: all clean
ALL = demo

CROSS = arm-stm32f4-eabi-
CC = $(CROSS)gcc
AS = $(CROSS)as
CFLAGS = -g
LDSCRIPT = stm32f407.ld
STARTUP = startup_stm32f4xx.o system_stm32f4xx.o
LDFLAGS = -nostartfiles -lstm32f4util -lstm32f4usbdevice -lstm32f4usbotg -lstm32f4usbhid -lstm32f4periph

OBJS = main.o selftest.o stm32f4xx_it.o usb_bsp.o usbd_desc.o usbd_usr.o
demo: $(OBJS) $(STARTUP)
	$(CC) $(CFLAGS) -T $(LDSCRIPT) -o $@ $^ $(LDFLAGS)

clean::
	$(RM) $(ALL) *\.o
