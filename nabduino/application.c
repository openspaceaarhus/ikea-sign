/*
* Ikea DIODER serial to nabto protocol
* Copyright (C) 2012 Rasmus Rohde
*
* To use this with the nabduino you need to make sure all debug output
* is disabled since we are using the serial port for the communication.
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include "application.h"
#include "unabto_app.h"
#include "unabto_util.h"

#define LED0_IO				                                                (LATDbits.LATD2)
#define	BUTTON0_IO                                                                      (PORTCbits.RC0)

static rom char my_url_pgm[] = "http://duff.dk/skilt/html_dd.zip";

void my_uart_initialize(void) {
	TXSTA = 0x20;
	RCSTA = 0x90;

	// 1200 baud
	TXSTA1bits.BRGH = 1;
	BAUDCON1bits.BRG16 = 1;
	SPBRGH1 = 0x21;
	SPBRG1 = 0xe8;

	LATCbits.LATC6 = 1;
	TRISCbits.TRISC6 = 0;
	TRISCbits.TRISC7 = 1;
}

bool uart_can_write(void) {
	return PIR1bits.TXIF == 1;
}

void my_uart_write(uint8_t value) {
	while (uart_can_write() == false);

	TXREG = value;
}

/**
 * The microchip specific application logic
 */
int application_event(application_request_t* request, buffer_read_t* read_buffer, buffer_write_t* write_buffer) {
	switch (request->query_id) {
        case 42:
        {
/*
  <query name="skilt" description="RGB Chooser" id="42">
  <request>
  <parameter name="red" type="uint8"/>
  <parameter name="green" type="uint8"/>
  <parameter name="blue" type="uint8"/>
  </request>
  <response>
  <parameter name="ret" type="uint8" />
  </response>
  </query>
*/
		uint8_t red, green, blue;
		if (!buffer_read_uint8(read_buffer, &red)) return -1;
		if (!buffer_read_uint8(read_buffer, &green)) return -1;
		if (!buffer_read_uint8(read_buffer, &blue)) return -1;

		// Red
		my_uart_write(0xc8 | (red >> 7));
		my_uart_write(red & 0x7f);

		// Green
		my_uart_write(0xd0 | (green >> 7));
		my_uart_write(green & 0x7f);

		// Blue
		my_uart_write(0xd8 | (blue >> 7));
		my_uart_write(blue & 0x7f);

		if (!buffer_write_uint8(write_buffer, (uint8_t)0)) return -1;
		return 0;
        }
        case 43:
        {
/*
  <query name="skilt" description="Mode Chooser" id="43">
  <request>
  <parameter name="mode" type="uint8"/>
  </request>
  <response>
  <parameter name="ret" type="uint8" />
  </response>
  </query>
*/
		uint8_t mode;
		if (!buffer_read_uint8(read_buffer, &mode)) return -1;

		my_uart_write(0xc1);
		my_uart_write(0x20 | (mode & 0x7));

		if (!buffer_write_uint8(write_buffer, (uint8_t)0)) return -1;
		return 0;
	}
	case 44:
	{
/*
  <query name="raw" description="Raw Command" id="44">
  <request>
  <parameter name="byte1" type="uint8"/>
  <parameter name="byte2" type="uint8"/>
  </request>
  <response>
  <parameter name="ret" type="uint8" />
  </response>
  </query>
*/
		uint8_t byte1, byte2;
		if (!buffer_read_uint8(read_buffer, &byte1)) return -1;
		if (!buffer_read_uint8(read_buffer, &byte2)) return -1;

		my_uart_write(byte1);
		my_uart_write(byte2);

		if (!buffer_write_uint8(write_buffer, (uint8_t)0)) return -1;

		return 0;
	}
	}
	return -1;
}

void setup(char** url) {
	static char my_url[sizeof(my_url_pgm)];

	my_uart_initialize();

	/* Set mode serial */
	my_uart_write(0xc1);
	my_uart_write(0x26);
	
	strcpypgm2ram(my_url, my_url_pgm);
	*url = my_url;
}

static uint16_t c = 0;

void loop(void) {
	c++;
	if((c & 0x3ff) == 0) {
		LED0_IO ^= 1;
	}
}
