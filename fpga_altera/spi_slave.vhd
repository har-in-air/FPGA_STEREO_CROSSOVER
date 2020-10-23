-----------------------------------------------------------------------------------
-- github.com/har-in-air  spi slave interface for loading 2-way active crossover coefficients
-----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library work;
use work.all;
use work.params.all;

entity spi_slave is
  port(
	-- system 
	i_clk		: in std_logic; -- system clock
	i_rstn		: in std_logic; -- system active low reset-active low reset

	-- spi 
	i_sclk		: in std_logic; --spi clk from master
	i_ssn		: in std_logic; --active low slave select
	i_mosi		: in std_logic; --master out, slave in
	i_tx_load	: in std_logic; -- tx buffer load
	i_tx_data	: in std_logic_vector(c_COEFF_NBITS-1 downto 0);  -- tx data to load in tx buffer

	o_miso		: out std_logic := 'Z'; --master in, slave out
	o_rx_cmd_rdy	: out std_logic;  --received command valid
	o_rx_data_rdy	: out std_logic;  --received data valid
	o_rx_buf	: out std_logic_vector(c_COEFF_NBITS+c_CMD_NBITS-1 downto 0) := (others => '0');  --receive buffer
	o_frame_active 	: out std_logic
	); 
end spi_slave;

architecture logic of spi_slave is

signal s_bit_index	: integer range -1 to c_COEFF_NBITS+c_CMD_NBITS-1;

signal s_rx_buf		: std_logic_vector(c_COEFF_NBITS+c_CMD_NBITS-1 downto 0) := (others => '0');  --receive buffer
signal s_tx_buf		: std_logic_vector(c_COEFF_NBITS+c_CMD_NBITS-1 downto 0) := (others => '0');  --transmit buffer


signal s_sclk_reg	: std_logic_vector(2 downto 0) := (others => '0');
signal s_ssn_reg 	: std_logic_vector(2 downto 0) := (others => '1');
signal s_mosi_reg	: std_logic_vector(1 downto 0) := (others => '0');

signal s_sclk_rising 	: std_logic := '0';
signal s_sclk_falling 	: std_logic := '0';

signal s_start_frame 	: std_logic := '0';
signal s_frame_active	: std_logic := '0';
signal s_mosi		: std_logic := '0';

begin
  o_rx_cmd_rdy 	<= '1' when s_bit_index = c_COEFF_NBITS-1 else '0';
  o_rx_data_rdy <= '1' when s_bit_index = -1 else '0';

  o_rx_buf		<= s_rx_buf;

  s_sclk_rising 	<= '1' when s_sclk_reg(2 downto 1) = b"01" else '0';
  s_sclk_falling 	<= '1' when s_sclk_reg(2 downto 1) = b"10" else '0';
  
  s_start_frame 	<= '1' when s_ssn_reg(2 downto 1) = b"10" else '0';
  s_frame_active 	<= '1' when s_ssn_reg(1) = '0' else '0';
  o_frame_active	<= s_frame_active;

  s_mosi 		<= s_mosi_reg(1);
  
proc_reg_signals : process(i_clk, i_rstn) 
begin
	if i_rstn = '0' then
		s_sclk_reg <= (others => '0');
		s_ssn_reg <= (others => '1');
		s_mosi_reg <= (others => '0');
	elsif rising_edge(i_clk) then
		s_sclk_reg <= s_sclk_reg(1 downto 0) & i_sclk;
		s_ssn_reg <= s_ssn_reg(1 downto 0) & i_ssn;
		s_mosi_reg <= s_mosi_reg(0) & i_mosi;
	end if;
end process;

--- bit_index
proc_bitindex : process(i_clk, i_rstn) 
begin
	if i_rstn = '0' then
		s_bit_index <= c_COEFF_NBITS+c_CMD_NBITS-1;         --reset miso/mosi bit position to msb
	elsif rising_edge(i_clk) then
		if s_start_frame = '1' then
			s_bit_index <= c_COEFF_NBITS+c_CMD_NBITS-1;         --reset miso/mosi bit position to msb			
		end if;
		if s_sclk_falling = '1'  then            --new bit on miso/mosi
			s_bit_index <= s_bit_index - 1;            --shift active bit indicator down
		end if;
	end if;
end process;


-- slave receive register
proc_rxbuf : process(i_clk, i_rstn)
begin      
	if i_rstn = '0' then
		s_rx_buf <= (others => '0');
	elsif rising_edge(i_clk) then
		if s_sclk_rising = '1' and s_frame_active = '1' then
			s_rx_buf(s_bit_index) <= s_mosi;
		end if;
	end if;
end process;	 
	 

--miso output register
proc_miso : process(i_clk, i_rstn)
begin
	if i_rstn = '0' then
		o_miso <= 'Z';
	elsif rising_edge(i_clk) then
		if s_frame_active = '0' then
			o_miso <= 'Z';
		elsif s_sclk_rising = '1' then
			o_miso <= s_tx_buf(s_bit_index);   --setup data bit for master to read on falling edge of sclk
		end if;
	end if;
end process;
	
--slave transmit register
proc_txbuf : process(i_clk, i_rstn)
begin
	if i_rstn = '0' then
		s_tx_buf <= (others => '0');
	elsif rising_edge(i_clk) then
		if i_tx_load = '1' then  
			s_tx_buf <= x"00" & i_tx_data;
		end if;
	end if;
end process;

  
end logic;
