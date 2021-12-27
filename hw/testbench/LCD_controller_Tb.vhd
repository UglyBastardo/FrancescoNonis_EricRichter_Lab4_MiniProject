library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tb_LCD_controller is

end tb_LCD_controller;


architecture test of tb_LCD_controller is

	constant CLK_PERIOD1 	: time := 100 ns;

	--clock characteristics
	constant clk_period	  	: time   := 20 ns;
	signal CLK			  	: std_logic;
	
	--Avalon Slave interface signals
	signal NRESET			: std_logic;
	signal AS_ADDRESS		: std_logic_vector(1 downto 0);
	signal AS_WRITE			: std_logic;
	signal AS_WRITEDATA		: std_logic_vector(31 downto 0);
	signal AS_WAIT			: std_logic;
	signal AS_READ			: std_logic;
	signal AS_READDATA 		: std_logic_vector(31 downto 0);
	
	--Avalon Master interface signals
	signal AM_ADDRESS		: std_logic_vector(31 downto 0);
	signal AM_READ	 		: std_logic;
	signal AM_WAIT			: std_logic;
	signal READDATAVALID	: std_logic;	
	signal READ_DATA 		: std_logic_vector(31 downto 0);
	signal BURSTCOUNT		: std_logic_vector(4 downto 0);
	
	--interface with the LCD 
	signal CSX				: std_logic;
	signal RESX				: std_logic;
	signal DCX 				: std_logic;
	signal WRX 				: std_logic;
	signal RDX 				: std_logic;
	signal data				: std_logic_vector(15 downto 0);
	
	--count number of burst done
	signal NBR_BURST		: integer;
	
begin
	
	dut: entity work.LCD_controller port map (
		CLK				=> clk,		
		NRESET			=> nReset,	
		
		--interface with the Avalon Bus, slave side
		AS_ADDRESS		=> AS_Address,  	
		AS_WRITE		=> AS_write,    	
		AS_WRITEDATA	=> AS_Writedata,	
		AS_WAIT			=> AS_Wait,			
		AS_READ			=> AS_Read,			
		AS_READDATA		=> AS_ReadData,		
		
		--interface with the Avalon Bus, master side (DMA)
		AM_ADDRESS		=> AM_Address,		
		AM_READ			=> AM_read,	 		 	
		AM_WAIT			=> AM_wait,			 	
		READDATAVALID	=> readdatavalid,	 		
		READ_DATA		=> read_data, 		 	
		BURSTCOUNT		=> burstcount,			
		
		--interface with the LCD screen
		CSX				=> CSX,				 
		RESX			=> RESX,			 
		DCX				=> DCX, 			 
		WRX				=> WRX, 			
		RDX				=> RDX, 			
		data			=> data);
	
	--synchronus clock signal generation 
	clk_generation: process
	begin
		CLK <= '1';
		wait for clk_period / 2;
		CLK <= '0';
		wait for clk_period / 2;
	end process clk_generation;
	
	--simulation sequence
	simu: process
		
		
		--reset procedure
		procedure async_reset is
			
			begin
				wait until rising_edge(CLK);
				wait for CLK_PERIOD1 / 2;
				NRESET <= '0';
				
				wait for CLK_PERIOD1 / 2;
				NRESET <= '1';
		end procedure async_reset;
		
		--AS write test procedure
		procedure test_write_dut(constant add : in std_logic_vector(1 downto 0);
						   constant wrt_data: in std_logic_vector(31 downto 0)) is
			
			begin
			
			wait until rising_edge(CLK);
			AS_WRITE 		<= '1';
			AS_ADDRESS		<= add;
			AS_WRITEDATA	<= wrt_data;
			
			wait until rising_edge(CLK);
			AS_WRITE		<= '0';
			AS_ADDRESS		<= (others => '0');
			AS_WRITEDATA	<= (others => '0');	   
						   
		end procedure test_write_dut;
		
		
		--AS read test procedure
		procedure test_read_dut(constant add : in std_logic_vector(1 downto 0)) is
			
			begin
			
			wait until rising_edge(CLK);
			AS_READ <= '1';
			AS_ADDRESS <= add;
			
			
			wait until rising_edge(CLK);
			AS_READ <= '0';
			AS_ADDRESS <= (others => '0');
		
		end procedure test_read_dut;
		
		
		--simulate the memory reaction to a read request
		procedure memory_simu(constant data_mem : in std_logic_vector(31 downto 0)) is
		
		begin
		
			wait until rising_edge(CLK);
			READDATAVALID 	<= '0';
			READ_DATA		<= data_mem;
			
			wait until rising_edge(CLK);
			READDATAVALID	<= '1';
			
			wait until rising_edge(CLK);
			READDATAVALID	<= '0';
		
		
		end procedure memory_simu;
		
		--simulate a whole burst memory read
		procedure single_burst_simu is
		
		begin
			
			
			memory_simu(x"00010002"); --1
			memory_simu(x"00030004"); --2
			memory_simu(x"00050006"); --3
			memory_simu(x"00070008"); --4
			memory_simu(x"0009000A"); --5
			memory_simu(x"000B000C"); --6
			memory_simu(x"000D000E"); --7
			memory_simu(x"000F0010"); --8
			memory_simu(x"00200030"); --9
			memory_simu(x"00400050"); --10
			memory_simu(x"00600070"); --11
			memory_simu(x"00800090"); --12
			memory_simu(x"00A000B0"); --13
			memory_simu(x"00C000D0"); --14
			memory_simu(x"00E000F0"); --15
			memory_simu(x"01000200"); --16 
			memory_simu(x"03000400"); --17
			memory_simu(x"05000600"); --18
			memory_simu(x"07000800"); --19
			memory_simu(x"09000A00"); --20 
		end procedure single_burst_simu;
		
	begin
	--assigning all signals
	NRESET 			<= '1';
	AS_ADDRESS		<= "00";  	
	AS_WRITE		<= '0';    	
	AS_WRITEDATA	<= x"00000000";				
	AS_READ			<= '0';			
	AM_WAIT			<= '0';
	READDATAVALID	<= '0';
	READ_DATA		<= x"00000000";
	NBR_BURST		<= 0;
	
	wait until rising_edge(CLK);
	
	
	
	--start by doing a reset
	async_reset;
	
	wait until rising_edge(CLK);
	--test access to RESX
	test_write_dut("11", x"00000000");
	wait until rising_edge(CLK);
	test_write_dut("11", x"00000001");
	--test a write
	test_write_dut("00", x"00010FFF");
	wait until AS_WAIT = '0';
	
	--test sending an image to LCD_controller
	test_write_dut("01", x"1000FFFF");	--setup adress
	test_write_dut("00", x"0000002C");
	
	for j in 1 to 1920 loop
		NBR_BURST <= NBR_BURST + 1;
		wait until AM_READ = '1';
		single_burst_simu;
	end loop;
	
	--wait until AM_READ = '1';
	--single_burst_simu;
	
	
	wait until AS_WAIT = '0';
	
	end process simu;


end test;