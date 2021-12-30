library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LCD_controller is 
	port (
		--clk and reset signal
		signal clk		: in std_logic;
		signal nReset	: in std_logic;
		
		--interface with the Avalon Bus, slave side
		signal AS_Address  	: in std_logic_vector(1 downto 0);
		signal AS_write    	: in std_logic;
		signal AS_Writedata	: in std_logic_vector(31 downto 0);
		signal AS_Wait			: out std_logic;
		signal AS_Read			: in std_logic;
		signal AS_ReadData		: out std_logic_vector(31 downto 0);
		
		--interface with the Avalon Bus, master side (DMA)
		signal AM_Address		:	out std_logic_vector(31 downto 0);
		signal AM_read	 		: 	out std_logic;
		signal AM_wait			: 	in std_logic;
		signal readdatavalid	: 	in std_logic;	
		signal read_data 		: 	in std_logic_vector(31 downto 0);
		signal burstcount		: 	out std_logic_vector(4 downto 0);
		
		--interface with the LCD screen
		signal CSX				: 	out std_logic;
		signal RESX			: 	out std_logic;
		signal DCX 			: 	out std_logic;
		signal WRX 			: 	out std_logic;
		signal RDX 			: 	out std_logic;
		signal data			:	out std_logic_vector(15 downto 0);
		
		signal LCD_ON		: out std_logic
	);
end entity LCD_controller;



architecture controller of LCD_controller is
	
	--signals between DMA and avalon slave modules
	signal mem_addr			: std_logic_vector(31 downto 0);
	signal img_read			: std_logic;
	
	--signals between Avalon Slave and LCD controller
	signal write_RQ		:  std_logic;
	signal cmd_data		:  std_logic_vector(31 downto 0);
	signal wait_LCD		:  std_logic;
	
	--interface with the LCD controll module and DMA
	signal start_read		: std_logic;
	
	--interface with the FIFO and the DMA
	signal write_FIFO			:  std_logic;
	signal write_data_FIFO 		:  std_logic_vector(31 downto 0);
	signal FIFO_full			:  std_logic;
	signal FIFO_written_words	:  std_logic_vector(8 downto 0);
	
	--inteface between the FIFO and the LCD Control module
	signal read_FIFO		:	 std_logic;
	signal read_data_FIFO 	:	 std_logic_vector(15 downto 0);
	signal FIFO_empty		: 	 std_logic;
	-----------------------------------------------------------------------------------------------
	
	--declaring the components -Master controller
	component MasterController is 
		port(
			clk 			: 	in std_logic;
			nReset 			:	in std_logic;
			
			-- External interface (i.e. Avalon Bus).
			AM_Address		:	out std_logic_vector(31 downto 0);
			AM_read	 		: 	out std_logic;
			AM_wait			: 	in std_logic;
			readdatavalid	: 	in std_logic;	
			read_data 		: 	in std_logic_vector(31 downto 0);
			burstcount		: 	out std_logic_vector(4 downto 0);


			-- Internal interface (LCD block).
			start_read		: 	in std_logic;
			
			-- Internal interface (Registers block).
			mem_addr			:	in std_logic_vector(31 downto 0);
			img_read			:	out std_logic;
			
			-- Internal interface (FIFO) 
			write_FIFO			:	out std_logic;
			write_data_FIFO 	:	out std_logic_vector(31 downto 0);
			FIFO_full			: 	in std_logic;
			FIFO_written_words	:	in std_logic_vector(8 downto 0)
			--FIFO_almost_full	: 	in std_logic
		
		
		);
	end component MasterController;
	
	component LCD is
		port(
			clk 			: 	in std_logic;
			nReset 			:	in std_logic;
			
			-- External interface (ILI9341).
			CSX				: 	out std_logic;
			--RESX			: 	out std_logic;
			DCX 			: 	out std_logic;
			WRX 			: 	out std_logic;
			RDX 			: 	out std_logic;
			data			:	out std_logic_vector(15 downto 0);
			
			-- Internal interface (Registers).
			write_RQ		: 	in std_logic;
			cmd_data		:	in std_logic_vector(31 downto 0);
			wait_LCD		: 	out std_logic;

			
			-- Internal interface (DMA block).
			start_read		: 	out std_logic;
			img_read		:   in std_logic;
			
			-- Internal interface (FIFO) 
			read_FIFO		:	out std_logic;
			read_data_FIFO 	:	in std_logic_vector(15 downto 0);
			FIFO_empty		: 	in std_logic
		
		);
		
	end component LCD;
	
	component Avalon_slave is 
		port(
			--Avalon Slave interface signals
			clk				: in std_logic;
			nReset			: in std_logic;
			AS_Address  	: in std_logic_vector(1 downto 0);
			AS_write    	: in std_logic;
			AS_Writedata	: in std_logic_vector(31 downto 0);
			AS_Wait			: out std_logic;
		
			AS_Read			: in std_logic;
			AS_ReadData		: out std_logic_vector(31 downto 0);
			
			--Interface with Avalon Master
			Memory_Address  : out std_logic_vector(31 downto 0);
			Img_sent		: in std_logic;
			--AM_nReset		: out std_logic;
			
			--Interface with the LCD control module
			LCD_write		: out std_logic;
			Cmd_Data		: out std_logic_vector(31 downto 0);
			LCD_wait		: in std_logic;
			
			--RESX pin 
			RESX			: out std_logic;
			LCD_ON			: out std_logic
		
		);
	end component Avalon_slave;
	
	component FIFO2 is
		port(
		data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		rdclk		: IN STD_LOGIC ;
		rdreq		: IN STD_LOGIC ;
		wrclk		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
		rdempty		: OUT STD_LOGIC ;
		wrfull		: OUT STD_LOGIC ;
		wrusedw		: OUT STD_LOGIC_VECTOR (8 DOWNTO 0)
		
		);
	end component FIFO2;

begin

	DMA: component MasterController port map(
		--general signals (Clock and reset)
		clk		=> clk,
		nReset 	=> nReset,
		
		-- External interface (i.e. Avalon Bus).
		AM_Address 		=> AM_Address,
		AM_read	 		=> AM_read,	
		AM_wait			=> AM_wait,
		readdatavalid	=> readdatavalid,
		read_data 		=> read_data,
		burstcount		=> burstcount,


		-- Internal interface (LCD block).
		start_read		=> start_read,
		
		-- Internal interface (Registers block).
		mem_addr		=> mem_addr,
		img_read		=> img_read,		
		
		-- Internal interface (FIFO) 
		write_FIFO			=> 	write_FIFO,
		write_data_FIFO 	=>	write_data_FIFO,
		FIFO_full			=>	FIFO_full,
		FIFO_written_words	=>	FIFO_written_words);
		

	LCD_component: component LCD port map(
		--general signal
		clk		=> clk,
		nReset 	=> nReset,
		
		--interface with the lEDS signals
		CSX		=>	CSX,
		DCX 	=>	DCX,	
		WRX 	=>	WRX, 	
		RDX 	=>	RDX, 	
		data	=>	data,
		
		-- Internal interface (Registers).
		write_RQ	=> write_RQ,
		cmd_data	=> cmd_data,
		wait_LCD	=> wait_LCD,

		
		-- Internal interface (LCD block).
		start_read	=> start_read,
		img_read	=> img_read,
		
		-- Internal interface (FIFO) 
		read_FIFO		=> read_FIFO,
		read_data_FIFO	=> read_data_FIFO, 
		FIFO_empty		=> FIFO_empty);

	
	AS: component Avalon_slave port map(
			--general signal
			clk		=> clk,		
			nReset	=> nReset,
			
			--Avalon Slave interface signals
			AS_Address  	=> AS_Address,
			AS_write    	=> AS_write,
			AS_Writedata	=> AS_Writedata,
			AS_Wait			=> AS_Wait,
		
			AS_Read			=> AS_Read,
			AS_ReadData		=> AS_ReadData,
			
			--Interface with Avalon Master
			Memory_Address 	=> mem_addr,
			Img_sent 		=> img_read,
			
			
			--Interface with the LCD control module
			LCD_write		=> write_RQ,
			Cmd_Data 		=> cmd_data,
			LCD_wait  		=> wait_LCD,
			
			RESX	=>	RESX,
			LCD_ON	=> LCD_ON);
			
	
	FIFO2_component: component FIFO2 port map(
			data 		=> write_data_FIFO,		 
			rdclk 		=> clk,		 
			rdreq 		=> read_FIFO,		 
			wrclk 		=> clk,		
			wrreq 		=> write_FIFO,					
			q 			=> read_data_FIFO,		
			rdempty 	=> FIFO_empty,		
			wrfull 		=> FIFO_full,		
			wrusedw 	=> FIFO_written_words);


end controller;