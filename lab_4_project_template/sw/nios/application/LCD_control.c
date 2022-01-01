/*
 * LCD_control.c
 *
 *  Created on: 29 déc. 2021
 *      Author: franc
 */
#include "LCd_control.h"
#include "io.h"
#include "system.h"
#include <unistd.h>


//Macros to ease the programming
#define Set_LCD_RST			IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0b1100, 0x00000001)
#define Clr_LCD_RST 		IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0b1100, 0x00000000)
#define LCD_WR_REG(value)	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0b0000, value)
#define LCD_WR_DATA(value)	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0b0000, value)

#define CLK_frequ		50000	//50 MHz/1000

void Delay_Ms(alt_u16 count_ms)
{
    while(count_ms--)
    {
        usleep(1000);
    }
}

/*//take input as ms
void Delay_Ms(unsigned int delta_t) {

	int nbr_iteration = delta_t*(CLK_frequ);

	for(int i = 0; i < nbr_iteration; ++i) {
			__asm__("nop");
	}

}
*/
void LCD_init() {

	alt_u16 data1, datat2;
	alt_u16 data3, data4;

	Set_LCD_RST;
	Delay_Ms(1);
	Clr_LCD_RST;
	Delay_Ms(10);
	Set_LCD_RST;
	Delay_Ms(120);

	LCD_WR_REG(0x00000011);	//Exit sleep

	LCD_WR_REG(0x000000CF); 		//Power Control B
		LCD_WR_DATA(0x00010000); // Always 0x00
		LCD_WR_DATA(0x00010081); //
		LCD_WR_DATA(0X000100c0);

	LCD_WR_REG(0x000000ED); // Power on sequence control
		LCD_WR_DATA(0x00010064); // Soft Start Keep 1 frame
		LCD_WR_DATA(0x00010003); //
		LCD_WR_DATA(0X00010012);
		LCD_WR_DATA(0X00010081);

	LCD_WR_REG(0x000000E8); // Driver timing control A
	 	LCD_WR_DATA(0x00010085);
	 	LCD_WR_DATA(0x00010001);
	 	LCD_WR_DATA(0x00010798);

	 LCD_WR_REG(0x000000CB); // Power control A
	 	LCD_WR_DATA(0x00010039);
	 	LCD_WR_DATA(0x0001002C);
	 	LCD_WR_DATA(0x00010000);
	 	LCD_WR_DATA(0x00010034);
	 	LCD_WR_DATA(0x00010002);

	 LCD_WR_REG(0x000000F7); // Pump ratio control
	 	LCD_WR_DATA(0x00010020);

	 LCD_WR_REG(0x000000EA); // Driver timing control B
	 	LCD_WR_DATA(0x00010000);
	 	LCD_WR_DATA(0x00010000);

	 LCD_WR_REG(0x000000B1); // Frame Control (In Normal Mode)
	 	LCD_WR_DATA(0x00010000);
	 	LCD_WR_DATA(0x0001001b);

	 LCD_WR_REG(0x000000B6); // Display Function Control
	 	LCD_WR_DATA(0x0001000A);
	 	LCD_WR_DATA(0x000100A2);

	 LCD_WR_REG(0x000000C0); //Power control 1
	 	LCD_WR_DATA(0x00010005); //VRH[5:0]

	  LCD_WR_REG(0x000000C1); //Power control 2
	 	LCD_WR_DATA(0x00010011); //SAP[2:0];BT[3:0]

	 LCD_WR_REG(0x000000C5); //VCM control 1
	 	LCD_WR_DATA(0x00010045); //3F
	 	LCD_WR_DATA(0x00010045); //3

	 LCD_WR_REG(0x000000C7); //VCM control 2
	 	LCD_WR_DATA(0x000100a2);

	 LCD_WR_REG(0x00000036); // Memory Access Control
	 	LCD_WR_DATA(0x00010008);// BGR order

	 LCD_WR_REG(0x000000F2); // Enable 3G
	 	LCD_WR_DATA(0x00010000); // 3Gamma Function Disable

	  LCD_WR_REG(0x00000026); // Gamma Set
	 	LCD_WR_DATA(0x00010001); // Gamma curve selected

	 LCD_WR_REG(0x000000E0); // Positive Gamma Correction, Set Gamma
	 	LCD_WR_DATA(0x0001000F);
	 	LCD_WR_DATA(0x00010026);
	 	LCD_WR_DATA(0x00010024);
	 	LCD_WR_DATA(0x0001000b);
	 	LCD_WR_DATA(0x0001000E);
	 	LCD_WR_DATA(0x00010008);
	 	LCD_WR_DATA(0x0001004b);
	 	LCD_WR_DATA(0x000100a8);
	 	LCD_WR_DATA(0x0001003b);
	 	LCD_WR_DATA(0x0001000a);
	 	LCD_WR_DATA(0x00010014);
	 	LCD_WR_DATA(0x00010006);
	 	LCD_WR_DATA(0x00010010);
	 	LCD_WR_DATA(0x00010009);
	 	LCD_WR_DATA(0x00010000);

	 LCD_WR_REG(0x000000E1); //Negative Gamma Correction, Set Gamma
	 	LCD_WR_DATA(0x00010000);
	 	LCD_WR_DATA(0x0001001c);
	 	LCD_WR_DATA(0x00010020);
	 	LCD_WR_DATA(0x00010004);
	 	LCD_WR_DATA(0x00010010);
	 	LCD_WR_DATA(0x00010008);
	 	LCD_WR_DATA(0x00010034);
	 	LCD_WR_DATA(0x00010047);
	 	LCD_WR_DATA(0x00010044);
	 	LCD_WR_DATA(0x00010005);
	 	LCD_WR_DATA(0x0001000b);
	 	LCD_WR_DATA(0x00010009);
	 	LCD_WR_DATA(0x0001002f);
	 	LCD_WR_DATA(0x00010036);
	 	LCD_WR_DATA(0x0001000f);

	 LCD_WR_REG(0x0000002A); // Column Address Set
	 	LCD_WR_DATA(0x00010000);
	 	LCD_WR_DATA(0x00010000);
	 	LCD_WR_DATA(0x00010000);
	 	LCD_WR_DATA(0x000100ef);

	 LCD_WR_REG(0x0000002B); // Page Address Set
	 	LCD_WR_DATA(0x00010000);
	 	LCD_WR_DATA(0x00010000);
	 	LCD_WR_DATA(0x00010001);
	 	LCD_WR_DATA(0x0001003f);

	 LCD_WR_REG(0x0000003A); // COLMOD: Pixel Format Set
	 	LCD_WR_DATA(0x00010055);

	 LCD_WR_REG(0x000000f6); // Interface Control
	 	LCD_WR_DATA(0x00010001);
	 	LCD_WR_DATA(0x00010030);
	 	LCD_WR_DATA(0x00010000);

	 LCD_WR_REG(0x00000029); //display on
	 LCD_WR_REG(0x0000002c); // 0x2C

}

