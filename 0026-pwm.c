#include "pic16f684.h"
#include "tsmtypes.h"

// Set the __CONFIG word:
// I usually set it to _EXTCLK_OSC&_WDT_OFF&_LVP_OFF&_DATA_CP_OFF&_PWRTE_ON
Uint16 __at 0x2007  __CONFIG = CONFIG_WORD;

static const Uint8 colorTabR[] = {1, 0, 0, 1, 1, 0};
static const Uint8 colorTabG[] = {0, 1, 0, 1, 0, 1};
static const Uint8 colorTabB[] = {0, 0, 1, 0, 1, 1};

#if 0
static Uint8 dir;

static void Intr(void) interrupt 0
{
	if(T0IF)	// Did we get a timer0 interrupt?
	{
		T0IF=0;

		if(dir)	// count up
		{
			CCPR1L++;
			if(CCPR1L == 0xff)
				dir=0;
		}
		else
		{
			CCPR1L--;
			if(CCPR1L == 0x00)
				dir=1;
		}
	}
}
#endif

void main(void)
{
	Uint8 poodle = 0, knap1_down = 0;
	Uint8 cycle_done = 1;
	Uint8 color = 0;
	Uint8 dirR = 0, dirG = 0, dirB = 0;
	Uint8 counter1, counter2;
	Uint8 counterR = 0, counterG = 0, counterB = 0;
	Uint8 colorI = 0;

        TRISA = 0xf8;	// Set PORTA as all inputs, except for RA0 - RA2

	while(1) {
		counterR += dirR;
		counterG += dirG;
		counterB += dirB;

		if(counterR > 245) {
			cycle_done = 1;
		}

		if(counterR > 150) {
			dirR = ~dirR;
			dirR++;
		}

		if(counterG > 245) {
			cycle_done = 1;
		}
		if(counterG > 150) {
			dirG = ~dirG;
			dirG++;
		}

		if(counterB > 245) {
			cycle_done = 1;
		}
		if(counterB > 150) {
			dirB = ~dirB;
			dirB++;
		}

		if(cycle_done) {
			if(poodle == 0) {
				dirR = colorTabR[colorI];
				dirG = colorTabG[colorI];
				dirB = colorTabB[colorI];
			}
			if(poodle == 1) {
				dirR = 0;
				dirG = 8;
				dirB = 0;
			}
			if(poodle == 2) {
				dirR = 8;
				dirG = 8;
				dirB = 0;
			}
			if(poodle == 3) {
				dirR = 8;
				dirG = 0;
				dirB = 0;
			}
			counterR = 0;
			counterG = 0;
			counterB = 0;
			cycle_done = 0;
			colorI++;
			if(colorI >= sizeof(colorTabR)) {
				colorI = 0;
			}
		}

#if 1
		if(!(PORTC & 0x20)) {
			knap1_down = 1;
		} else {
			if(knap1_down) {
				knap1_down = 0;
				poodle++;
				poodle &= 3;
				cycle_done = 1;
			}
		}

#endif

		for(counter1=0; counter1<10; counter1++) {
			for(counter2=0; counter2 < 255; counter2++) {
				if(counter2 < counterR)
					color |= 4;
				if(counter2 < counterG)
					color |= 1;
				if(counter2 < counterB)
					color |= 2;
				
				PORTA = color;
				/* It looks kind of stupid to set color to 0 here,
				   but makes sdcc generate better code */
				color = 0;
			}
		}
	}
}

