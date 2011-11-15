CFLAGS=-Wall -O2

COD=1

taget: idh-firmware.hex idh-serial

ifeq ($(COD),1)
idh-firmware.hex: idh-firmware.asm
	gpasm -DCOD=1 -o $@ $<
else
idh-firmware.hex: idh-firmware.o
	gplink -m -o $@ $<

idh-firmware.o: idh-firmware.asm
	gpasm -c -o $@ $<
endif

idh-serial: idh-serial.c
