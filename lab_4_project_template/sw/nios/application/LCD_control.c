/*
 * LCD_control.c
 *
 *  Created on: 29 déc. 2021
 *      Author: franc
 */
#include "LCd_control.h"
#include "io.h"
#include "system.h"


//Macros to ease the programming
#define Set_LCD_RST			IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0b1100, 0x00000001)
#define Clr_LCD_RST 		IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0b1100, 0x00000000)
#define LCD_WR_REG(value)	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0b00, value)
#define LCD_WR_DATA(value)	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0b00, value||0x0001000)

#define CLK_frequ		50000000	//50 MHz

//take input as ms
void Delay_Ms(unsigned int delta_t) {

	int nbr_iteration = delta_t*(CLK_frequ/1000);

	for(int i = 0; i < nbr_iteration; ++i) {
			__asm__("nop");
	}


}

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
		LCD_WR_DATA(0x00000000); // Always 0x00
		LCD_WR_DATA(0x00000081); //
		LCD_WR_DATA(0X000000c0);

	LCD_WR_REG(0x000000ED); // Power on sequence control
		LCD_WR_DATA(0x00000064); // Soft Start Keep 1 frame
		LCD_WR_DATA(0x00000003); //
		LCD_WR_DATA(0X00000012);
		LCD_WR_DATA(0X00000081);

	LCD_WR_REG(0x000000E8); // Driver timing control A
	 	LCD_WR_DATA(0x00000085);
	 	LCD_WR_DATA(0x00000001);
	 	LCD_WR_DATA(0x00000798);

	 LCD_WR_REG(0x000000CB); // Power control A
	 	LCD_WR_DATA(0x00000039);
	 	LCD_WR_DATA(0x0000002C);
	 	LCD_WR_DATA(0x00000000);
	 	LCD_WR_DATA(0x00000034);
	 	LCD_WR_DATA(0x00000002);

	 LCD_WR_REG(0x000000F7); // Pump ratio control
	 	LCD_WR_DATA(0x00000020);

	 LCD_WR_REG(0x000000EA); // Driver timing control B
	 	LCD_WR_DATA(0x00000000);
	 	LCD_WR_DATA(0x00000000);

	 LCD_WR_REG(0x000000B1); // Frame Control (In Normal Mode)
	 	LCD_WR_DATA(0x00000000);
	 	LCD_WR_DATA(0x0000001b);

	 LCD_WR_REG(0x000000B6); // Display Function Control
	 	LCD_WR_DATA(0x0000000A);
	 	LCD_WR_DATA(0x000000A2);

	 LCD_WR_REG(0x000000C0); //Power control 1
	 	LCD_WR_DATA(0x00000005); //VRH[5:0]

	  LCD_WR_REG(0x000000C1); //Power control 2
	 	LCD_WR_DATA(0x00000011); //SAP[2:0];BT[3:0]

	 LCD_WR_REG(0x000000C5); //VCM control 1
	 	LCD_WR_DATA(0x00000045); //3F
	 	LCD_WR_DATA(0x00000045); //3

	 LCD_WR_REG(0x000000C7); //VCM control 2
	 	LCD_WR_DATA(0x000000a2);

	 LCD_WR_REG(0x00000036); // Memory Access Control
	 	LCD_WR_DATA(0x00000008);// BGR order

	 LCD_WR_REG(0x000000F2); // Enable 3G
	 	LCD_WR_DATA(0x00000000); // 3Gamma Function Disable

	  LCD_WR_REG(0x00000026); // Gamma Set
	 	LCD_WR_DATA(0x00000001); // Gamma curve selected

	 LCD_WR_REG(0x000000E0); // Positive Gamma Correction, Set Gamma
	 	LCD_WR_DATA(0x0000000F);
	 	LCD_WR_DATA(0x00000026);
	 	LCD_WR_DATA(0x00000024);
	 	LCD_WR_DATA(0x0000000b);
	 	LCD_WR_DATA(0x0000000E);
	 	LCD_WR_DATA(0x00000008);
	 	LCD_WR_DATA(0x0000004b);
	 	LCD_WR_DATA(0x000000a8);
	 	LCD_WR_DATA(0x0000003b);
	 	LCD_WR_DATA(0x0000000a);
	 	LCD_WR_DATA(0x00000014);
	 	LCD_WR_DATA(0x00000006);
	 	LCD_WR_DATA(0x00000010);
	 	LCD_WR_DATA(0x00000009);
	 	LCD_WR_DATA(0x00000000);

	 LCD_WR_REG(0x000000E1); //Negative Gamma Correction, Set Gamma
	 	LCD_WR_DATA(0x00000000);
	 	LCD_WR_DATA(0x0000001c);
	 	LCD_WR_DATA(0x00000020);
	 	LCD_WR_DATA(0x00000004);
	 	LCD_WR_DATA(0x00000010);
	 	LCD_WR_DATA(0x00000008);
	 	LCD_WR_DATA(0x00000034);
	 	LCD_WR_DATA(0x00000047);
	 	LCD_WR_DATA(0x00000044);
	 	LCD_WR_DATA(0x00000005);
	 	LCD_WR_DATA(0x0000000b);
	 	LCD_WR_DATA(0x00000009);
	 	LCD_WR_DATA(0x0000002f);
	 	LCD_WR_DATA(0x00000036);
	 	LCD_WR_DATA(0x0000000f);

	 LCD_WR_REG(0x0000002A); // Column Address Set
	 	LCD_WR_DATA(0x00000000);
	 	LCD_WR_DATA(0x00000000);
	 	LCD_WR_DATA(0x00000000);
	 	LCD_WR_DATA(0x000000ef);

	 LCD_WR_REG(0x0000002B); // Page Address Set
	 	LCD_WR_DATA(0x00000000);
	 	LCD_WR_DATA(0x00000000);
	 	LCD_WR_DATA(0x00000001);
	 	LCD_WR_DATA(0x0000003f);

	 LCD_WR_REG(0x0000003A); // COLMOD: Pixel Format Set
	 	LCD_WR_DATA(0x00000055);

	 LCD_WR_REG(0x000000f6); // Interface Control
	 	LCD_WR_DATA(0x00000001);
	 	LCD_WR_DATA(0x00000030);
	 	LCD_WR_DATA(0x00000000);

	 LCD_WR_REG(0x00000029); //display on
	 LCD_WR_REG(0x0000002c); // 0x2C





}

