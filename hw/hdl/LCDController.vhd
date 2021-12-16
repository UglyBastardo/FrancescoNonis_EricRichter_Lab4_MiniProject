library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


--------------------------------------------------------------------------------------------
--												Entity Initialization											--
--------------------------------------------------------------------------------------------
entity Registers is
port(

	clk 				: 	in std_logic;
	nReset 			:	in std_logic;

	-- Internal interface (i.e. Avalon slave).
	AS_address 		: 	in std_logic_vector(1 downto 0);
	AS_write 		: 	in std_logic;
	AS_writedata 	: 	in std_logic_vector(31 downto 0);

	-- External interface (i.e. Avalon Bus).
	AS_wait 			: 	out std_logic_vector;
	AS_IRQ 			: 	out std_logic_vector;
	
	-- Internal interface (LCD block).
	write_RQ		: 	out std_logic_vector;
	cmd_data			:	out std_logic_vector(31 downto 0);
	wait_LCD			: 	in std_logic_vector;

	-- Internal interface (Master Controller Block).
	mem_addr			:	out std_logic_vector(31 downto 0);
	img_read			:	in std_logic_vector;
	
	);
end Registers;
	


entity LCD is
port(

	clk 				: 	in std_logic;
	nReset 			:	in std_logic;
	
	-- External interface (ILI9341).
	CSX 				: 	out std_logic_vector;
	RESX				: 	out std_logic_vector;
	DCX 				: 	out std_logic_vector;
	WRX 				: 	out std_logic_vector;
	RDX 				: 	out std_logic_vector;
	data				:	out std_logic_vector(15 downto 0);
	
	-- Internal interface (Registers).
	write_RQ			: 	in std_logic_vector;
	cmd_data			:	in std_logic_vector(31 downto 0);
	wait_LCD			: 	out std_logic_vector;

	
	-- Internal interface (LCD block).
	start_read		: 	out std_logic_vector;
	
	-- Internal interface (FIFO) 
	read_FIFO		:	out std_logic;
	read_data_FIFO :	in std_logic_vector(31 downto 0);
	FIFO_Empty		: 	in std_logic_vector;


	
	);
end LCD;
	
	
		
entity MasterController is
port(

	clk 				: 	in std_logic;
	nReset 			:	in std_logic;
	
	-- Internal interface (i.e. DMA).
	-- External interface (i.e. Avalon Bus).
	AM_Address		:	out std_logic_vector(31 downto 0);
	AM_read	 		: 	out std_logic;
	AM_wait			: 	in std_logic_vector;
	readdatavalid	: 	in std_logic_vector;	
	read_data 		: 	in std_logic_vector(31 downto 0);
	brustcount		: 	out std_logic_vector(4 downto 0);


	-- Internal interface (LCD block).
	start_read		: 	in std_logic_vector;
	
	-- Internal interface (Registers block).
	mem_addr			:	in std_logic_vector(31 downto 0);
	img_read			:	out std_logic_vector;
	
	-- Internal interface (FIFO) 
	write_FIFO		:	 out std_logic;
	write_data_FIFO:	out std_logic_vector(31 downto 0);
	FIFO_full		: 	in std_logic_vector;
	FIFO_almost_full: in std_logic_vector;

	);
end MasterController;



--------------------------------------------------------------------------------------------
--											Architecture Definition												--
--------------------------------------------------------------------------------------------


--------------------------------------------------
--Architecture of LCD
--
--Comments:
--This here state machine is a bit different from the state machine in the report
--There is no way back to Idle...
--There is also no way to go back to any other state once the send_image state starts...
--I fon't understant how to get back to it... Should go back as soon as a whole picture is sent? That measn we just need to implement a counter.
--
--Also, I supposed the read signal would trigger the full or almost full signal. Is that the case?
architecture behavior of LCD is

	-- define constants
	constant write_mem_cont_cmd:	std_logic_vector(7 downto0) := "00111100";

	-- define state machine types
	type lcd_states_type		 			is (Idle, Command, SendData, SendImg);	--This is the global state type
	type px_send_states_type 			is (WaitData, SendData);					--Alternates between the two when requesting from Fifo and reading/sending pixels from it
	type send_states_type				is (Config, Trigger);						--Alternates between the two states when setting up the lines then sending the data through
	
	
	--Define state machines
	signal lcd_state						:	lcd_states_type;
	signal px_send_state					:  px_send_states_type;
	signal send_state						: 	send_states_type;
	
	--Define useful signals to momentarily store data and a timing counter
	signal current_data					:	std_logic_vector(31 downto 0);
	signal wait_twrl						: 	std_logic_vector(1 downto 0); --4 cycles for twrl (write control pulse L duration)
	
begin
	
	--Reset all signals
	process(nReset)
	begin
		if nReset = '0' then
			lcd_state			 	<= Idle;
			send_state				<= Config;
			px_send_state			<= WaitData;
			current_data			<= (others => '0');
			wait_twrl 				<= (others => '0');
		end if;
	end process;
	
	-- state machine
	process(clk)
	begin
		if rising_edge(clk) then
			case lcd_state is
			
				when Idle 		=>
				
					--if a write is pending, start the state machine
					if write_RQ then
						lcd_state			<=	Command;
					end if;
				
			
		
		
				when Command 	=>
					
					--read the pending data from Registers and request wait until the data is processed
					current_data				<= cmd_data;
					wait_LCD						<= '1';						--disable new read from avalon bus
					case send_state is
						when Config 	=>								--configure lines so that the camera can interpret the sent data correctly
							RESX	<=	'1';
							CSX	<=	'0';
							DCX	<= '0';	--send command
							WRX 	<= '0';	--set up write trigger
							wait_twrl 	<= 3;
							data			<=	current_data(7 downto 0);
							send_state	<= Trigger;    --once the lines are configured for the camera 

						
						when Trigger	=>
							case wait_twrl is
							
								--if the 4 cycles wait for write cycle L are up, trigger the send and go to next state
								when "00"	=>
									WRX	<= '1';
									wait_LCD 	<= '0';			--enable new read from avalon bus
									send_state <= Config;
									
									--if the cmd is to write pixels
									if current_data = write_mem_cont_cmd then
										start_read	<= '1';			--enable DMA read from avalon memory
										lcd_state	<= SendImg;		--to sending pictures instead of configuration data
											
									--if the cmd is to write LCD configurations	
									else
										lcd_state	<= SendData;	--to sending configuration data
										wait_LCD 	<= '0';			--enable new read from avalon bus
									
									end if;
										
								--this state ensures that the data in current_data is on the conduit
								when "11"	=>						--this state ensures that the data in current_data is on the conduit
									data	<=	current_Data(15 downto 0);
									wait_twrl <= wait_twrl-1;
								
								others => 
									wait_twrl <=wait_twrl-1;
									
							end case; --wait_twrl
								
							--if the write cycle time is not up
							else 
								wait_twrl <= wait_twrl-1;
							end if; --wait_twrl
					end case; --send_state
				
				
				
				
				when SendData 	=>				--This state simply sends the data for configuration of the ILI9341
					
					--if the new data is actually a command
					if cmd_data(16) = '0' then
						lcd_state	<= Command;
					else
						
						--read the pending data from Registers and request wait until the data is processed
						current_data				<= cmd_data;
						wait_LCD						<= '1';					--disable new read from avalon bus
						case send_state is
							when Config 	=>
								RESX	<=	'1';
								CSX	<=	'0';
								DCX	<= '1';	--send Data
								WRX 	<= '0';	--set up write trigger
								wait_twrl <= 3;
								data	<=	cmd_data(15 downto 0);
								send_state	<= Trigger;    --once the wires are configured for correct communication 

							
							when Trigger	=>
								case wait_twrl is
									--if the 4 cycles wait for write cycle L are up, trigger the send and go to next state
									when "00"	=>
										WRX	<= '1';
										wait_LCD 	<= '0';			--enable new read from avalon bus
										send_state <= Config;
										
									--this state ensures that the data in current_data is on the conduit
									when "11"	=>						--this state ensures that the data in current_data is on the conduit
										data	<=	current_Data(15 downto 0);
										wait_twrl <= wait_twrl-1;
									
									others => 
										wait_twrl <=wait_twrl-1;
								end case; --wat_twrl
						end case; --send_state
					end if; --cmd_data = (0)
					
					
				
				when DataImg	=>			--This State does the same as SendData, however, it reads from the FIFO instead

					--wait for data to be available from the FIFO, and then write it to the ILI9341
					case px_send_state is
						when WaitData	=>
							read_FIFO <= '1';
							px_send_state <= SendData;
							
						when SendData	=>
							read_FIFO <= '0';
							if FIFO_Empty then
								px_send_state <= WaitData;
							else
								--read the pending data from FIFO
								current_data				<= read_data_FIFO;
								
								--send the data From FIFO
								case send_state is
									when Config 	=>
										RESX	<=	'1';
										CSX	<=	'0';
										DCX	<= '1';	--send Data
										WRX 	<= '0';	--set up write trigger
										wait_twrl <= 3;
										send_state	<= Trigger;    --once the wires are configured for correct communication

									when Trigger	=>
										case wait_twrl is
										
											--if the 4 cycles 'wait for write cycle L' are up, trigger the send and go to next state
											when "00"	=>
												WRX	<= '1';
												send_state <= Config;
											when "11"	=>						--this state ensures that the data in current_data is on the conduit
												data	<=	current_Data(15 downto 0);
												wait_twrl <= wait_twrl-1;
											others => 
												wait_twrl <=wait_twrl-1;
										end case; --wait_twrl
								end case; --send_state 
							end if; --FIFO_empty
					end case; --px_send_state
			end case; --LCD_state
		end if;
	end process;
end behavior;

--------------------------------------------------
--Architecture of the Master Controller
--
--Comments:
--Again, I considered the write_FIFO to trigger the Full/Almost full signal. Is that the case?
architecture behavior of MasterController is

	--define state machine types
	type DMA_states_type		 			is (Idle, WaitFIFO, ReadRqAM, ReadData);	--This is the global state type
	type write_FIFO_states_type		is (WaitData, SendData);						--Alternates between the two when requesting from Fifo and reading/sending pixels from it

	--Define state machines
	signal DMA_state						:	DMA_states_type;
	signal write_FIFO_state				:  write_FIFO_states_type;

begin
	--Reset all signals
	process(nReset)
	begin
		if nReset = '0' then
			DMA_state			 	<= Idle;
			
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			case DMA_state is
				when Idle 			=>			--In Idle state, the DMA does nothing but wait for the start trigger from the LCD
					if start_read = '1' then
						DMA_state <= WaitFIFO;
					end if;
					
				when WaitFIFO 		=>			--In this state, the DMA waits for the FIFO to be ready to receive data
					case write_FIFO_state is
						when WaitData =>
							write_FIFO <= '1';
						when SendData =>
							write_FIFO <= '0';
							if ((FIFO_full = '0') and (FIFO_almost_full = '0')) then
								DMA_state <= ReadRqAM;
							else
								write_FIFO_state <= WaitData;
							end if;
					end case;
				
				when ReadRqAM		=>			--In this state, the DMA waits for the AM bus to be ready to send Data
					
					
				when ReadData		=>
			end case; --DMA_state
		end if; --rising edge(clk)
	end process; --state machine
end behavior;