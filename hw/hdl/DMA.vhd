library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--------------------------------------------------------------------------------------------
--												Entity Initialization											--
--------------------------------------------------------------------------------------------
entity MasterController is
port(

	clk 				: 	in std_logic;
	nReset 			:	in std_logic;
	
	-- External interface (i.e. Avalon Bus).
	AM_Address		:	out std_logic_vector(31 downto 0);
	AM_read	 		: 	out std_logic;
	AM_wait			: 	in std_logic;
	readdatavalid	: 	in std_logic;	
	read_data 		: 	in std_logic_vector(31 downto 0);
	brustcount		: 	out std_logic_vector(4 downto 0);


	-- Internal interface (LCD block).
	start_read		: 	in std_logic;
	
	-- Internal interface (Registers block).
	mem_addr			:	in std_logic_vector(31 downto 0);
	img_read			:	out std_logic;
	
	-- Internal interface (FIFO) 
	write_FIFO		:	out std_logic;
	write_data_FIFO:	out std_logic_vector(31 downto 0);
	FIFO_full		: 	in std_logic;
	FIFO_almost_full: in std_logic

);
end MasterController;






--------------------------------------------------------------------------------------------
--											Architecture Definition												--
--------------------------------------------------------------------------------------------

--------------------------------------------------
--Architecture of the Master Controller
--
--Comments:
architecture behavior of MasterController is

	--define constants for the DMA
	constant burstcount_constant:	std_logic_vector(4 downto 0) := "10100"; --20
	constant address_increment	 : std_logic_vector(6 downto 0) := "1010000"; --80
	constant nb_rows_of_pixels  :	std_logic_vector(7 downto 0) := "11110000"; --240
	constant nb_burst_per_row   :	std_logic_vector(2 downto 0) := "111"; --7



	--define state machine types
	type DMA_states_type		 			is (Idle, WaitFIFO, ReadRqAM, ReadData);	--This is the global state type	
	
	--Define state machines
	signal DMA_state						:	DMA_states_type;
	
	--Define variable signals and counters
	signal current_memory_address		:	std_logic_vector(31 downto 0);
	signal row_counter					:  std_logic_vector(7 downto 0);
	signal burst_iter						:  std_logic_vector(4 downto 0);
	signal burst_counter					:	std_logic_vector(2 downto 0);
	signal new_image						:  std_logic;

begin
	--Reset all signals
	process(nReset)
	begin
		if nReset = '0' then
			DMA_state			 		<= Idle;
			current_memory_address 	<= mem_addr;
			row_counter					<=	(others => '0');
			burst_iter 					<= (others => '0');
			burst_counter				<= (others => '0');
			new_image					<= '1';
		end if;
	end process;

	--Main Process
	process(clk)
	begin
		if rising_edge(clk) then
			--State machine goes from Idle, to Waiting for the FIFO to the ready for data, to requesting and 
			--waiting for data from the avalon bus to actually reading that data to the FIFO
			case DMA_state is
				when Idle 			=>			--In Idle state, the DMA does nothing but wait for the start trigger from the LCD
					if start_read = '1' then
						DMA_state <= WaitFIFO;
					end if;
					
				when WaitFIFO 		=>			--In this state, the DMA waits for the FIFO to be ready to receive data
					if (FIFO_full = '0') and (FIFO_almost_full = '0') then
						DMA_state 					<= ReadRqAM;
						if new_image = '1' then
							current_memory_address 	<= mem_addr;
							new_image 					<= '0';
							row_counter 				<= "00000000";
						else 
							current_memory_address 	<= current_memory_address + address_increment;
							burst_counter				<= burst_counter + 1;
						end if;
					end if;
				
				when ReadRqAM		=>			--In this state, the DMA waits for the AM bus to be ready to send Data
					AM_read 		<= '1';
					AM_Address 	<= current_memory_address;
					
					if AM_wait = '0' then
						DMA_state 	<= ReadData;
						burst_iter  <= "00000";
						AM_read 		<= '0';
					end if; --AM_wait
						
					
				when ReadData		=>			--In this state, DMA write data to the FIFO every time readdatavalid is high
					write_FIFO 			<= readdatavalid;
					write_data_FIFO 	<= read_data;
					
					if readdatavalid = '1' then
					
						if burst_iter = burstcount_constant-1 then
						
							if burst_counter = nb_burst_per_row then
							
								row_counter <= row_counter + 1;
								
								if row_counter = nb_rows_of_pixels-1 then
									DMA_state 		<= Idle;
									new_image 		<= '1';
									img_read			<= '1';
								end if;	--img finished
								
							end if; -- row finished
							
							DMA_state	 	<= WaitFIFO;
							
						end if; --burst finished
						burst_iter		<= burst_iter + 1;
						
					end if; --word finished
				
			end case; --DMA_state
		end if; --rising edge(clk)
	end process; --state machine
end behavior;