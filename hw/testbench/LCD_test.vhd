library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_LCD is

end tb_LCD;


architecture test of tb_LCD is 

	--clock characteristics
	constant clk_period	: time  := 20 ns;
	constant CLK_PERIOD1: time 	:= 100 ns;
	
	signal CLK 			: 	std_logic;
	signal NRESET		:	std_logic;
	
	-- External interface (ILI9341).
	signal CS_X			: 	std_logic;
	signal RES_X		: 	std_logic;
	signal DC_X			: 	std_logic;
	signal WR_X			: 	std_logic;
	signal RD_X			: 	std_logic;
	signal DATA			:	std_logic_vector(15 downto 0);
	
	-- Internal interface (Registers).
	signal WRITE_RQ		: 	std_logic;
	signal CMD_DATA		:	std_logic_vector(31 downto 0);
	signal WAIT_LCD		: 	std_logic;

	
	-- Internal interface (LCD block).
	signal START_READ	: 	std_logic;
	signal IMG_READ     :   std_logic;
	
	-- Internal interface (FIFO) 
	signal READ_FIFO	:	std_logic;
	signal READ_DATA_FIFO:	std_logic_vector(15 downto 0);
	signal FIFO_EMPTY	: 	std_logic;
	
	
	
begin 

	dut : entity work.lcd
		port map(
			CLK 			=> clk,
			NRESET			=> nReset,
			CSX				=> CS_X,
			RESX			=> RES_X,
			DCX				=> DC_X,
			WRX				=> WR_X,
			rdx				=> RD_X,
			DATA 			=> data,
			WRITE_RQ		=> write_RQ,
			CMD_DATA 		=> CMD_data,
			WAIT_LCD		=> wait_LCD,
			START_READ		=> start_read,
			read_FIFO		=> READ_FIFO,
			READ_DATA_FIFO	=> read_data_FIFO,
			FIFO_empty		=> FIFO_EMPTY,
			img_read		=> IMG_READ);
			
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
		procedure sync_reset is
			begin
				wait until rising_edge(CLK);
				wait for CLK_PERIOD1 / 2;
				NRESET <= '0';
				
				wait for CLK_PERIOD1 / 2;
				NRESET <= '1';
			end procedure sync_reset;
		
		--Avalon react to DMA test procedure
		procedure simulate_FIFO(
			constant read_data1: in std_logic_vector(15 downto 0)
			) is
			
			begin
				FIFO_EMPTY <= '1';
				wait for 7*clk_period;

				FIFO_EMPTY <= '0';
				wait until rising_edge(READ_FIFO);
				READ_DATA_FIFO <= read_data1;
				wait for clk_period;
				wait until rising_edge(CLK);
				FIFO_EMPTY <= '1';
			end procedure simulate_FIFO;
				
		procedure simulate_send_cmd_or_data(
			constant command: in std_logic_vector(31 downto 0)
			) is
			begin
				wait until rising_edge(CLK);
				WRITE_RQ <= '1';
				CMD_DATA <= command;
				wait until rising_edge(CLK);
				WRITE_RQ <= '0';
			end procedure simulate_send_cmd_or_data;

		procedure simulate_send_img_cmd(
			constant img_cmd: std_logic_vector(31 downto 0) := x"0000003C"
			) is
			begin
				wait until rising_edge(CLK);
				WRITE_RQ <= '1';
				CMD_DATA <= img_cmd;
				wait until rising_edge(CLK);
				WRITE_RQ <= '0';
			end procedure simulate_send_img_cmd;

		constant cmdones : std_logic_vector(31 downto 0) := x"013000FF";
		constant cmd1pair: std_logic_vector(31 downto 0) := x"00304FAA";
		constant datones : std_logic_vector(31 downto 0) := x"0001FFFF";
		constant dat1pair: std_logic_vector(31 downto 0) := x"0341AAAA";
		constant pixel1  : std_logic_vector(15 downto 0) := x"05AF";
		constant pixel2  : std_logic_vector(15 downto 0) := x"8888";
		constant pixel3  : std_logic_vector(15 downto 0) := x"FFFF";

	begin
		--default values
		NRESET 				<= '1';
		FIFO_EMPTY			<= '1';
		
		--reset values
		sync_reset;
		
		--wait for a while to see if the LCD reacts
		wait for 3*clk_period;
		
		--Send a cmd
		wait until rising_edge(CLK);
		simulate_send_cmd_or_data(cmdones);

		wait until WAIT_LCD = '0';
		simulate_send_cmd_or_data(cmd1pair);

		wait until WAIT_LCD = '0';
		simulate_send_cmd_or_data(datones);

		wait until WAIT_LCD = '0';
		simulate_send_cmd_or_data(dat1pair);

		wait until WAIT_LCD = '0';
		simulate_send_img_cmd;
		
		wait until rising_edge(CLK);
		simulate_FIFO(pixel1);
		wait until rising_edge(CLK);
		simulate_FIFO(pixel2);
		wait until rising_edge(CLK);
		simulate_FIFO(pixel3);
		wait for 20*CLK_PERIOD1;

	end process simulation;
end test;