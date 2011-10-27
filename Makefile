CC=sdcc

0026-pwm.hex: 0026-pwm.o
	gplink -m -s /usr/share/gputils/lkr/16f684.lkr -o $@ /usr/share/sdcc/lib/pic/pic16f684.lib /usr/share/sdcc/lib/pic/libsdcc.lib $<

0026-pwm.o: 0026-pwm.asm
	gpasm -c $<

0026-pwm.asm: 0026-pwm.c
	$(CC) --opt-code-speed -DKHZ=8000 -S -V -mpic14 -p16f684 -D__16f684 -DCONFIG_WORD=_INTRC_OSC_NOCLKOUT\\\&_WDT_OFF\\\&_CP_OFF\\\&_CPD_OFF\\\&_PWRTE_ON $<

program:
	sudo ../pk2cmd -PPIC16f684 -M -F0026-pwm.hex
	sudo ../pk2cmd -PPIC16f684 -T
