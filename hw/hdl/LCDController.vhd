library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--------------------------------------------------------------------------------------------
--												Entity Initialization											--
--------------------------------------------------------------------------------------------
entity LCD is
port(

	clk 				: 	in std_logic;
	nReset 			:	in std_logic;
	
	-- External interface (ILI9341).
	CSX 				: 	out std_logic;
	RESX				: 	out std_logic;
	DCX 				: 	out std_logic;
	WRX 				: 	out std_logic;
	RDX 				: 	out std_logic;
	data				:	out std_logic_vector(15 downto 0);
	
	-- Internal interface (Registers).
	write_RQ			: 	in std_logic;
	cmd_data			:	in std_logic_vector(31 downto 0);
	wait_LCD			: 	out std_logic;

	
	-- Internal interface (LCD block).
	start_read		: 	out std_logic;
	
	-- Internal interface (FIFO) 
	read_FIFO		:	out std_logic;
	read_data_FIFO :	in std_logic_vector(31 downto 0);
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
	constant write_mem_cont_cmd:	std_logic_vector(7 downto 0) := "00111100";

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
					if write_RQ = '1' then
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
							wait_twrl 	<= "11";
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
								
								when others => 
									wait_twrl <=wait_twrl-1;
									
							end case; --wait_twrl
								
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
								wait_twrl <= "11";
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
									
									when others => 
										wait_twrl <=wait_twrl-1;
								end case; --wat_twrl
						end case; --send_state
					end if; --cmd_data = (0)
					
					
				
				when SendImg	=>			--This State does the same as SendData, however, it reads from the FIFO instead

					--wait for data to be available from the FIFO, and then write it to the ILI9341
					case px_send_state is
						when WaitData	=>
							if FIFO_empty = '0' then
								read_FIFO <= '1';
								px_send_state <= SendData;
							end if;
							
						when SendData	=>
							--reset read_FIFO signal until ready to send again
							read_FIFO <= '0';
							
							--read the pending data from FIFO
							current_data				<= read_data_FIFO;
							
							--send the data From FIFO
							case send_state is
								when Config 	=>
									RESX	<=	'1';
									CSX	<=	'0';
									DCX	<= '1';	--send Data
									WRX 	<= '0';	--set up write trigger
									wait_twrl <= "11";
									send_state	<= Trigger;    --once the wires are configured for correct communication
								when Trigger	=>
									case wait_twrl is
									
										--if the 4 cycles 'wait for write cycle L' are up, trigger the send and go to next state
										when "00"	=>
											WRX	<= '1';
											send_state <= Config;			--reinitialize sending
											px_send_state <= WaitData; 	--go back to reading from the FIFO
										--this state ensures that the data in current_data is on the conduit	
										when "11"	=>
											data	<=	current_Data(15 downto 0);
											wait_twrl <= wait_twrl-1;
										when others => 
											wait_twrl <=wait_twrl-1;
									end case; --wait_twrl
							end case; --send_state 
					end case; --px_send_state
			end case; --LCD_state
		end if;
	end process;
end behavior;
