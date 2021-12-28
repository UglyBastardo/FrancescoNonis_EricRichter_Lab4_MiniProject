library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--------------------------------------------------------------------------------------------
--												Entity Initialization											--
--------------------------------------------------------------------------------------------
entity LCD is
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
end LCD;
	
	
		



--------------------------------------------------------------------------------------------
--											Architecture Definition												--
--------------------------------------------------------------------------------------------


--------------------------------------------------
--Architecture of LCD
--
architecture behavior of LCD is

	-- define constants
	constant write_mem_cont_cmd:	std_logic_vector(15 downto 0) := x"002C";

	-- define state machine types
	type lcd_states_type		 		is (Idle, InterpretData, SendData, FetchPixelFromFIFO);	--This is the global state type
	
	--Define state machines
	signal lcd_state						:	lcd_states_type;
	
	--Define useful signals to momentarily store data and a timing counter
	signal current_data						:	std_logic_vector(31 downto 0);
	signal wait_twrl						: 	std_logic_vector(1 downto 0); --4 cycles for twrl (write control pulse L duration)
	signal ready							:   std_logic; --a timing signal
	signal done								:   std_logic; --a signal to tell the LCD_controller that a total image has been read.
	
begin
	
	-- state machine
	process(clk, nReset)
	begin
		if nReset = '0' then
			lcd_state			<= Idle;
			current_data		<= (others => '0');
			wait_twrl 			<= (others => '0');
			ready 				<= '0';

			--reset outputs
			CSX					<= '1';
			--RESX				<= '0';
			DCX 				<= '1';
			WRX 				<= '1';
			RDX 				<= '0';
			data				<= (others => '0');
			wait_LCD			<= '0';
			start_read			<= '0';
			read_FIFO			<= '0';


		elsif rising_edge(clk) then
			case lcd_state is
			
				--In this state, the LCD waits for a new command
				when Idle 		=>
					--done 			<= '1';
					CSX				<= '0';			--stop ignoring wrx and data lines
					--RESX			<= '1';			--stop resetting the ILI9341

					if ready = '0' then
					wait_LCD 		<= '0';			--enable new read from avalon bus
					ready 			<= '1';

					--if a write is pending, start the state machine
					elsif write_RQ = '1' then
						current_data		<= cmd_data;  		--read the pending data
						wait_LCD			<= '1';		  		--disable new read from avalon bus
						lcd_state			<= InterpretData;	--Go to interpretation state
						ready 				<= '0';
					end if;
				
			
				--In this state, the LCD send a command. It then redirects
				when InterpretData 	=>
					CSX			<= '0';
					WRX 		<= '0';			--set up write trigger
					wait_twrl 	<= "11";		--set up the timer for write low's 4 cycles

					if current_data(16) = '0' then 	--configure cmd transmission
						DCX			<= '0';			--send command adress
						data		<= x"0000" + current_data(7 downto 0);
						if current_data = write_mem_cont_cmd then
							start_read	<= '1';					--enable DMA read from avalon memory
						end if;
					else 
						DCX			<= '1';			--send command Data
						data		<= cmd_data(15 downto 0);
					end if;

					lcd_state	<= SendData;    	--once the wires are configured for correct communication 

				--In this state, the data is simply put on the lines during correct timings
				--Also, if the command is to send pixels, then this state sets the machine to that state (FIFO then back etc...)
				when SendData 		=>
					start_read 			<= '0';
					if wait_twrl = "00" then
						WRX				<= '1';						
						--if the cmd is to write pixels
						if current_data = write_mem_cont_cmd then
							lcd_state	<= FetchPixelFromFIFO;	--to sending pictures instead of configuration data
						else 
							lcd_state 	<= Idle;				--just wait for next avalon info
						end if;
													
					else 
						wait_twrl <= wait_twrl-1; 		 --decrement counter

					end if;

				--This state reads from the FIFO to fetch the data needed
				when FetchPixelFromFIFO	=>								
					
					if wait_twrl = "11" then	--if we just set the wait_twrl signal
						--configure sending
						CSX				<= '0';
						DCX				<= '1';
						WRX 			<= '0';			--set up write trigger
						read_FIFO 		<= '0';			   --reset read_FIFO to avoid missing data
						wait_twrl 		<= "10";

					elsif wait_twrl = "10" then

						data			<= x"0000" + read_data_FIFO; --read from FIFO
						lcd_state   	<= SendData;	   --send Data from FIFO
						
					--wait for data to be available from the FIFO
					elsif FIFO_empty = '0' then

						read_FIFO 		<= '1';			--send read signal
						wait_twrl 		<= "11";		--set up the timer for write low's 4 cycles
					
					elsif done = '1' then
						lcd_state 		<= Idle;

					end if;
					

			end case; --LCD_state
		end if; --rising_edge(clk)
	end process;--DMA_state_machine


	--check if a full img is over
	process(clk)
	begin
		
		if LCD_state = Idle then
			done <= '0';
		end if;
		
		if rising_edge(clk) then
			if img_read = '1' then
				done <= '1';
			end if;
		end if;
	end process;


end behavior;
