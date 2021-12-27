library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_DMA is

end tb_DMA;


architecture test of tb_DMA is 
	constant CLK_PERIOD1 					: time := 100 ns;

	--clock characteristics
	constant clk_period	  					: time   := 20 ns;
	
	signal CLK 				: std_logic;
	signal NRESET 			: std_logic;
	
	-- External interface (i.e. Avalon Bus).
	signal AM_ADDRESS		:	std_logic_vector(31 downto 0);
	signal AM_READ	 		: 	std_logic;
	signal AM_WAIT			: 	std_logic;
	signal READDATAVALID	: 	std_logic;	
	signal READ_DATA 		: 	std_logic_vector(31 downto 0);
	signal BURSTCOUNT		: 	std_logic_vector(4 downto 0);


	-- Internal interface (LCD block).
	signal START_READ		: 	std_logic;
	
	-- Internal interface (Registers block).
	signal MEM_ADDR			:	std_logic_vector(31 downto 0);
	signal IMG_READ			:	std_logic;
	
	-- Internal interface (FIFO) 
	signal WRITE_FIFO		:	std_logic;
	signal WRITE_DATA_FIFO:	std_logic_vector(31 downto 0);
	signal FIFO_FULL		: 	std_logic;
	signal FIFO_written_words: std_logic_vector(8 downto 0);
	
	
	
begin 

	dut : entity work.MasterController
		port map(
			CLK 				=> clk,
			NRESET			=> nReset,
			AM_ADDRESS		=> AM_Address,
			AM_READ			=> AM_read,
			AM_WAIT			=> AM_wait,
			READDATAVALID	=> readdatavalid,
			READ_DATA 		=> read_data,
			BURSTCOUNT		=> burstcount,
			START_READ 		=> start_read,
			MEM_ADDR		=> mem_addr,
			IMG_READ		=> img_read,
			WRITE_FIFO		=> write_FIFO,
			WRITE_DATA_FIFO=> write_data_FIFO,
			FIFO_FULL		=> FIFO_full,
			FIFO_written_words=>FIFO_written_words);
			
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
		
		--Avalon react to DMA test procedure
		procedure test_Avalon_react_to_dut(
			constant read_data1: in std_logic_vector(31 downto 0);
			constant read_data2: in std_logic_vector(31 downto 0);
			constant FIFO_mode : in std_logic_vector(1 downto 0)
			) is
			
		begin
			--send wait request when AM_READ is issued			
			wait until rising_edge(AM_READ);
			AM_WAIT	<= '1';
			
			--after a while, stop wait request but do not send valid data (data1)
			wait for 3*clk_period;
			wait until rising_edge(CLK);
			AM_WAIT		 	<= '0';
			READDATAVALID	<= '0';
			READ_DATA 		<= read_data1;
			
			--after a while send valid data (data2) 4 times in a row
			wait for 2*clk_period;
			wait until rising_edge(CLK);
			READDATAVALID	<= '1';
			READ_DATA 		<= read_data2;  
			wait for 3.5*clk_period;	
			
			--set FIFO signals if specified
			case FIFO_mode is
				when "01" =>
					FIFO_written_words	<= "111111111";
				when "10" =>
					FIFO_FULL			<= '1';
				when "11" =>	
					FIFO_FULL 			<= '1';
					FIFO_written_words  <= "111111111";
				when others =>
					FIFO_written_words 	<= "000000000";
					FIFO_FULL		  	<= '0';
			end case;
			
			--make data unvalid for a while (data2)
			wait until rising_edge(CLK);
			READDATAVALID<= '0';
			READ_DATA 		<= read_data2;
		
			--after that while, send the rest of the data valid as data1
			wait for 3*clk_period;
			wait until rising_edge(CLK);
			READDATAVALID<= '1';
			READ_DATA		<= read_data1;
			wait for 16*clk_period;
			
			--change the READ_DATA: nothing should be read by the DMA
			wait until rising_edge(CLK);
			READ_DATA 		<= read_data2;
			
			--change the READDATAVALID to 0
			wait until rising_edge(CLK);
			READDATAVALID	<= '0';

		end procedure test_Avalon_react_to_dut;
		
		
		
		
		procedure test_interract_FIFO is
		begin
			--tell the DMA that the FIFO is full only
			wait until rising_edge(CLK);
			FIFO_written_words	<="000000000";
			FIFO_FULL			<='1';
			wait for 2*clk_period;
			
			--tell the DMA that the FIFO is almost full only
			wait until rising_edge(CLK);
			FIFO_FULL			<= '0';
			FIFO_written_words	<= "111111111";
			wait for 2*clk_period;
			
			--tell the DMA that the FIFO is ready to receive
			wait until rising_edge(CLK);
			FIFO_FULL			<= '0';
			FIFO_written_words	<= "000000000";
		end procedure test_interract_FIFO;
		
	begin
		--default values
		NRESET 				<= '1';
		MEM_ADDR				<= x"12345678";
		READDATAVALID		<= '0';
		FIFO_FULL			<= '1';
		FIFO_written_words	<= "111111111";
		
		wait for CLK_PERIOD1;
		
		--reset values
		async_reset;
		
		--wait for a while to see if the DMA reacts
		wait for 3*clk_period;
		
		--tell the DMA to start transmission but the FIFO is not ready
		wait until rising_edge(CLK);
		START_READ			<= '1';
		wait for 3*clk_period;
		
		--toy with the DMA through FIFO signals
		test_interract_FIFO;
		
		--interract with the Avalon bus
		test_Avalon_react_to_dut(x"00000005", x"0000000F", "01"); --1
		
		wait for 2*clk_period;
		FIFO_written_words 			<= "000000000";
		--Do it as many times as is needed for a whole picture: 3 more times. I'll leave it for 4 to see
		--2
		test_Avalon_react_to_dut(x"00000055", x"000000FF", "00"); 
		
		--3
		test_Avalon_react_to_dut(x"00000555", x"00000FFF", "10"); --3
		wait for 5*clk_period;
		FIFO_FULL 					<= '0';
	
		--4
		test_Avalon_react_to_dut(x"00005555", x"0000FFFF", "11"); --4
		wait for 5*clk_period;
		FIFO_FULL 					<= '0';	
		FIFO_written_words			<= "000000000";
		
		--5
		test_Avalon_react_to_dut(x"00055555", x"000FFFFF", "00"); --5

	end process simulation;

end test;