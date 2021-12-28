library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--------------------------------------------------------------------------------------------
--												Entity Initialization											--
--------------------------------------------------------------------------------------------
entity MasterController is
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
	constant burstcount_constant:	std_logic_vector(4 downto 0) := "10011"; --0 to 19 is 20 iterations
	constant address_increment	 : std_logic_vector(6 downto 0) := "1010000"; --80

	constant nb_rows_of_pixels  :	std_logic_vector(7 downto 0) := "11101111"; --0 to 239 is 240 iterations
--	constant nb_rows_of_pixels  :	std_logic_vector(7 downto 0) := "00000001"; --0 to 1 rows for test

	constant nb_burst_per_row   :	std_logic_vector(2 downto 0) := "111"; --0 to 7	is 8 iterations
--	constant nb_burst_per_row   :	std_logic_vector(2 downto 0) := "001"; --0 to 1 bursts per row ... for test




	--define state machine types
	type DMA_states_type		 			is (Idle, WaitFIFO, ReadRqAM, ReadData);	--This is the global state type	
	
	--Define state machines
	signal DMA_state						:	DMA_states_type;
	
	--Define variable signals and counters
	signal current_memory_address		:  std_logic_vector(31 downto 0);
	signal row_counter					:  std_logic_vector(7 downto 0);
	signal burst_iter					:  std_logic_vector(4 downto 0);
	signal burst_counter				:  std_logic_vector(2 downto 0);
	signal new_image					:  std_logic;
	signal AM_rq_ready					:  std_logic;
	signal reading						:  std_logic;

begin

	--Main Process
	process(clk, nReset)
	begin		
		if nReset = '0' then			
			--reset signals
			--DMA_state			 		<= Idle;
			current_memory_address 		<= (others => '0');
			row_counter					<= (others => '0');
			burst_iter 					<= (others => '0');
			burst_counter				<= (others => '0');
			new_image					<= '1';
			AM_rq_ready					<= '0';
			reading 					<= '0';

			
			--reset outputs
			AM_Address 					<=	(others => '0');
			AM_read						<= '0';
			burstcount					<= (others => '0');
			img_read					<= '0';
			write_FIFO					<= '0';
			write_data_FIFO			<= (others => '0');
	 
		elsif rising_edge(clk) then
			--State machine goes from Idle, to Waiting for the FIFO to the ready for data, to requesting and 
			--waiting for data from the avalon bus to actually reading that data to the FIFO
			case DMA_state is
				when Idle 			=>					--In Idle state, the DMA does nothing but wait for the start trigger from the LCD
					write_FIFO <= '0';
					img_read <= '0';
					if start_read = '1' then
						reading			<= '1'; --reinit img_read for new reading of image
					elsif reading = '1' then 	--if the start_read command was set, start reading a picture from memory and do not stop until the picture is read or a reset is issued
						DMA_state 		<= WaitFIFO;
					end if;
					
				when WaitFIFO 		=>			--In this state, the DMA waits for the FIFO to be ready to receive data
					--reset write_FIFO so as to not write when unexpected
					write_FIFO 			<= readdatavalid;
					
					--test if enough space in FIFO
					--if (FIFO_full = '0') and (FIFO_almost_full = '0') then
					if (FIFO_full = '0') and (unsigned(FIFO_written_words) <= 491) then
					
						if new_image = '1' then
							current_memory_address 	<= mem_addr;
							AM_Address 					<= mem_addr;
							new_image 					<= '0';
							row_counter 				<= (others => '0');
							burst_counter				<= (others => '0');
						else 
							current_memory_address 	<= current_memory_address + address_increment;
							AM_Address					<= current_memory_address + address_increment;
						end if;
						
						--go to next state
						DMA_state 			<= ReadRqAM;
						AM_read 			<= '1';
						burstcount  		<= burstcount_constant + 1;
					end if;
				
				when ReadRqAM		=>			--In this state, the DMA waits for the AM bus to be ready to send Data
						
					if AM_wait = '0' then --Avalon bus is ready to send data
						DMA_state 						<= ReadData;
						burst_iter  					<= (others => '0');
						AM_read 						<= '0';
						AM_rq_ready 					<= '0';
					end if; --AM_wait
						
					
				when ReadData		=>			--In this state, DMA write data to the FIFO every time readdatavalid is high
					write_FIFO 			<= readdatavalid;
					write_data_FIFO(31 downto 16) 	<= read_data(15 downto 0);
					write_data_FIFO(15 downto 0) 	<= read_data(31 downto 16);
					
					--read the data
					if readdatavalid = '1' then
					
						--when a burst is finished
						if burst_iter = burstcount_constant then
	

							-- when a row is finished
							if burst_counter = nb_burst_per_row then
								
								
								--when the whole image is read
								if row_counter = nb_rows_of_pixels then
									DMA_state 		<= Idle;
									new_image 		<= '1';
									img_read		<= '1';
									reading			<= '0';
								else --just go back to waiting on the FIFO to be ready
									DMA_state	 	<= WaitFIFO;
								end if;	--img finished
								
								--reset burst counter
								burst_counter 	<= (others => '0');
							
								--increase row counter
								row_counter 	<= row_counter + 1;
								
							else --just go back to the FIFO to be ready
								DMA_state	 	<= WaitFIFO;

							end if; -- row finished
							
							burst_counter <= burst_counter + 1;
						end if; --burst finished
						burst_iter		<= burst_iter + 1;
						
					end if; --word finished
				
			end case; --DMA_state
		end if; --rising edge(clk)
	end process; --state machine
end behavior;