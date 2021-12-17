library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Avalon_Slave is

	port(
			--Avalon Slave interface signals
			clk				: in std_logic;
			nReset			: in std_logic;
			AS_Address  	: in std_logic_vector(1 downto 0);
			AS_write    	: in std_logic;
			AS_Writedata	: in std_logic_vector(31 downto 0);
			AS_Wait			: out std_logic;
			AS_IRQ			: out std_logic;
			AS_Read			: in std_logic;
			AS_ReadData		: out std_logic_vector(31 downto 0);
			
			--Interface with Avalon Master
			Memory_Address : out std_logic_vector(31 downto 0);
			Img_sent			: in std_logic;
			AM_nReset		: out std_logic;
			
			--Interface with the LCD control module
			LCD_write		: out std_logic;
			Cmd_Data			: out std_logic_vector(31 downto 0);
			LCD_wait			: in std_logic;
			LCD_nReset		: out std_logic
			
	);

end Avalon_Slave;




architecture AS of Avalon_Slave is

	--Register inteface
	signal Command_data_reg		: std_logic_vector(31 downto 0);
	signal Memory_address_reg	: std_logic_vector(31 downto 0);
	signal Img_read_reg			: std_logic_vector(31 downto 0);
	
	--type declaration for state machine handling
	type  AS_state is (Idle, Write_LCD_control);
	
	signal current_state 		: AS_state; 
	signal transfer_started    : std_logic;


begin 

   ------------------------------------------------------------------------------------------------
	--Avalon Slave interface processes
	------------------------------------------------------------------------------------------------
	
	process (clk, nReset)
	
	begin 
		
		--reset procedure
		if nReset = '0' then
			
			--transfer the reset to the other modules
			LCD_nReset		<= '0';
			AM_nReset		<= '0';
			
			--setting the signals to safe values
			AS_IRQ 			<= '0';
			Memory_Address <= (others => '0');
			
		
		
		elsif rising_edge(clk) then
			
			--the CPU writes to one of the registers
			if AS_write = '1' then
				
				case AS_Address is
					
					when "00" => Command_data_reg 	   <= AS_Writedata;
					
					when "01" => Memory_Address 	<= AS_Writedata;
									 Memory_address_reg <= AS_Writedata;
					when "10" => Img_read_reg <= AS_Writedata;
					when others => null;
				
				end case;
			
			end if;
			
			--Interface with the DMA
			
			if Img_sent = '1' then
			
			 Img_read_reg <= x"00000001";
			
			end if;
		
		end if;
	
	end process;
	
	
	-------------------------------------------------------------------------------------------------
	--Avalon slave read from register
	-------------------------------------------------------------------------------------------------
	process(clk, nReset)
	
	begin
		if nReset = '1' then
			
			AS_ReadData <= (others => '0');
			
		
		elsif rising_edge(clk) then
			
			if AS_Read = '1' then
				
				case AS_Address is
					when "00" => AS_ReadData <= Command_data_reg;
					when "01" => AS_ReadData <= Memory_address_reg;
					when "10" => AS_ReadData <= Img_read_reg;
					when others => null;
					
				end case;
			
			end if;		
		
		
		end if;
	
	
	end process;
	
	
	---------------------------------------------------------------------------------------
	--Interface with the LCD control module, here lies the state machine of the module
	---------------------------------------------------------------------------------------
	process(clk, nReset)
	
	begin
		
		--if there is a reset we pull down the AS wait signal
		if nReset = '0' then
		
			AS_Wait 			<= '0';
			LCD_write		<= '0';
			Cmd_Data			<= (others => '0');
			current_state	<= Idle;
			transfer_started <= '0';
			

			
		elsif rising_edge(clk) then 
		
			--update the state of the machine
			if AS_write = '1' then
				if AS_Address = "00" then
					current_state 	<= Write_LCD_control;
				end if;
			
			end if;
		
			--State machine
			case current_state is 
				
				--In the idle state we do nothing, we simply wait for the CPU to start a transfer
				when Idle => null;
				
				--In this state we make the transfer with the LCD control
				when Write_LCD_control => 
				
						--if haven't started writing, start the writing if LCD is not busy
						if (transfer_started = '0') and (LCD_wait = '0') then
						
								AS_Wait				<= '1';
								Cmd_data 			<= Command_data_reg;
								LCD_write 			<= '1';
								transfer_started	<= '1';
						
						--check when the writing has finished
						elsif (transfer_started = '1') and (LCD_wait = '0') then
								transfer_started 	<= '0';
								current_state 		<= Idle;
								AS_Wait				<= '0';
								
						--if LCD control is busy we wait it to be free
						elsif  LCD_wait = '1' then
								AS_wait <= '1';
						
						end if;
					  
			end case;
		
		end if;
	
	end process;


end AS;