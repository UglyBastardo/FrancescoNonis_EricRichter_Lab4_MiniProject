library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_Avalon_slave is

end tb_Avalon_slave;


architecture test of tb_Avalon_slave is 

	constant CLK_PERIOD1 : time := 100 ns;

	--clock characteristics
	constant clk_period	  : time   := 20 ns;
	signal CLK			  : std_logic;
	
	--LCD interface signal
	signal LCD_WRITE			: std_logic;
	signal CMD_DATA 			: std_logic_vector(31 downto 0);
	signal LCD_WAIT 			: std_logic;
	signal LCD_NRESET			: std_logic;
	
	--Avalon Slave signals
	signal NRESET				: std_logic;
	signal AS_ADDRESS			: std_logic_vector(1 downto 0);
	signal AS_WRITE				: std_logic;
	signal AS_WRITEDATA			: std_logic_vector(31 downto 0);
	signal AS_WAIT				: std_logic;
	signal AS_READ				: std_logic;
	signal AS_READDATA 			: std_logic_vector(31 downto 0);
	
	--interface with avalon master
	signal MEMORY_ADDRESS 	: std_logic_vector(31 downto 0);
	signal IMG_SENT			: std_logic;
	signal AM_NRESET		: std_logic;


begin 

	dut : entity work.avalon_slave
		port map(
			CLK 			=> clk,
			NRESET			=> nReset,
			LCD_WRITE		=> LCD_write,
			CMD_DATA		=> Cmd_Data,
			LCD_WAIT		=> LCD_wait,
			LCD_NRESET		=> LCD_nReset,
			AS_ADDRESS 		=> AS_Address,
			AS_WRITE		=> AS_write,
			AS_WRITEDATA 	=> AS_Writedata,
			AS_WAIT			=> AS_Wait,
			AS_READ			=> AS_Read,
			AS_READDATA		=> AS_ReadData,
			MEMORY_ADDRESS 	=> Memory_Address,
			IMG_SENT		=> Img_sent,
			AM_NRESET		=> AM_nReset);


	--synchronus clock signal generation 
	clk_generation: process
	begin
		CLK <= '1';
		wait for clk_period / 2;
		CLK <= '0';
		wait for clk_period / 2;
	end process clk_generation;
	
	--simulation process
	simulation: process
		
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
		
		--simulate an image finished being sent
		procedure test_img_sent is
		
			begin
			wait until rising_edge(CLK);
			IMG_SENT <= '1';
			
			wait until rising_edge(CLK);
			IMG_SENT <= '0';
		
		end procedure test_img_sent;
		
		--simulate an LCD write with a LCD wait signal being given 
		procedure simu_real_write_to_LCD(constant add: in std_logic_vector(1 downto 0);
										 constant wrt_data: in std_logic_vector(31 downto 0)) is
			begin
			
			
			wait until rising_edge(CLK);
			AS_WRITE 		<= '1';
			AS_ADDRESS		<= add;
			AS_WRITEDATA	<= wrt_data;
			
			wait until rising_edge(CLK);
			AS_WRITE 		<= '0';
			wait until rising_edge(CLK);
			LCD_WAIT <= '1';
			
			wait for 2*CLK_PERIOD1;
			LCD_WAIT <= '0';
			AS_WRITE <= '0';
			AS_ADDRESS <= (others => '0');
			AS_WRITEDATA <= (others => '0');
			
			
			
			
		end procedure simu_real_write_to_LCD;
	
		--simulate the CPU wanting to write to the LCD while it is busy
		procedure simu_write_to_busy(constant add: in std_logic_vector(1 downto 0);
										 constant wrt_data: in std_logic_vector(31 downto 0)) is
			begin
			
			
			wait until rising_edge(CLK);
			AS_WRITE 		<= '1';
			AS_ADDRESS		<= add;
			AS_WRITEDATA	<= wrt_data;
			
			wait until rising_edge(CLK);
			AS_WRITE 		<= '0';
			wait until rising_edge(CLK);
			LCD_WAIT <= '1';
			
			--while LCD is busy, we try to do another write
			wait until rising_edge(CLK);
			AS_WRITE 		<= '1';
			AS_ADDRESS		<= add;
			AS_WRITEDATA 	<= x"0002FFFF";
			
			wait until rising_edge(CLK);
			LCD_WAIT <= '0';
			
			wait until rising_edge(CLK);
			null;
			
			wait until rising_edge(CLK);
			AS_ADDRESS <= (others => '0');
			AS_WRITEDATA <= (others => '0');
			AS_WRITE <= '0';
			
			
		end procedure simu_write_to_busy;
		
		
	begin
		
			--Default values
			NRESET			<= '1';
			AS_ADDRESS  	<= (others => '0');
			AS_WRITE    	<= '0';
			AS_WRITEDATA	<= (others => '0');
			LCD_WAIT		<= '0';
			IMG_SENT		<= '0';
			AS_READ			<= '0';
			wait for CLK_PERIOD1;
			
			--Reset of the circuit
			async_reset;
			
			--start testing the device
			--we first do a write test on register 0 (command/data)
			test_write_dut("00", x"00010010");
			wait until AS_WAIT = '0';
			--test register 1 (memory adress)
			test_write_dut("01", x"FFFF1111");
			wait for CLK_PERIOD1;
			--test an image sent with read of the register just after
			test_img_sent;
			test_read_dut("10");
			wait for CLK_PERIOD1;
			
			--simulate a wait signal from the LCD
			simu_real_write_to_LCD("00", x"0001FFFF");
			wait for CLK_PERIOD1;
			simu_write_to_busy("00", x"0001FFF0");
		
	
	end process simulation;





end test;