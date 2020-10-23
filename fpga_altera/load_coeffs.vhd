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
	i_coeff_addr : in natural range 0 to c_NCOEFFS-1 := 0;
	o_coeff_data : out std_logic_vector(c_COEFF_NBITS-1 downto 0);

	o_coeffs_rdy : out std_logic
	);
end entity;


architecture rtl of load_coeffs is

-- wires to spi_slave
signal s_tx_load		: std_logic := '0';
signal s_tx_data 		: std_logic_vector(c_COEFF_NBITS-1 downto 0) := (others => '0');
signal s_rx_buf  		: std_logic_vector(c_COEFF_NBITS+c_CMD_NBITS-1 downto 0) := (others => '0');  --receive buffer
signal s_rx_data_rdy	: std_logic := '0';
signal s_rx_cmd_rdy	: std_logic := '0';

signal s_command		: std_logic_vector(2 downto 0) := (others => '0');

-- dpram
-- a side, spi read/write interface
signal s_dpram_addr_a	: natural range 0 to c_NCOEFFS-1 := 0;
signal s_dpram_data_a	: std_logic_vector(c_COEFF_NBITS-1 downto 0) := (others=>'0');
signal s_dpram_q_a		: std_logic_vector(c_COEFF_NBITS-1 downto 0) := (others=>'0');
signal s_dpram_we_a		: std_logic := '0';

-- b side, coefficient loader read-only interface
-- addr_b => i_coeff_addr, data_b => 0, we_b => 0

signal s_frame_active : std_logic := '0';  

-- state machine
type state_top_t is (IDLE, CMD, WT_WR_DATA, WR_DATA, RD_DATA, TX_DATA, WT_CS);
signal state_top : state_top_t := IDLE;

begin
	
inst_spi_slave : ENTITY work.spi_slave
PORT map(
	i_clk       => i_clk_sys,
	i_rstn		=> i_rstn,
	i_sclk    	=> i_sclk,
	i_ssn       => i_ssn,
	i_mosi		=> i_mosi,
	i_tx_load	=> s_tx_load,
	i_tx_data	=> s_tx_data,

	o_miso			=> o_miso,
	o_rx_cmd_rdy	=> s_rx_cmd_rdy,
	o_rx_data_rdy	=> s_rx_data_rdy,
	o_rx_buf        => s_rx_buf,
	o_frame_active	=> s_frame_active
	);
    
inst_dpram : entity work.dpram
port map(	
	clk		=> i_clk_sys,
	d_a		=> s_dpram_data_a,
	addr_a	=> s_dpram_addr_a,
	we_a    => s_dpram_we_a,
	q_a		=> s_dpram_q_a,
	d_b		=> X"0000000000", --s_dpram_data_b, 
	addr_b	=> i_coeff_addr, --s_dpram_addr_b,
	we_b    => '0', --s_dpram_we_b,
	q_b		=> o_coeff_data --s_dpram_q_b
	);

	
-- state machine for processing spi master commands
-- top byte (7:5) = command. 1 = write register, 2 = read register, 3 = notify audiosystem of loaded coefficients
-- top byte (4:0) = dpram register index
-- lower 5 bytes = 40-bit signed 2's complement coefficient data in 4.36 format

proc_spi_transaction : process (i_clk_sys, i_rstn)
begin 
if i_rstn = '0' then
	state_top <= IDLE;
	s_dpram_we_a <= '0';
	o_coeffs_rdy <= '0';
	s_command <= (others => '0');
	s_tx_load <= '0';
	s_tx_data <= (others => '0');
elsif rising_edge(i_clk_sys) then      
	case state_top is
	when IDLE =>
		if s_rx_cmd_rdy = '1' then
			s_command <= s_rx_buf(c_COEFF_NBITS+7 downto c_COEFF_NBITS+5);
			s_dpram_addr_a <= to_integer(unsigned(s_rx_buf(c_COEFF_NBITS+4 downto c_COEFF_NBITS)));
			state_top <=  CMD;
		else 
			state_top <= IDLE;
		end if;
	
				
	when CMD =>
		if s_command = b"001" then   -- command : write dpram register		
   			state_top <= WT_WR_DATA;
		elsif s_command = b"010" then   -- command : read dpram register
			s_dpram_we_a <= '0';
	  		state_top <= RD_DATA; -- read data from dpram register
		elsif s_command = b"011" then -- command : 'coefficients loaded', notify audiosystem
			o_coeffs_rdy <= '1';
	  		state_top <= WT_CS;
		else
   			state_top <= IDLE;
	  	end if;
	  		
	when WT_WR_DATA => -- on reception of data_rdy synchronized flag
		if s_rx_data_rdy = '1' then 		
	  		s_dpram_data_a <= s_rx_buf(c_COEFF_NBITS-1 downto 0);
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
		o_coeffs_rdy <= '0'; -- reset system read ready pulse	   
		if s_frame_active = '0' then
			state_top <= IDLE;
		else
			state_top <= WT_CS;
		end if;

	end case;
end if;			  	    
	  	   
end process;

end architecture rtl;

