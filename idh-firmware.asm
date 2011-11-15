; Ikea DIODER hack
; Copyright (C) 2011  B. Stultiens

; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
;
;---------------
; The Ikea DIODER gadget, with the color-control panel, has three high power
; outputs for RGB, three buttons (active low) and a potentiometer for analog
; input.
;
; PIC16F684 Pinout:
; Pin	Port	I/O	Name	ICSP		Description
;  1	Vdd	pwr	+5V	Vdd		Power supply
;  2	RA5	(I+pu)	(RX)	-		(RX emulated RS232)
;  3	RA4	I	S1	-		Switch 1, active low
;  4	RA3	I	S2	MCLR/Vpp	Switch 2, active low
;  5	RC5	I	S3	-		Switch 3, active low
;  6	RC4	(O)	(IND4)	-		(indicator 4)
;  7	RC3	AN7	WHEEL	-		1k potmeter 0..5V
;  8	RC2	(O)	(IND3)	-		(indicator 3)
;  9	RC1	(O)	(IND2)	-		(indicator 2)
; 10	RC0	(O)	(IND1)	-		(indicator 1)
; 11	RA2	O	RED	-		Red LEDs
; 12	RA1	O	BLUE	CLK		Blue LEDs
; 13	RA0	O	GREEN	DAT		Green LEDs
; 14	Vss	prw	GND	Vss		Ground
;
; Pins/values in () are normally unconnected/unused
;
; Modifications:
; * The RA5(RX) pin is normally unconnected, but has an emulated RS232
;   receiver, operating at 2400 Baud 8N1.
; * The IND[1..4] pins are normally unconnected, but are used as feedback
;   indicators (put some LEDs on them, please). IND[0..2] indicate the
;   running mode (binary encoded) and IND4 blinks on RS232 receive.
; * Use google (or hackaday) to find the programming pads on the PCB for
;   manual programming this gadget.
;
;
; Serial protocol
;----------------
; A two-byte sequence is used for each command, where the first byte has the
; highest bit set and the second byte has the highest bit cleared.
;
;  cmd  Byte 0   Byte 1
;   1  10000--- 0-------	Nop
;   2  11000000 0-hsvrgb	Swap active and shadow values
;   3  11000001 0DMd-mmm	Set running mode/direction
;   4  1100001d 0ddddddd	Set running delay/speed
;   5  110001-- 0-------	Nop
;   6  1a001--r 0rrrrrrr	Set Red
;   7  1a010--g 0ggggggg	Set Green
;   8  1a011--b 0bbbbbbb	Set Blue
;   9  1a10hhhh 0hhhhhhh	Set Hue
;  10  1a110--s 0sssssss	Set Saturation
;  11  1a111--v 0vvvvvvv	Set Value
;
; a = 1: activate immediately, 0: shadow store
; - = don't care, must be set to zero
; M = 1: set mode, 0: ignore mode
; D = 1: set direction, 0: ignore direction
;
; Swap active/shadow should employ either HSV or RGB values. Using both
; gives undefined results. Each '1' bit in the data-byte swaps the
; corresponding values.
;
; The host should send a CMD-byte followed by one or more DATA-byte(s). Each
; command is executed at the reception of the data byte. If multiple data
; bytes are sent, then the previous command remains in place and is used.
; The ommision of the command byte reduces the communication overhead
; for fast changing data.
; Note: multiple data bytes are /only/ useful if the initial command byte has
; the "activate immediately" bit set.
;
;
; Running modes
; -------------
; Button S2 advances the running mode (cyclic) from the following list.
; The mode-settings can be changed with the wheel while holding down
; indicated buttons.
; - off		All LEDs are off
; - rampage	LEDs cycle through rainbow colors at full strength
;			* S3	set speed
;			* S1	reverse direction
; - step	A fixed set of colors is displayed sequentially
;			* S3	set speed
;			* S1	reverse direction
; - random	A pseudo random set of colors is displayed
;			* S3	set speed
; - wheel	LEDs cycle through the HSV cone, the buttons S1 and S3 are used
;		to select the color with the wheel:
;			* S3	set speed
;			* S3+S1	set value
;			*    S1	set saturation
;			* direction depends on previous setting
; - fixed	A fixed color is selected, the buttons S1 and S3 are used
;		to select the color with the wheel:
;			* S3	set hue
;			* S3+S1	set value
;			*    S1	set saturation
; - serial	Only serial input changes the colors
; 
;
;------------------------------------------------------------------------------
; Source code configuration defines
; =================================
;
; We need to use absolute assembly to support the jump-tables
; The COD is normally set from the assembler call:
; $ gpasm -DCOD=1 ...
;COD		equ	1	; Absolute assemble mode
;
;------------------------------------------------------------------------------
; Test for jump-table misalignments
; The following define, if set, disables nop insertions which align
; jump-tables. If unset, misalignments will create runtime problems.
; The test *only* works in absolute assembly mode.
;TEST_ALIGNMENT	equ	1
;
; If you get errors, check the list-file and see which jump-table is
; out of alignment and fix it by inserting code like:
;IFNDEF TEST_ALIGNMENT	; {
;		nop		; Alignment for the xyz jump-table
;		nop
;		nop
;ENDIF		; }
;
IFDEF TEST_ALIGNMENT	; {
IFNDEF COD		; {
 ERROR "Testing alignment only works in absolute assembly mode"
ENDIF			; }
ENDIF			; }

;------------------------------------------------------------------------------
; Fake any writes to the eeprom is defined
; (FIXME: must be set until the eeprom code is fixed)
FAKEEEPROM	equ	1	; Fake the eeprom
;
;------------------------------------------------------------------------------
;
	list		p=16f684
	;list		p=16f690
	errorlevel	1
	radix		dec

IFDEF __16F684	; {
	include		"p16f684.inc"
	__CONFIG _FCMEN_OFF & _IESO_OFF & _BOD_OFF & _CPD_OFF & _CP_OFF & _MCLRE_OFF & _PWRTE_OFF & _WDT_OFF & _INTRC_OSC_NOCLKOUT & _INTOSCIO
ELSE		; }{
IFDEF __16F690	; {
	include		"p16f690.inc"
	__CONFIG _FCMEN_OFF & _IESO_OFF & _BOR_OFF & _CPD_OFF & _CP_OFF & _MCLRE_OFF & _PWRTE_OFF & _WDT_OFF & _INTRC_OSC_NOCLKOUT & _INTOSCIO
ELSE		; }{
 ERROR "No supported processor type selected"
ENDIF		; }
ENDIF		; }

BITRED		equ	2	; PORTA high-power outputs
BITBLUE		equ	1
BITGREEN	equ	0

BITRX		equ	5	; PORTA position of RS232 receiver input

BITS1		equ	4	; Input switches (S1, S2 on PORTA, S3 on PORTC)
BITS2		equ	3
BITS3		equ	5

BITIND1		equ	0	; Indicator outputs on PORTC
BITIND2		equ	1
BITIND3		equ	2
BITIND4		equ	4

; Flag bits
BIT_S1		equ	BITS1
BIT_S2		equ	BITS2
BIT_S3		equ	BITS3
BIT_RXREADY	equ	6	; Serial data available
BIT_DIR		equ	7	; Direction flag bit

; Serial data mode flags
BIT_RUN_ENABLE	equ	5	; Set mode/direction enable bits
BIT_DIR_ENABLE	equ	6

; Button mappings
; - wheel: SPEED and SAT must be on different buttons
; - fixed: HUE and SAT must be on different buttons
BIT_SET_SPEED	equ	BIT_S3
BIT_SET_DIR	equ	BIT_S1
BIT_SET_HUE	equ	BIT_S3
BIT_SET_SAT	equ	BIT_S1
; BIT_SET_VAL	-> combination of BIT_SET_HUE and BIT_SET_SAT
BIT_SET_MODE	equ	BIT_S2

RAM_B0_START	equ	0x0020
RAM_B0_LAST	equ	0x007F
RAM_B0_SIZE	equ	(RAM_B0_LAST - RAM_B0_START + 1)

; The following is in the shared space for the interrupt service routine
IFDEF COD	; {
		org	0x0070
ELSE		; }{
sharebank	udata_ovr	0x0070
ENDIF		; }
ovr_data_start
isr_ssave	res	1	; ISR: Status reg save
isr_wsave	res	1	; ISR: W reg save
isr_tmp		res	1	; ISR: temp variable
_pwm_r		res	1	; PWM counter red channel
_pwm_g		res	1	; PWM counter green channel
_pwm_b		res	1	; PWM counter blue channel
_bit_r		res	1	; Red channel
_bit_g		res	1	; Green channel
_bit_b		res	1	; Blue channel
_rxd		res	1	; Received serial data
_rxreg		res	1	; Serial data shift register
_bitrxcnt	res	1	; Serial data bit counter
_flags		res	1	; Flags from the ISR to main to indicate input
_dbs1		res	1	; Debounce counter S1
_dbs2		res	1	; Debounce counter S2
_dbs3		res	1	; Debounce counter S3
ovr_data_end
IF (ovr_data_end - ovr_data_start) > 16	; {
 ERROR "Shared data size overflow"
ENDIF		; }

; Running variables
IFDEF COD	; {
		org	0x0020
ELSE		; }{
databank	udata		0x0020
ENDIF		; }
hue_lo		res	1	; HSV colorspace
hue_hi		res	1
value		res	1
saturation	res	1
frac_lo		res	1	; fraction helper for HSV
frac_hi		res	1
mul_lo		res	1	; Multiply 16 bit source
mul_hi		res	1
mul_tmp		res	1	; Multiply 8 bit source
res_lo		res	1	; Multiply 16 bit result
res_hi		res	1

adc_lo		res	1	; Read A/D converter channel 7 value
adc_hi		res	1

runmode		res	1	; Which running show to do
speed		res	1	; Speed of change
buttonstate	res	1	; complement of the S[1..3] _flags indicators

rampage_state	res	1	; Rampage mode state

step_state	res	1	; Which color to display

TMR1_DIVISOR	equ	70	; Timer1 divisor for step and random display
tmr1div		res	1	; Counter to speed down timer1

rand_0		res	1	; Random number generator values
rand_1		res	1
rand_2		res	1
rand_3		res	1

shdw_red	res	1	; Shadow values for RGB and HSV
shdw_green	res	1	; These will be activated on serial command
shdw_blue	res	1
shdw_hue_lo	res	1
shdw_hue_hi	res	1
shdw_value	res	1
shdw_saturation	res	1

rxcmd		res	1	; Received serial command and data
rxdata		res	1

; Running modes
MODE_OFF	equ	0
MODE_RAMPAGE	equ	1
MODE_STEP	equ	2
MODE_RANDOM	equ	3
MODE_WHEEL	equ	4
MODE_FIXED	equ	5
MODE_SERIAL	equ	6
MODE_7		equ	7
MODE_MASK	equ	0x07

; EEPROM layout:
eeprom_startup_mode	equ	0x00
eeprom_rampage_speed	equ	0x01
eeprom_rampage_dir	equ	0x02
eeprom_step_speed	equ	0x03
eeprom_step_dir		equ	0x04
eeprom_random_speed	equ	0x05
eeprom_wheel_speed	equ	0x06
eeprom_wheel_dir	equ	0x07
eeprom_wheel_value	equ	0x08
eeprom_wheel_saturation	equ	0x09
eeprom_fixed_hue_lo	equ	0x0a
eeprom_fixed_hue_hi	equ	0x0b
eeprom_fixed_value	equ	0x0c
eeprom_fixed_saturation	equ	0x0d

;
; The fastest possible is 2400 Baud. Any faster will skew the bit sampling
; too much and we miss the data.
FIRST_BIT_TIME	equ	(-57)	; 1.1 bit delay at 2400 Baud
NEXT_BIT_TIME	equ	(-52)	; 1.0 bit delay at 2400 Baud

SEXTSIZE	equ	((1 << 8) + 1)
SEXT0		equ	(0 * SEXTSIZE)
SEXT1		equ	(1 * SEXTSIZE)
SEXT2		equ	(2 * SEXTSIZE)
SEXT3		equ	(3 * SEXTSIZE)
SEXT4		equ	(4 * SEXTSIZE)
SEXT5		equ	(5 * SEXTSIZE)
MAX_HUE		equ	(6 * SEXTSIZE - 1)
MAX_VALUE	equ	255
MAX_SATURATION	equ	255

;
; Code origin
;
IFNDEF COD	; {
code_ikeavars	code
ENDIF		; }
		org	0x00
		goto	_main
		nop
		nop
		nop

;
;------------------------------------------------------------------------------
; Interrupt service routine
; The isr should run in less than 156 clocks or timer2 will fire again
;------------------------------------------------------------------------------
;
		org	0x04
_isr
		movwf	isr_wsave
		swapf	STATUS, w
		movwf	isr_ssave

;----- Timer2 handling -----

		banksel	PIR1
		btfss	PIR1, TMR2IF		; TMR2IF
		goto	no_tmr2
		bcf	PIR1, TMR2IF		; Clear TMR2IF

		clrf	isr_tmp
		incf	_pwm_r, f		; Round-robin PWM counter
		incf	_pwm_g, f		; Round-robin PWM counter
		incf	_pwm_b, f		; Round-robin PWM counter

		; if(bit_r > pwm) RA2 = 1
		movf	_bit_r, w
		addwf	_pwm_r, w
		btfsc	STATUS, C
		bsf	isr_tmp, BITRED
		; if(bit_g > pwm) RA1 = 1
		movf	_bit_g, w
		addwf	_pwm_g, w
		btfsc	STATUS, C
		bsf	isr_tmp, BITGREEN
		; if(bit_b > pwm) RA0 = 1
		movf	_bit_b, w
		addwf	_pwm_b, w
		btfsc	STATUS, C
		bsf	isr_tmp, BITBLUE

		movf	isr_tmp, w		; Set the LED outputs simultaneously
		movwf	PORTA

		; Check the serial input
		movf	_bitrxcnt, w		; Only check if not currently receiving
		btfss	STATUS, Z
		goto	no_startbit

		btfsc	PORTA, BITRX		; Check if a start-bit is detected on RA5
		goto	no_startbit

		movlw	FIRST_BIT_TIME		; Set Timer0 to fire at middle of first serial bit
		movwf	TMR0
		bcf	INTCON, T0IF		; Clear TMR0IF
		bsf	INTCON, T0IE		; Enable Timer0 interrupt
		movlw	9
		movwf	_bitrxcnt
		bsf	PORTC, BITIND4		; Set the receive indicator

no_startbit
		; Check the buttons and debounce
		; if(~button ^ flag == 0)
		;	dbcnt = 0;
		; if(!--dbcnt)
		;	flag = ~button;
		comf	PORTA, w
		xorwf	_flags, w
		andlw	(1 << BITS1)	; if((~PORTA ^ _flags) & (1 << BITS1) == 0)
		btfsc	STATUS, Z
		clrf	_dbs1		;	_dbs1 = 0
		decf	_dbs1, f	; if(!--_dbs1)
		btfss	STATUS, Z
		goto	no_change_s1	; false-clause -> skip to next button
		bsf	_flags, BIT_S1	; true-clause -> reversed flag: buttons active low
		btfsc	PORTA, BITS1
		bcf	_flags, BIT_S1
no_change_s1
		comf	PORTA, w
		xorwf	_flags, w
		andlw	(1 << BIT_S2)
		btfsc	STATUS, Z
		clrf	_dbs2
		decf	_dbs2, f
		btfss	STATUS, Z
		goto	no_change_s2
		bsf	_flags, BIT_S2
		btfsc	PORTA, BITS2
		bcf	_flags, BIT_S2
no_change_s2
		comf	PORTC, w
		xorwf	_flags, w
		andlw	(1 << BIT_S3)
		btfsc	STATUS, Z
		clrf	_dbs3
		decf	_dbs3, f
		btfss	STATUS, Z
		goto	no_change_s3
		bsf	_flags, BIT_S3
		btfsc	PORTC, BITS3
		bcf	_flags, BIT_S3
no_change_s3
no_tmr2

;----- Timer0 handling -----

		btfss	INTCON, T0IE		; Do we have timer0 enable?
		goto	no_tmr0
		btfss	INTCON, T0IF		; Do we have timer0 interrupt?
		goto	no_tmr0

		movlw	NEXT_BIT_TIME		; Set Timer0 to fire at next bit
		movwf	TMR0
		bcf	INTCON, T0IF		; Clear TMR0IF

		; if(_bitrxcnt > 1)
		;  read bit
		; else
		;  check stop bit
		movf	_bitrxcnt, w
		sublw	1			; 1 - _bitrxcnt
		btfsc	STATUS, C		; if(_bitrxcnt <= 1)
		goto	check_stopbit		; 	check stopbit

		bcf	STATUS, C		; Read the input state
		btfsc	PORTA, BITRX
		bsf	STATUS, C
		rrf	_rxreg, f		; and put the bit in receiver
		goto	next_bit

check_stopbit
		btfsc	PORTA, BITRX		; The stopbit must be '1'
		goto	next_bit
		; error, the stopbit is not '1'
		clrf	_bitrxcnt		; clear the counter
		bcf	INTCON, T0IE		; stop the timer
		; Now it will read a "start-bit" at next timer2 interrupt,
		; but we don't care and the errors will continue until
		; the line is idle for a longer period.
		bcf	PORTC, BITIND4		; Clear the receive indicator
		goto	done_tmr0
next_bit
		decf	_bitrxcnt, f		; Have all bits?
		btfss	STATUS, Z
		goto	done_tmr0		; no

bits_done
		bcf	INTCON, T0IE		; yes, clear timer0 interrupt enable
		movf	_rxreg, w		; Move data to received data
		btfss	_flags, BIT_RXREADY	; Don't overwrite existing data, just drop
		movwf	_rxd
		bsf	_flags, BIT_RXREADY	; Indicate data received

done_tmr0
no_tmr0
		swapf	isr_ssave, w
		movwf	STATUS
		swapf	isr_wsave, f
		swapf	isr_wsave, w
		retfie
;
;------------------------------------------------------------------------------
; Main entry point
;------------------------------------------------------------------------------
;
_main
		; Initialize registers
		clrf	STATUS			; Be sure to load BANK0

		movlw	0
		movwf	INTCON			; Disable all interrupts
		movwf	PORTA			; All LEDs off
		movwf	PORTC
IFDEF USEWDT	; {
		movlw	00010011b
		movwf	WDTCON		; Watchdog enable, period scale 1:16384 (~0.52 seconds)
		; Timer1 should fire at least ~3.8 times per second, which
		; kicks the dog in the main loop. If it hasn't, we'll be
		; in reset shortly thereafter.
		clrwdt
ENDIF	; }
		banksel	TRISA			; BANK1
		movlw	11111000b
		movwf	TRISA			; RA[012] output, RA[345] input
		movlw	11101000b
		movwf	TRISC			; RC[0124] output, RC[35] input
		movlw	0x02
		movwf	PIE1			; Enable Timer2 interrupts
		movlw	0x71
		movwf	OSCCON			; Internal 8MHz oscillator
		movlw	0x20
		movwf	WPUA			; RA5 week pull-up enable
		movlw	0x03
		movwf	OPTION_REG		; Enable RA pull-up, internal TMR0 clock, presclaler for TMR0, prescale 1:16
		movlw	0x00
		movwf	IOCA			; No interrupt-on-change
		movlw	0x20
		movwf	ADCON1			; ADC clock Fosc/32
		movlw	156
		movwf	PR2			; Timer2 period register 156 counts -> 12820.51/256 -> pwm:50.08Hz
IFDEF __16F690	; {
		banksel	ANSEL
ENDIF		; }
		movlw	0x80
		movwf	ANSEL			; RC3/AN7 analog input
IFDEF __16F690	; {
		movlw	0x00
		movwf	ANSELH			; None analog in the high bits
ENDIF		; }

		banksel	ADCON0			; BANK0
		movlw	0x9d
		movwf	ADCON0			; ADC right justify, Vdd ref, AN7 selected, ADC enable
		movlw	0x04
		movwf	T2CON			; Timer2 postscaler 1:1, Timer2 enable, Timer2 prescaler 1
		movlw	00110101b
		movwf	T1CON			; Timer1 enable, internal Fosc/4, prescale 1:8
		movlw	0x00
		movwf	TMR2			; Reset Timer2
		movwf	PIR1			; Clear all peripheral int flags

		; Setup memory
		; Clear BANK0 memory
		movlw	LOW(RAM_B0_START)
		movwf	FSR
		movlw	LOW(RAM_B0_SIZE)
clear_ram_b0
		clrf	INDF
		incf	FSR, f
		addlw	-1
		btfss	STATUS, Z
		goto	clear_ram_b0

		; Setup variables
		; Everything that should be zero is already set.
		;movlw	0x00
		;movwf	_pwm_r			; The PWM counters are time-shifted to distribute the on-current surge
		movlw	0x01
		movwf	_pwm_g
		movlw	0x02
		movwf	_pwm_b

		movlw	TMR1_DIVISOR		; Timer1 divisor at max
		movwf	tmr1div

		movlw	0xde			; Random generator init at 0xdeadbeef
		movwf	rand_3
		movlw	0xad
		movwf	rand_2
		movlw	0xbe
		movwf	rand_1
		movlw	0xef
		movwf	rand_0

		movlw	0xe0
		movwf	speed			; Fast start

		movlw	0xff			; Set the default color at startup
		movwf	value
		movwf	saturation
		movlw	LOW(MAX_HUE)
		movwf	hue_lo
		movlw	HIGH(MAX_HUE)
		movwf	hue_hi
		call	_hsv_to_rgb

		movlw	0xc0			; Enable global and peripheral interrupts
		iorwf	INTCON, f

		; continue into main loop

		; Get the eeprom stored runmode
		movlw	eeprom_startup_mode
		call	eeprom_read
		movwf	runmode			; Start stored mode
		; if(runmode > 7)
		;	eeprom_init()
		andlw	~MODE_MASK
		btfss	STATUS, Z
		call	eeprom_init

		call	restore_mode_init	; Set state and IND[0..2]

;
;------------------------------------------------------------------------------
; Main Loop 
;------------------------------------------------------------------------------
;

	; Timer1 fires between 3.8 and 976.6 times per second. This is for
	; ramping about between 1.56 and 401.1 seconds round-trip.
	; For step and random it means changes between 0.071 and 18.3 seconds.
		clrw				; Set timer1 to speed:0
		movwf	TMR1L
		movf	speed, w
		movwf	TMR1H
		bcf	PIR1, TMR1IF		; Clear the timer1 interrupt flag

		clrwdt				; Kick the dog before we start looping

main_loop
		btfsc	_flags, BIT_RXREADY
		call	handle_rx

		movf	_flags, w		; See if S2 has changed state since last time
		xorwf	buttonstate, w
		andlw	(1 << BIT_SET_MODE)
		btfss	STATUS, Z
		call	handle_set_mode

		btfss	PIR1, TMR1IF		; keep looping until timer1 fires
		goto	main_loop

		; Restart the timer here so that we don't use too many
		; cycles before it is restarted and thereby throwing
		; the timing off
		clrw				; Set timer1 to speed:0
		movwf	TMR1L			; timer1 fires between 3.8 and 976.6 times per second
		movf	speed, w
		movwf	TMR1H
		bcf	PIR1, TMR1IF		; Clear the timer1 interrupt flag

		; Timer1 fired, run the step-code

		; We kick the dog here to ensure that we will step through
		; the mode dispatcher at regular intervals. Otherwise we
		; could be stuck inside the timer1 wait...
		clrwdt			; Kick!

		movlw	HIGH(mode_table_start)
		movwf	PCLATH
		movf	runmode, w
		andlw	MODE_MASK		; We only know 8 modes
		call	gotomode
		goto	main_loop
gotomode
		addwf	PCL, f
mode_table_start
		goto	off_step
		goto	rampage_step
		goto	step_step
		goto	random_step
		goto	wheel_step
		goto	fixed_step
		return					; goto	serial_step
		goto	mode7_step
mode_table_end
IFDEF COD	; {
IF HIGH((mode_table_end-1) ^ mode_table_start) != 0		; {
 ERROR "mode_table crosses page boundary"
ENDIF		; }
ENDIF		; }

;
;------------------------------------------------------------------------------
; Serial mode
; This is a no-op, the serial data will set all values
;------------------------------------------------------------------------------
;
;serial_init
;		return
;serial_step
;		return
;
;------------------------------------------------------------------------------
; Mode 7
;------------------------------------------------------------------------------
;
;mode7_init
;		return
;
mode7_step
		; Not implemented, yet
		; set off mode for now
		movlw	MODE_OFF
		movwf	runmode
		goto	restore_mode_init

;
;------------------------------------------------------------------------------
; S2 button handling
; Called when a S2 state-change is detected
;------------------------------------------------------------------------------
;
handle_set_mode
		btfss	buttonstate, BIT_SET_MODE
		goto	handle_set_mode_on	; Only do something if it is pressed
		bcf	buttonstate, BIT_SET_MODE
		return
handle_set_mode_on
		bsf	buttonstate, BIT_SET_MODE
		; Safe current state
		; FIXME

		; Advance to next state
		movf	runmode, w		; Advance to next mode
		addlw	1
		andlw	MODE_MASK
		movwf	runmode
		; Fallthrough to init next mode and set IND[0..2]

		; Restore new state
restore_mode_init
		movlw	HIGH(modeinit_table_start)
		movwf	PCLATH
		movf	runmode, w
		andlw	MODE_MASK		; We only know 8 modes
		call	gotomodeinit
		goto	show_mode
gotomodeinit
		addwf	PCL, f
modeinit_table_start
		return				; goto	off_init
		goto	rampage_init
		goto	step_init
		goto	random_init
		goto	wheel_init
		goto	fixed_init
		return				; goto	serial_init
		return				; goto	mode7_init
modeinit_table_end
IFDEF COD	; {
IF HIGH((modeinit_table_end-1) ^ modeinit_table_start) != 0		; {
 ERROR "modeinit_table crosses page boundary"
ENDIF		; }
ENDIF		; }

show_mode
		; Show mode on IND[0..2]
		movlw	0xf8
		andwf	PORTC, f
		movf	runmode, w
		iorwf	PORTC, f
		return
;
;------------------------------------------------------------------------------
; Read the ADC channel 7
;------------------------------------------------------------------------------
;
read_adc
		bsf	ADCON0, GO	; Start A/D conversion
		btfsc	ADCON0, GO	; Poll until done
		goto	$-1

		banksel	ADRESL
		movf	ADRESL, w	; Read low A/D result
		banksel	ADRESH
		movwf	adc_lo
		movf	ADRESH, w	; Read high A/D result
		movwf	adc_hi
		return
;
;------------------------------------------------------------------------------
; Set speed from ADC and save to eeprom on button release
; Input: eeprom address in Wreg
;------------------------------------------------------------------------------
;
set_speed
		movwf	mul_tmp			; Save address of eeprom target

		btfss	_flags, BIT_SET_SPEED
		goto	set_speed_save		; If not set check if we need to save

		bsf	buttonstate, BIT_SET_SPEED	; Else set the speed
		call	read_adc
		rrf	adc_hi, f		; Reduce AD to 8 bit
		rrf	adc_lo, f
		rrf	adc_hi, f
		rrf	adc_lo, w
		movwf	speed
		return

set_speed_save
		btfss	buttonstate, BIT_SET_SPEED	; Only save if button just went off
		return

		bcf	buttonstate, BIT_SET_SPEED
		movf	speed, w
		movwf	FSR
		movf	mul_tmp, w
		goto	eeprom_write			; Store speed

;
;------------------------------------------------------------------------------
; Set direction from button and save to eeprom on initial button press
; Input: eeprom address in Wreg
; Output: C set if direction changed
;------------------------------------------------------------------------------
;
set_dir
		movwf	mul_tmp			; Save address of eeprom target
		bcf	STATUS, C		; Default to no dir change

		btfss	_flags, BIT_SET_DIR	; Don't do anything on not-pressed
		goto	set_dir_nopress

		; Ok, button is pressed, seen it before?
		btfsc	buttonstate, BIT_SET_DIR
		return				; Yes, seen it pressed, do nothing

		bsf	buttonstate, BIT_SET_DIR
		movlw	(1 << BIT_DIR)
		xorwf	_flags, f		; Invert direction
		movf	_flags, w		; Read the direction
		andlw	~(1 << BIT_DIR)		; Isolate it
		movwf	FSR
		movf	mul_tmp, w
		call	eeprom_write		; and store in eeprom
		bsf	STATUS, C		; Return status that dir changed
		return

set_dir_nopress
		bcf	buttonstate, BIT_SET_DIR
		return

;
;------------------------------------------------------------------------------
; OFF step
; Simply blanks all outputs...
;------------------------------------------------------------------------------
;
;off_init
;
;		return
off_step
		clrf	_bit_r
		clrf	_bit_g
		clrf	_bit_b
		return
;
;------------------------------------------------------------------------------
; Step step
; Step through discrete colors
;------------------------------------------------------------------------------
;
; Please find your own colors...
; My aesthetic abilities in artistic sense are non-existent
;
STEP_COUNT	equ	12

STEP_VAL_0	equ	0x33ff00
STEP_VAL_1	equ	0xff0000
STEP_VAL_2	equ	0x00ff00
STEP_VAL_3	equ	0x0000ff
STEP_VAL_4	equ	0xffff00
STEP_VAL_5	equ	0xff00ff
STEP_VAL_6	equ	0x00ffff
STEP_VAL_7	equ	0x33ff00
STEP_VAL_8	equ	0xffffff
STEP_VAL_9	equ	0xa0a0a0
STEP_VAL_10	equ	0x606060
STEP_VAL_11	equ	0x404040

make_step_r	macro	idx	; {
		if (idx < STEP_COUNT)	; {
			retlw	UPPER(STEP_VAL_#v(idx))
			make_step_r (idx + 1)
		endif		; }
		endm		; }
make_step_g	macro	idx	; {
		if (idx < STEP_COUNT)	; {
			retlw	HIGH(STEP_VAL_#v(idx))
			make_step_g (idx + 1)
		endif		; }
		endm		; }
make_step_b	macro	idx	; {
		if (idx < STEP_COUNT)	; {
			retlw	LOW(STEP_VAL_#v(idx))
			make_step_b (idx + 1)
		endif		; }
		endm		; }

step_init
		movlw	eeprom_step_speed	; Restore speed
		call	eeprom_read
		movwf	speed
		movlw	eeprom_step_dir		; and direction
		call	eeprom_read
		andlw	(1<<BIT_DIR)
		bcf	_flags, BIT_DIR
		iorwf	_flags, f
		return

step_step
		movlw	eeprom_step_speed
		call	set_speed
		movlw	eeprom_step_dir
		call	set_dir

		decfsz	tmr1div, f		; divide the timer1 firing rate
		return
		movlw	TMR1_DIVISOR
		movwf	tmr1div

		btfsc	_flags, BIT_DIR
		goto	step_decr
		; else direction increment
		incf	step_state, f		; step_state++
		movf	step_state, w		; if(step_state >= STEP_COUNT)
		addlw	-(STEP_COUNT-1)
		btfsc	STATUS, C
		clrf	step_state		;	step_state = 0;
		goto	step_handle_r
step_decr
		decf	step_state, f		; step_state--
		btfss	step_state, 7		; if(step_state < 0)
		goto	step_handle_r
		movlw	STEP_COUNT-1		;	step_state = STEP_COUNT-1;
		movwf	step_state

step_handle_r
		movlw	HIGH(step_r_table_start)
		movwf	PCLATH
		movf	step_state, w
		call	step_table_r
		movwf	_bit_r
		goto	step_handle_g
step_table_r
		addwf	PCL, f
step_r_table_start
		make_step_r	0
step_r_table_end
IFDEF COD	; {
IF HIGH((step_r_table_end-1) ^ step_r_table_start) != 0	; {
 ERROR "step_r_table crosses page boundary"
ENDIF		; }
ENDIF		; }

step_handle_g
		movlw	HIGH(step_r_table_start)
		movwf	PCLATH
		movf	step_state, w
		call	step_table_g
		movwf	_bit_g
		goto	step_handle_b
step_table_g
		addwf	PCL, f
step_g_table_start
		make_step_g	0
step_g_table_end
IFDEF COD	; {
IF HIGH((step_g_table_end-1) ^ step_g_table_start) != 0	; {
 ERROR "step_g_table crosses page boundary"
ENDIF		; }
ENDIF		; }

step_handle_b
		movlw	HIGH(step_r_table_start)
		movwf	PCLATH
		movf	step_state, w
		call	step_table_b
		movwf	_bit_b
		return
step_table_b
		addwf	PCL, f
step_b_table_start
		make_step_b	0
step_b_table_end
IFDEF COD	; {
IF HIGH((step_b_table_end-1) ^ step_b_table_start) != 0	; {
 ERROR "step_b_table crosses page boundary"
ENDIF		; }
ENDIF		; }
;
;------------------------------------------------------------------------------
; Fixed color step
; Set color based on A/D values
;
; S1	set hue
; S1+S3	set value
;    S3	set saturation
;------------------------------------------------------------------------------
;
fixed_init
		movlw	eeprom_fixed_hue_lo	; Restore color
		call	eeprom_read
		movwf	hue_lo
		movlw	eeprom_fixed_hue_hi
		call	eeprom_read
		movwf	hue_lo
		movlw	eeprom_fixed_value
		call	eeprom_read
		movwf	value
		movlw	eeprom_fixed_saturation
		call	eeprom_read
		movwf	saturation
		goto	_hsv_to_rgb		; Activate

fixed_step
		movf	_flags, w		; Check if S1/S3 are pressed
		movwf	mul_tmp			; save for later use (interrupts may change the flags)
		andlw	(1<<BIT_SET_HUE) | (1<<BIT_SET_SAT)
		btfsc	STATUS, Z
		return				; Not pressed, skip just return

		call	read_adc		; Get the current wheel position

		btfss	mul_tmp, BIT_SET_SAT
		goto	fixed_set_saturation
		btfss	mul_tmp, BIT_SET_HUE
		goto	fixed_set_hue

		; else set value
		rrf	adc_hi, f		; Reduce AD to 8 bit
		rrf	adc_lo, f
		rrf	adc_hi, f
		rrf	adc_lo, w
		movwf	value
		goto	_hsv_to_rgb

fixed_set_saturation
		rrf	adc_hi, f		; Reduce AD to 8 bit
		rrf	adc_lo, f
		rrf	adc_hi, f
		rrf	adc_lo, w
		movwf	saturation
		goto	_hsv_to_rgb

fixed_set_hue
		; Note: AD is 0..1023, which is multiplied by 3/2 -> 0..1534.
		; This is below the maximum hue value of 1541, so that works
		; very nicely.
		call	read_adc
		movf	adc_lo, w
		movwf	hue_lo
		movf	adc_hi, w
		movwf	hue_hi

		; Calculate AD = 3 * AD / 2
		bcf	STATUS, C	; AD *= 2
		rlf	hue_lo, f
		rlf	hue_hi, f

		movf	adc_lo, w	; AD = AD + 2*AD
		addwf	hue_lo, f
		movf	adc_hi, w
		btfsc	STATUS, C
		addlw	1
		addwf	hue_hi, f

		bcf	STATUS, C	; AD = 3 * AD / 2
		rrf	hue_hi, f
		rrf	hue_lo, f
		goto	_hsv_to_rgb	; Set the RGB values
;
;------------------------------------------------------------------------------
; Random step in RGB mode
;
; The method for random used is the Galois LFSR.
; See: http://en.wikipedia.org/wiki/Linear_feedback_shift_register
; See: http://www.piclist.com/techref/microchip/rand8bit.htm
;
; The used polynomial apears to have very large period (about 2^32-1), so that
; should be fine for our purposes. However, this is not explicitly verified.
;
; static uint32_t rand_val = 0xdeadbeef;
; uint32_t random_step(void)
; {
;	int c = rand_val & 1;
;	rand_val >>= 1;
;	if(c)
;		rand_val ^= 0xa6a6a6a6;
; }
;------------------------------------------------------------------------------
;
random_init
		movlw	eeprom_random_speed	; Restore speed
		call	eeprom_read
		movwf	speed
		return

random_step
		movlw	eeprom_random_speed
		call	set_speed

		decfsz	tmr1div, f		; divide the timer1 firing rate
		return
		movlw	TMR1_DIVISOR
		movwf	tmr1div

		bcf	STATUS, C
		rrf	rand_3, f
		rrf	rand_2, f
		rrf	rand_1, f
		rrf	rand_0, f
		btfss	STATUS, C
		goto	rand_set_rgb
		movlw	0xa6
		xorwf	rand_3, f
		xorwf	rand_2, f
		xorwf	rand_1, f
		xorwf	rand_0, f
rand_set_rgb
		movf	rand_0, w
		xorwf	rand_3, w
		movwf	_bit_r
		movf	rand_1, w
		xorwf	rand_3, w
		movwf	_bit_g
		movf	rand_2, w
		xorwf	rand_3, w
		movwf	_bit_b
		return
;
;------------------------------------------------------------------------------
; Handle serial input
;------------------------------------------------------------------------------
;
IFNDEF TEST_ALIGNMENT	; {
		nop		; Alignment for the xyz jump-table
		nop
		nop
		nop
		nop
ENDIF		; }
handle_rx
		bcf	PORTC, BITIND4		; Clear the receive indicator
		movf	_rxd, w			; Get the received byte
		bcf	_flags, BIT_RXREADY	; Receiver is free to store data again

		movwf	mul_tmp			; Save byte temp and store in cmd/data
		btfsc	mul_tmp, 7
		movwf	rxcmd
		btfss	mul_tmp, 7
		movwf	rxdata
		btfsc	mul_tmp, 7		; If this is a cmd, we're done
		return

		; We have a data byte, execute command
		movlw	HIGH(rx_table_start)
		movwf	PCLATH
		movf	rxcmd, w
		movwf	mul_tmp
		rrf	mul_tmp, f		; Isolate primary command selection bits
		rrf	mul_tmp, f
		rrf	mul_tmp, w
		andlw	0x07
		addwf	PCL, f			; Jump accordingly
rx_table_start
		goto	rx_special
		goto	rx_setred
		goto	rx_setgreen
		goto	rx_setblue
		goto	rx_sethue
		goto	rx_sethue
		goto	rx_setsaturation
		goto	rx_setvalue
rx_table_end
IFDEF COD	; {
IF HIGH((rx_table_end-1) ^ rx_table_start) != 0	; {
 ERROR "rx_table crosses page boundary"
ENDIF		; }
ENDIF		; }

; 10 000 --- 0-------	Nop
rx_special
		btfss	rxcmd, 6		; If bit 6 is '0', it is a NOP
		return
		; otherwise, continue

; 11 000 000 0-hsvrgb	Activate shadow values
; 11 000 001 0DMd-mmm	Set running mode/direction
; 11 000 01d 0ddddddd	Set running delay/speed
; 11 000 1-- 0-------	Nop
		movlw	HIGH(rx_special_table_start)
		movwf	PCLATH
		movf	rxcmd, w
		andlw	0x07
		addwf	PCL, f
rx_special_table_start
		goto	rx_setactivate
		goto	rx_setrunmode
		goto	rx_setspeed
		goto	rx_setspeed
		return				; this is a NOP
		return				; this is a NOP
		return				; this is a NOP
		return				; this is a NOP
rx_special_table_end
IFDEF COD	; {
IF HIGH((rx_special_table_end-1) ^ rx_special_table_start) != 0	; {
 ERROR "rx_special_table crosses page boundary"
ENDIF		; }
ENDIF		; }

rx_setactivate
		btfss	rxdata, 0
		goto	rx_not_b
		movf	shdw_blue, w
		xorwf	_bit_b, w
		xorwf	_bit_b, f
		xorwf	_bit_b, w
		movwf	shdw_blue
rx_not_b
		btfss	rxdata, 1
		goto	rx_not_g
		movf	shdw_green, w
		xorwf	_bit_g, w
		xorwf	_bit_g, f
		xorwf	_bit_g, w
		movwf	shdw_green
rx_not_g
		btfss	rxdata, 2
		goto	rx_not_r
		movf	shdw_red, w
		xorwf	_bit_r, w
		xorwf	_bit_r, f
		xorwf	_bit_r, w
		movwf	shdw_red
rx_not_r
		btfss	rxdata, 3
		goto	rx_not_v
		movf	shdw_value, w
		xorwf	value, w
		xorwf	value, f
		xorwf	value, w
		movwf	shdw_value
rx_not_v
		btfss	rxdata, 4
		goto	rx_not_s
		movf	shdw_saturation, w
		xorwf	saturation, w
		xorwf	saturation, f
		xorwf	saturation, w
		movwf	shdw_saturation
rx_not_s
		btfss	rxdata, 5
		goto	rx_not_h
		movf	shdw_hue_lo, w
		xorwf	hue_lo, w
		xorwf	hue_lo, f
		xorwf	hue_lo, w
		movwf	shdw_hue_lo
		movf	shdw_hue_hi, w
		xorwf	hue_hi, w
		xorwf	hue_hi, f
		xorwf	hue_hi, w
		movwf	shdw_hue_hi
rx_not_h
		movf	rxdata, w		; If HSV values changed, call RGB conversion
		andlw	0x38
		btfss	STATUS, Z
		call	_hsv_to_rgb
		return
rx_setrunmode
		movf	rxdata, w
		andlw	MODE_MASK
		btfss	rxdata, BIT_RUN_ENABLE
		goto	rx_nomodeset
		movwf	runmode
		call	restore_mode_init		; Restore the state
rx_nomodeset
		btfss	rxdata, BIT_DIR_ENABLE
		return
		bcf	_flags, BIT_DIR
		btfsc	rxdata, 4
		bsf	_flags, BIT_DIR
		return

rx_setspeed
		call	rx_fix_data8
		movwf	speed
		return
; 1a 001 --r 0rrrrrrr	Set Red
rx_setred
		call	rx_fix_data8
		btfss	rxcmd, 6
		movwf	shdw_red
		btfsc	rxcmd, 6
		movwf	_bit_r
		return
; 1a 010 --g 0ggggggg	Set Green
rx_setgreen
		call	rx_fix_data8
		btfss	rxcmd, 6
		movwf	shdw_green
		btfsc	rxcmd, 6
		movwf	_bit_g
		return
; 1a 011 --b 0bbbbbbb	Set Blue
rx_setblue
		call	rx_fix_data8
		btfss	rxcmd, 6
		movwf	shdw_blue
		btfsc	rxcmd, 6
		movwf	_bit_b
		return
; 1a 10h hhh 0hhhhhhh	Set Hue
rx_sethue
		call	rx_fix_data8
		btfss	rxcmd, 6
		movwf	shdw_hue_lo
		btfsc	rxcmd, 6
		movwf	hue_lo
		rrf	rxcmd, w	; the remaining high bits are in the cmd byte
		andlw	0x07
		btfss	rxcmd, 6
		movwf	shdw_hue_hi
		btfsc	rxcmd, 6
		movwf	hue_hi
		goto	rx_update_hsv
; 1a 110 --s 0sssssss	Set Saturation
rx_setsaturation
		call	rx_fix_data8
		btfss	rxcmd, 6
		movwf	shdw_saturation
		btfsc	rxcmd, 6
		movwf	saturation
		goto	rx_update_hsv
; 1a 111 --v 0vvvvvvv	Set Value
rx_setvalue
		call	rx_fix_data8
		btfss	rxcmd, 6
		movwf	shdw_value
		btfsc	rxcmd, 6
		movwf	value
rx_update_hsv
		btfsc	rxcmd, 6
		call	_hsv_to_rgb
		return

; Restore the high bit in the rx data from the low bit of the cmd byte
; return data in Wreg
rx_fix_data8
		rlf	rxdata, f
		rrf	rxcmd, w
		rrf	rxdata, w
		return

;
;------------------------------------------------------------------------------
; Rampage: ramping RGB mode
;------------------------------------------------------------------------------
;
RAMPAGE_RUG	equ	0
RAMPAGE_RDR	equ	1
RAMPAGE_RUB	equ	2
RAMPAGE_RDG	equ	3
RAMPAGE_RUR	equ	4
RAMPAGE_RDB	equ	5
RAMPAGE_MAX	equ	6

rampage_init
		movlw	eeprom_rampage_speed	; Restore speed
		call	eeprom_read
		movwf	speed
		movlw	eeprom_rampage_dir	; Restore direction
		call	eeprom_read
		andlw	(1<<BIT_DIR)
		bcf	_flags, BIT_DIR
		iorwf	_flags, f
		clrf	rampage_state		; When we get back to rampage, we want to start fresh
		return

rampage_step
		movlw	eeprom_rampage_speed
		call	set_speed
		movlw	eeprom_rampage_dir
		call	set_dir
		btfss	STATUS, C		; set_dir sets C if direction changed
		goto	rampage_dispatch

		; Reverse the running direction state position
		movlw	-(RAMPAGE_MAX/2)	; goto state - 3 position
		addwf	rampage_state, f	; save
		movlw	RAMPAGE_MAX
		addwf	rampage_state, w	; set modulo position
		btfsc	STATUS, C		; is the add wrapped, the initial subtract underflowed
		movwf	rampage_state		; save the modulo
rampage_dispatch
		movlw	HIGH(rampage_table_start)
		movwf	PCLATH
		movf	rampage_state, w
		addwf	PCL, f
rampage_table_start
		goto	rampage_rug
		goto	rampage_rdr
		goto	rampage_rub
		goto	rampage_rdg
		goto	rampage_rur
		goto	rampage_rdb
rampage_table_end
IFDEF COD	; {
IF HIGH((rampage_table_end-1) ^ rampage_table_start) != 0	; {
 ERROR "rampage_table crosses page boundary"
ENDIF		; }
ENDIF		; }

rampage_rug	; Rampup Green
		incfsz	_bit_g, f
		return
		decf	_bit_g, f		; go back to 0xff
		movlw	RAMPAGE_RDR		; move to next state
		btfsc	_flags, BIT_DIR
		movlw	RAMPAGE_RDB		; move to previous state
		movwf	rampage_state
		return

rampage_rdr	; Rampdown Red
		decfsz	_bit_r, f
		return
		movlw	RAMPAGE_RUB		; move to next state
		btfsc	_flags, BIT_DIR
		movlw	RAMPAGE_RUG		; move to previous state
		movwf	rampage_state
		return

rampage_rub	; Rampup Blue
		incfsz	_bit_b, f
		return
		decf	_bit_b, f		; go back to 0xff
		movlw	RAMPAGE_RDG		; move to next state
		btfsc	_flags, BIT_DIR
		movlw	RAMPAGE_RDR		; move to previous state
		movwf	rampage_state
		return

rampage_rdg	; Rampdown Green
		decfsz	_bit_g, f
		return
		movlw	RAMPAGE_RUR		; move to next state
		btfsc	_flags, BIT_DIR
		movlw	RAMPAGE_RUB		; move to previous state
		movwf	rampage_state
		return

rampage_rur	; Rampup Red
		incfsz	_bit_r, f
		return
		decf	_bit_r, f		; go back to 0xff
		movlw	RAMPAGE_RDB		; move to next state
		btfsc	_flags, BIT_DIR
		movlw	RAMPAGE_RDG		; move to previous state
		movwf	rampage_state
		return

rampage_rdb	; Rampdown Blue
		decfsz	_bit_b, f
		return
		movlw	RAMPAGE_RUG		; move to next state
		btfsc	_flags, BIT_DIR
		movlw	RAMPAGE_RUR		; move to previous state
		movwf	rampage_state
		return
;
;------------------------------------------------------------------------------
; Wheel: circle the hue circle
;------------------------------------------------------------------------------
;
wheel_init
		movlw	eeprom_wheel_speed	; Restore speed
		call	eeprom_read
		movwf	speed
		movlw	eeprom_wheel_dir	; Restore direction
		call	eeprom_read
		andlw	(1<<BIT_DIR)
		bcf	_flags, BIT_DIR
		iorwf	_flags, f
		movlw	eeprom_wheel_value	; Restore value
		call	eeprom_read
		movwf	value
		movlw	eeprom_wheel_saturation	; Restore sauration
		call	eeprom_read
		movwf	saturation
		goto	_hsv_to_rgb		; activate color

wheel_step
		movf	_flags, w		; Save flags so we see a consistent state
		movwf	mul_tmp

		andlw	(1<<BIT_SET_SPEED) | (1<<BIT_SET_SAT)
		btfsc	STATUS, Z		; Set the wheel output if no buttons
		goto	wheel_move

		call	read_adc		; Get an 8-bit reading
		rrf	adc_hi, f
		rrf	adc_lo, f
		rrf	adc_hi, f
		rrf	adc_lo, f

		; We know that at least one button is pressed here
		movf	adc_lo, w
		btfss	mul_tmp, BIT_SET_SPEED
		goto	wheel_set_sat		; speed not pressed -> set saturation
		btfss	mul_tmp, BIT_SET_SAT
		goto	wheel_set_speed		; saturation not pressed -> set speed

		; Here both buttons are pressed -> set value
		movwf	value
		goto	wheel_move

wheel_set_speed
		movlw	eeprom_wheel_speed
		call	set_speed
		goto	wheel_move

wheel_set_sat
		movwf	saturation
		; FALLTHROUGH
wheel_move
		btfss	_flags, BIT_DIR
		goto	wheel_decr
		; if(++hue >= MAX_HUE+1)
		;	hue = 0
		incf	hue_lo, f		; ++hue
		btfsc	STATUS, Z
		incf	hue_hi

		movlw	HIGH(MAX_HUE+1)
		subwf	hue_hi, w		; hue_hi - HIGH(MAX_HUE+1)
		btfss	STATUS, Z
		goto	wheel_testc		; if(hue_hi == HIGH(MAX_HUE+1)) -> test carry
		movlw	LOW(MAX_HUE+1)
		subwf	hue_lo, w		; hue_lo - LOW(MAX_HUE+1)
wheel_testc
		btfss	STATUS, C
		goto	wheel_set		; if(hue_lo >= LOW(MAX_HUE+1)) -> jump true
		clrf	hue_lo
		clrf	hue_hi
		goto	wheel_set

wheel_decr
		movlw	-1
		addwf	hue_lo, f		; --hue_lo
		btfsc	STATUS, C		; if(hue_lo >= 0)
		goto	wheel_set		;	done
		addwf	hue_hi, f		; --hue_hi
		btfsc	STATUS, C		; if(hue_hi >= 0)
		goto	wheel_set		;	done
		movlw	HIGH(MAX_HUE)		; else hue = MAX_HUE
		movwf	hue_hi
		movlw	LOW(MAX_HUE)
		movwf	hue_lo

wheel_set
		goto	_hsv_to_rgb
;
;------------------------------------------------------------------------------
; HSV to RGB conversion
;------------------------------------------------------------------------------
; H [0..1541]	angle 0 == 0deg, 1541 < 360deg
;		sextants: [0..256], [257..513], [514..770], [771..1027], [1028..1284], [1285..1541]
;		8-bit(+1) per sextant
;		~0.2335 degrees per count
;		This is the highest resolution possible with 8 bit target colors and is already
;		slightly higher than necessay (max resolution is ~6 * 256). However, using the
;		current setup makes calculation a lot easier by using 8-bit shifts.
; S [0..255]
; V [0..255]
;
;	frac = h;
;	if(h < 257) {
;		frac -= 0;
;		red   = v;
;		green = (v * (uchar)(~((s * (256-frac)) >> 8))) >> 8;
;		blue  = (v * (uchar)(~s + 1)) >> 8;
;	} else if(h < 514) {
;		frac -= 257;
;		red   = (v * (uchar)(~((s * frac) >> 8))) >> 8;
;		green = v;
;		blue  = (v * (uchar)(~s + 1)) >> 8;
;	} else if(h < 514) {
;		frac -= 257;
;		red   = (v * (uchar)(~s + 1)) >> 8;
;		green = v;
;		blue  = (v * (uchar)(~((s * (256-frac)) >> 8))) >> 8;
;	} else if(h < 771) {
;		frac -= 514;
;		red   = (v * (uchar)(~s + 1)) >> 8;
;		green = (v * (uchar)(~((s * frac) >> 8))) >> 8;
;		blue  = v;
;	} else if(h < 1028) {
;		frac -= 771;
;		red   = (v * (uchar)(~((s * (256-frac)) >> 8))) >> 8;
;		green = (v * (uchar)(~s + 1)) >> 8;
;		blue  = v;
;	} else {
;		frac -= 1028;
;		red   = v;
;		green = (v * (uchar)(~s + 1)) >> 8;
;		blue  = (v * (uchar)(~((s * frac) >> 8))) >> 8;
;	}
;
; FIXME: We should not do a linear search in the if() clauses, but do bisection
; to make the timing more stable and slightly faster...
;
_hsv_to_rgb
		bcf	STATUS, RP0		; BANK0

		movf	hue_lo, w		; frac = hue
		movwf	frac_lo
		movf	hue_hi, w
		movwf	frac_hi

		; if(hue < SEXT1)
		movlw	HIGH(SEXT1)
		subwf	hue_hi, w		; hue_hi - HIGH(SEXT1)
		btfss	STATUS, Z
		goto	hsv_testc0		; if(hue_hi == HIGH(SEXT1)) -> test carry
		movlw	LOW(SEXT1)
		subwf	hue_lo, w		; hue_lo - LOW(SEXT1)
hsv_testc0
		btfsc	STATUS, C
		goto	hsv_st1			; if(hue_lo >= LOW(SEXT1)) -> jump false

		; h < SEXT1
		movf	value, w		; red = v
		movwf	_bit_r
		call	hsv_nsBmfrac_mul_v
		movwf	_bit_g
		call	hsv_ns1_mul_v
		movwf	_bit_b
		return

hsv_st1
		; if(hue < SEXT2)
		movlw	HIGH(SEXT2)
		subwf	hue_hi, w
		btfss	STATUS, Z
		goto	hsv_testc1
		movlw	LOW(SEXT2)
		subwf	hue_lo, w
hsv_testc1
		btfsc	STATUS, C
		goto	hsv_st2

		; h < SEXT2
		movlw	LOW(SEXT1)		; frac -= SEXT1
		subwf	frac_lo, f
		movlw	HIGH(SEXT1)
		btfss	STATUS, C
		addlw	1
		subwf	frac_hi, f

		call	hsv_nsfrac_mul_v
		movwf	_bit_r
		movf	value, w
		movwf	_bit_g
		call	hsv_ns1_mul_v
		movwf	_bit_b
		return

hsv_st2
		; if(hue < SEXT3)
		movlw	HIGH(SEXT3)
		subwf	hue_hi, w
		btfss	STATUS, Z
		goto	hsv_testc2
		movlw	LOW(SEXT3)
		subwf	hue_lo, w
hsv_testc2
		btfsc	STATUS, C
		goto	hsv_st3

		; h < SEXT3
		movlw	LOW(SEXT2)		; frac -= SEXT2
		subwf	frac_lo, f
		movlw	HIGH(SEXT2)
		btfss	STATUS, C
		addlw	1
		subwf	frac_hi, f

		call	hsv_ns1_mul_v
		movwf	_bit_r
		movf	value, w
		movwf	_bit_g
		call	hsv_nsBmfrac_mul_v
		movwf	_bit_b
		return

hsv_st3
		; if(hue < SEXT4)
		movlw	HIGH(SEXT4)
		subwf	hue_hi, w
		btfss	STATUS, Z
		goto	hsv_testc3
		movlw	LOW(SEXT4)
		subwf	hue_lo, w
hsv_testc3
		btfsc	STATUS, C
		goto	hsv_st4

		; h < SEXT4
		movlw	LOW(SEXT3)		; frac -= SEXT3
		subwf	frac_lo, f
		movlw	HIGH(SEXT3)
		btfss	STATUS, C
		addlw	1
		subwf	frac_hi, f

		call	hsv_ns1_mul_v
		movwf	_bit_r
		call	hsv_nsfrac_mul_v
		movwf	_bit_g
		movf	value, w
		movwf	_bit_b
		return

hsv_st4
		; if(hue < SEXT5)
		movlw	HIGH(SEXT5)
		subwf	hue_hi, w
		btfss	STATUS, Z
		goto	hsv_testc4
		movlw	LOW(SEXT5)
		subwf	hue_lo, w
hsv_testc4
		btfsc	STATUS, C
		goto	hsv_st5

		; h < SEXT5
		movlw	LOW(SEXT4)		; frac -= SEXT4
		subwf	frac_lo, f
		movlw	HIGH(SEXT4)
		btfss	STATUS, C
		addlw	1
		subwf	frac_hi, f

		call	hsv_nsBmfrac_mul_v
		movwf	_bit_r
		call	hsv_ns1_mul_v
		movwf	_bit_g
		movf	value, w
		movwf	_bit_b
		return

hsv_st5
		; else
		; h >= SEXT5
		movlw	LOW(SEXT5)		; frac -= SEXT5
		subwf	frac_lo, f
		movlw	HIGH(SEXT5)
		btfss	STATUS, C
		addlw	1
		subwf	frac_hi, f

		movf	value, w
		movwf	_bit_r
		call	hsv_ns1_mul_v
		movwf	_bit_g
		call	hsv_nsfrac_mul_v
		movwf	_bit_b
		return

;------------
; Calculate Wreg = ((uchar)(~s + 1) * value) >> 8
;
hsv_ns1_mul_v
		movf	saturation, w		; s
		xorlw	0xff			; ~s
		addlw	1			; (~s + 1)
		goto	hsv_mul_v
;
;------------
; Calculate Wreg = (v * (uchar)(~((s * (256-frac)) >> 8))) >> 8;
;
hsv_nsBmfrac_mul_v
		movf	frac_lo, w
		sublw	LOW((SEXTSIZE-1))
		movwf	mul_lo
		movf	frac_hi, w
		btfss	STATUS, C
		incf	frac_hi, w
		sublw	HIGH((SEXTSIZE-1))
		movwf	mul_hi
		goto	hsv_domul
;
;------------
; Calculate Wreg = (v * (uchar)(~((s * frac) >> 8))) >> 8;
;
hsv_nsfrac_mul_v
		movf	frac_lo, w
		movwf	mul_lo
		movf	frac_hi, w
		movwf	mul_hi
hsv_domul
		movf	saturation, w
		call	mult_8x16	; mul * s
		movf	res_hi, w	; low(x >> 8) == high(x)
		xorlw	0xff
		goto	hsv_mul_v
;
;------------
; Calculate WReg = (Wreg * value) >> 8
;
hsv_mul_v
		movwf	mul_lo
		clrf	mul_hi
		movf	value, w
		call	mult_8x16
		movf	res_hi, w
		return

;------------
; Multiply routine
;	res_hi:res_lo = mul_hi:mul_lo * Wreg
; The result is 16 bit, which is sufficient here (max values: 256*255).
;
; Multiply one bit loop-unroll
mulbit		macro	doshift		; {
		local	muladdskip
		rrf	mul_tmp, f
		btfss	STATUS, C
		goto	muladdskip

		movf	mul_lo, w
		addwf	res_lo, f
		movf	mul_hi, w
		btfsc	STATUS, C
		addlw	1
		addwf	res_hi, f	

muladdskip
IF doshift == 1	; {
		bcf	STATUS, C
		rlf	mul_lo, f
		rlf	mul_hi, f
ENDIF		; }
		endm	; }
;
mult_8x16
		movwf	mul_tmp
		clrf	res_lo
		clrf	res_hi

		mulbit	1
		mulbit	1
		mulbit	1
		mulbit	1
		mulbit	1
		mulbit	1
		mulbit	1
		mulbit	0
		return

IFDEF FAKEEEPROM	; {
;
;------------------------------------------------------------------------------
; Eeprom fakery
;------------------------------------------------------------------------------
;
eeprom_fake_addr	equ	0xa0

eeprom_read
		addlw	eeprom_fake_addr
		movwf	FSR
		movf	INDF, w
		return

eeprom_write
		addlw	eeprom_fake_addr
		xorwf	FSR, w		; exchange Wreg <-> FSR
		xorwf	FSR, f
		xorwf	FSR, w
		movwf	INDF
		return
ELSE			; }{
;
;------------------------------------------------------------------------------
; Read eeprom value
; Address in Wreg -> output in Wreg
;------------------------------------------------------------------------------
;
eeprom_read
		banksel	EEADR
		movwf	EEADR		; Set address
IFDEF __16F690	; {
		banksel	EECON1
		bcf	EECON1, EEPGD
ENDIF		; }
		bsf	EECON1, RD	; Read

IFDEF __16F690	; {
		banksel	EEDAT
ENDIF		; }
		movf	EEDAT, w	; Get the data
		banksel	0
		return

;
;------------------------------------------------------------------------------
; Write eeprom value
; Address in Wreg, data in FSR
;------------------------------------------------------------------------------
;
eeprom_write
		movwf	mul_tmp		; Save address
;		call	eeprom_read
;		subwf	FSR, w		; Check is data is same
;		btfsc	STATUS, Z
;		return

		banksel	EEADR
		movf	mul_tmp, w
		movwf	EEADR		; Set address
		movf	FSR, w
		movwf	EEDAT		; Set data
IFDEF __16F684	; {
		banksel	PIR1
		bcf	PIR1, EEIF
ENDIF		; }
IFDEF __16F690	; {
		banksel	PIR2
		bcf	PIR2, EEIF
		banksel	EECON1
		bcf	EECON1, EEPGD
ENDIF		; }
		bsf	EECON1, WREN	; Write enable

		bcf	INTCON, GIE	; Disable interrupts
		btfsc	INTCON, GIE	; See AN576, must ensure disable
		goto	$-2

		movlw	0x55
		movwf	EECON2
		movlw	0xaa
		movwf	EECON2
		bsf	EECON1, WR
		bsf	INTCON, GIE
		; Wait for the write to complete
IFDEF __16F690	; {
		banksel	PIR2
		btfss	PIR2, EEIF
		goto	$-1
		bcf	PIR2, EEIF
ENDIF		; }
IFDEF __16F684	; {
		banksel	PIR1
		btfss	PIR1, EEIF
		goto	$-1
		bcf	PIR1, EEIF
ENDIF		; }

		banksel	EECON1
		bcf	EECON1, WREN
		banksel	0
		return
ENDIF			; }
;
;------------------------------------------------------------------------------
; Initialize eeprom values
;------------------------------------------------------------------------------
;
eeprom_dowrite	macro	addr, val	; {
		movlw	val
		movwf	FSR
		movlw	addr
		call	eeprom_write
		endm			; }

eeprom_init
		eeprom_dowrite	eeprom_startup_mode, MODE_RAMPAGE
		eeprom_dowrite	eeprom_rampage_speed, 0xc0
		eeprom_dowrite	eeprom_rampage_dir, 0
		eeprom_dowrite	eeprom_step_speed, 0xc0
		eeprom_dowrite	eeprom_step_dir, 0
		eeprom_dowrite	eeprom_random_speed, 0xc0
		eeprom_dowrite	eeprom_wheel_speed, 0xc0
		eeprom_dowrite	eeprom_wheel_dir, 0
		eeprom_dowrite	eeprom_wheel_value, 255
		eeprom_dowrite	eeprom_wheel_saturation, 255
		eeprom_dowrite	eeprom_fixed_hue_lo, 0
		eeprom_dowrite	eeprom_fixed_hue_hi, 0
		eeprom_dowrite	eeprom_fixed_value, 255
		eeprom_dowrite	eeprom_fixed_saturation, 255
		movlw	MODE_RAMPAGE
		movwf	runmode
		return

		end
