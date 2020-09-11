-------------------------------------------------------------------------------------------
-- github.com/har-in-air  state machine for loading filter coefficients via slave spi interface
---------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library work;
use work.all;
use work.params.all;

entity load_coeffs is 
port (
-- global clock and reset
	i_clk_sys  : in std_logic;
	i_rstn : in std_logic := '1';

-- external spi interface
	i_ssn  : in std_logic := '1';
	i_sclk : in std_logic := '0';
	i_mosi : in std_logic := '0';
	o_miso : out std_logic := '0';

-- internal system interface 
	i_clk_audio : in std_logic;
	i_reg_addr : in natural range 0 to c_NUM_REGS-1 := 0;
	o_reg_data : out std_logic_vector(c_REG_NBITS-1 downto 0);

	o_reg_rdy : out std_logic
	);
end entity;


architecture rtl of load_coeffs is

-- wires to spi_slave
signal s_tx_load   : std_logic := '0';
signal s_tx_data : std_logic_vector(c_REG_NBITS-1 downto 0) := (others => '0');
signal s_rx_buf  : std_logic_vector(c_REG_NBITS+c_CMD_NBITS-1 downto 0) := (others => '0');  --receive buffer
signal s_rx_data_rdy    : std_logic := '0';
signal s_rx_cmd_rdy    : std_logic := '0';

signal s_command : std_logic_vector(3 downto 0) := (others => '0');

-- dpram with asynchronous clocks for a and b side
-- a side, i_clk_sys, read/write by this module to load coefficients
signal s_dpram_addr_a 	: natural range 0 to c_NUM_REGS-1 := 0;
signal s_dpram_data_a 	: std_logic_vector(c_REG_NBITS-1 downto 0) := (others=>'0');
signal s_dpram_q_a 		: std_logic_vector(c_REG_NBITS-1 downto 0) := (others=>'0');
signal s_dpram_we_a 	: std_logic := '0';

-- b side, i_clk_audio, read only by audiosystem module
signal s_dpram_addr_b 	: natural range 0 to c_NUM_REGS-1 := 0;
signal s_dpram_data_b 	: std_logic_vector(c_REG_NBITS-1 downto 0) := (others=>'0');
signal s_dpram_q_b 		: std_logic_vector(c_REG_NBITS-1 downto 0) := (others=>'0');
signal s_dpram_we_b 		: std_logic := '0';

signal s_reg_rdy : std_logic := '0';

signal s_frame_active : std_logic := '0';  

-- state machine
type state_top_t is (IDLE, CMD, WT_WR_DATA, WR_DATA, RD_DATA, TX_DATA, WT_CS);
signal state_top : state_top_t := IDLE;

begin
	-- b side of dpram used as audiosystem read-only 16x32 memory for coefficients (only first 10 entries used)
	s_dpram_addr_b 	<= i_reg_addr;
	o_reg_data 		<= s_dpram_q_b;
	-- pulse used to notify audiosystem that the table has been loaded with new filter coefficients
	o_reg_rdy <=  s_reg_rdy;

	
inst_spi_slave : ENTITY work.spi_slave
PORT map(
	i_clk		=> i_clk_sys,
	i_rstn		=> i_rstn,
	i_sclk    	=> i_sclk,
	i_ssn		=> i_ssn,
	i_mosi		=> i_mosi,
	i_tx_load	=> s_tx_load,
	i_tx_data	=> s_tx_data,

	o_miso		=> o_miso,
	o_rx_cmd_rdy	=> s_rx_cmd_rdy,
	o_rx_data_rdy	=> s_rx_data_rdy,
	o_rx_buf		=> s_rx_buf,
	o_frame_active	=> s_frame_active
	);
    
inst_dpram : entity work.dpram_async_clks
port map(	
	clk_a	=> i_clk_sys,
	clk_b	=> i_clk_audio,
	d_a		=> s_dpram_data_a,
	addr_a	=> s_dpram_addr_a,
	we_a	=> s_dpram_we_a,
	q_a		=> s_dpram_q_a,
	d_b		=> s_dpram_data_b, 
	addr_b	=> s_dpram_addr_b,
	we_b	=> s_dpram_we_b,
	q_b		=> s_dpram_q_b
	);

	
-- state machine for processing spi master commands
-- top byte (7:4) = command. 1 = write register, 2 = read register, 3 = notify audiosystem of loaded coefficients
-- top byte (3:0) = dpram register index 0 - 15
-- lower 4 bytes = 32-bit signed 2's complement coefficient data in 2.30 format

proc_spi_transaction : process (i_clk_sys, i_rstn)
begin 
if i_rstn = '0' then
	state_top <= IDLE;
	s_dpram_we_a <= '0';
	s_dpram_we_b <= '0';
	s_reg_rdy <= '0';
	s_command <= (others => '0');
	s_tx_load <= '0';
	s_tx_data <= (others => '0');
elsif rising_edge(i_clk_sys) then      
	case state_top is
	when IDLE =>
		if s_rx_cmd_rdy = '1' then
			s_command <= s_rx_buf(c_REG_NBITS+7 downto c_REG_NBITS+4);
			s_dpram_addr_a <= to_integer(unsigned(s_rx_buf(c_REG_NBITS+3 downto c_REG_NBITS)));
			state_top <=  CMD;
		else 
			state_top <= IDLE;
		end if;
	
				
	when CMD =>
		if s_command = X"1" then   -- command : write dpram register		
   			state_top <= WT_WR_DATA;
		elsif s_command = X"2" then   -- command : read dpram register
			s_dpram_we_a <= '0';
	  		state_top <= RD_DATA; -- read data from dpram register
		elsif s_command = X"3" then -- command : 'registers loaded', notify audiosystem
			s_reg_rdy <= '1';
	  		state_top <= WT_CS;
		else
   			state_top <= IDLE;
	  	end if;
	  		
	when WT_WR_DATA => -- on reception of data_rdy synchronized flag
		if s_rx_data_rdy = '1' then 		
	  		s_dpram_data_a <= s_rx_buf(c_REG_NBITS-1 downto 0);
	  		state_top <= WR_DATA; 
		else 
			state_top <= WT_WR_DATA;
		end if;
			  		
	when WR_DATA =>
  		s_dpram_we_a <= '1'; -- dpram_data_a and dpram_addr_a buses are stable, generate write pulse
  		state_top <= WT_CS;
  		
	
	when RD_DATA => -- allow one clock for dpram_q_a output
		state_top <= TX_DATA;

	when TX_DATA => -- load spi slave txbuf with dpram data, with next spi sclk, the data is sent on miso line
		s_tx_data <= s_dpram_q_a;	  	
		s_tx_load <= '1';	
		state_top <= WT_CS; 

	when WT_CS => -- reset pulses and wait until spi bus is idle
		s_dpram_we_a <= '0';  -- reset write pulse 
      	s_tx_load <= '0'; -- reset load pulse     
		s_reg_rdy <= '0'; -- reset system read ready pulse	   
		if s_frame_active = '0' then
			state_top <= IDLE;
		else
			state_top <= WT_CS;
		end if;

	end case;
end if;			  	    
	  	   
end process;

end architecture rtl;

