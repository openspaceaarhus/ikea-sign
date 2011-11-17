CFLAGS=-Wall -O2

# For absolute mode
COD=-DCOD=1

TARGETS=\
	idh-firmware-16f690.hex \
	idh-firmware-16f684.hex \
	idh-serial

ASMSRC=idh-firmware.asm

all: $(TARGETS)

idh-firmware-16f684.hex: $(ASMSRC)
	gpasm $(COD) -p16f684 -o $@ $<

idh-firmware-16f690.hex: $(ASMSRC)
	gpasm $(COD) -p16f690 -o $@ $<

#.o.hex:
#	gplink -m -o $@ $<
#
#.asm.o:
#	gpasm -c -o $@ $<


idh-serial: idh-serial.c


clean:
	$(RM) $(TARGETS) $(TARGETS:.hex=.lst) $(TARGETS:.hex=.cod)
