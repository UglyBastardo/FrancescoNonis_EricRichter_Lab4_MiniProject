/*
 * "Hello World" example.
 *
 * This example prints 'Hello from Nios II' to the STDOUT stream. It runs on
 * the Nios II 'standard', 'full_featured', 'fast', and 'low_cost' example
 * designs. It runs with or without the MicroC/OS-II RTOS and requires a STDOUT
 * device in your system's hardware.
 * The memory footprint of this hosted application is ~69 kbytes by default
 * using the standard reference design.
 *
 * For a reduced footprint version of this template, and an explanation of how
 * to reduce the memory footprint for a given application, see the
 * "small_hello_world" template.
 *
 */

#include <stdio.h>
#include "LCD_control.h"
#include "system.h"
#include "io.h"

#define NBR_PIXEL	76800
#define RED			0xF800
#define GREEN		0x07E0
#define BLUE		0x001F

#define ADDRESS_REG 	0b100
#define COMMAND_REG 	0b00
#define IMAGE_READ_REG 	0b1000
#define DISPLAY_COMMAND 0x0000002C
#define NOP_COMMAND		0x00000000

//function to load an image on the SD card
void write_image_1();
void write_image_2();
int main()
{
	//write an image to memory
	write_image_1();
	//initialize the LCD
	LCD_init();

	//tells the LCD to display the written image
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, ADDRESS_REG, HPS_0_BRIDGES_BASE);
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, COMMAND_REG, DISPLAY_COMMAND);
	alt_u32 img_read = IORD_32DIRECT(LCD_CONTROLLER_0_BASE, IMAGE_READ_REG);

	while(img_read != 0x00000001) {
		img_read = IORD_32DIRECT(LCD_CONTROLLER_0_BASE, IMAGE_READ_REG);
	}

	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, IMAGE_READ_REG, 0x00000000);
	write_image_2();
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, ADDRESS_REG, HPS_0_BRIDGES_BASE);
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, COMMAND_REG, DISPLAY_COMMAND);



	while(1) {


	}



  return 0;
}




void write_image_1() {
	/*	generates and loads an image to the SDRAM */
	for (alt_u32 i = 0; i < NBR_PIXEL/4; ++i)
	{
		IOWR_16DIRECT(HPS_0_BRIDGES_BASE, 2*i, GREEN);
	}

	for (alt_u32 i = NBR_PIXEL/4; i < NBR_PIXEL/2; ++i) {
		IOWR_16DIRECT(HPS_0_BRIDGES_BASE, 2*i, BLUE);
	}
	for (alt_u32 i = NBR_PIXEL/2; i < 3*NBR_PIXEL/4; ++i) {
			IOWR_16DIRECT(HPS_0_BRIDGES_BASE, 2*i, RED);
	}
	for (alt_u32 i = 3*NBR_PIXEL/4; i < NBR_PIXEL; ++i) {
				IOWR_16DIRECT(HPS_0_BRIDGES_BASE, 2*i, BLUE|GREEN);
	}

}

void write_image_2() {
	/*	generates and loads an image to the SDRAM */
	for (alt_u32 i = 0; i < NBR_PIXEL/4; ++i)
	{
		IOWR_16DIRECT(HPS_0_BRIDGES_BASE, 2*i, GREEN);
	}

	for (alt_u32 i = NBR_PIXEL/4; i < NBR_PIXEL/2; ++i) {
		IOWR_16DIRECT(HPS_0_BRIDGES_BASE, 2*i, BLUE);
	}
	for (alt_u32 i = NBR_PIXEL/2; i < 3*NBR_PIXEL/4; ++i) {
			IOWR_16DIRECT(HPS_0_BRIDGES_BASE, 2*i, GREEN);
	}
	for (alt_u32 i = 3*NBR_PIXEL/4; i < NBR_PIXEL; ++i) {
				IOWR_16DIRECT(HPS_0_BRIDGES_BASE, 2*i, BLUE);
	}

}
