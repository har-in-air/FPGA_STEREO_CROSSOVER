----------------------------------------------------------------------------------
-- github.com/har-in-air , stereo 2-way crossover filter with dynamically loadable
-- filter coefficients
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.all;
use work.params.all;

entity top is
	port (
	-- global clock and reset
	i_clk_50Mhz	: in std_logic;
	i_rstn		: in std_logic;

	-- i2s slave interface (mck, bck, ws from external source)
	i_mck		: in std_logic;	 
	i_bck		: in std_logic;
	i_ws		: in std_logic;
	i_sdi		: in std_logic;  -- stereo input left on ws=0, right on ws=1
	o_sdo_l		: out std_logic; -- left channel with LPF on ws=0, HPF on ws=1
	o_sdo_r		: out std_logic; -- right channel with LPF on ws=0, HPF on ws=1
	
	-- spi slave interface for loading filter coefficients
	i_ssn		: in std_logic;
	i_sclk		: in std_logic;
	i_mosi		: in std_logic;
	o_miso		: out std_logic	
	);
end top;

architecture rtl of top is

-- signals for coefficient loading
signal s_coeff_addr 	: natural range 0 to c_NCOEFFS-1 := 0;
signal s_coeff_data 	: std_logic_vector(c_COEFF_NBITS-1 downto 0);
signal s_coeffs_rdy  	: std_logic := '0';
signal s_coeffs_rdy_sync : std_logic_vector(1 downto 0) := (others => '0'); 

--type coeff_t is signed(c_COEFF_NBITS-1 downto 0);
type coeff_array_t is array(0 to c_NCOEFFS-1) of signed(c_COEFF_NBITS-1 downto 0);
signal s_coeff_array : coeff_array_t := (others => (others => '0'));


type state_tbl_t is (ST_IDLE, ST_ADDR, ST_DATA);
signal state_tbl : state_tbl_t := ST_IDLE;


begin

inst_audiosystem : entity work.audiosystem
port map (
	i_rstn	=> i_rstn,
	i_mck	=> i_mck,
	i_bck	=> i_bck,
	i_ws	=> i_ws,
	i_sdi	=> i_sdi, -- input stereo l+r   
	o_sdo_l	=> o_sdo_l, -- output left lpf + hpf
	o_sdo_r	=> o_sdo_r, -- output right lpf + hpf

-- s=44.1khz, fc=340hz, q= 0.707
	
--	-- LPF biquad coefficients
--	i_lp0_b0 =>  40D"155887665",
--	i_lp0_b1 => 40D"311775331",
--	i_lp0_b2 => 40D"155887665",
--	i_lp0_a1 => -40D"530929086023",
--	i_lp0_a2 => 40D"256674729741",
--	     
--	-- HPF biquad coefficients
--	i_hp0_b0 => 40D"265620430677",
--	i_hp0_b1 => -40D"531240861354",
--	i_hp0_b2 => 40D"265620430677",
--	i_hp0_a1 => -40D"530929086023",
--	i_hp0_a2 => 40D"256674729741",
	
	-- LPF0 biquad coefficients
	i_lp0_b0 => s_coeff_array(0),
	i_lp0_b1 => s_coeff_array(1),
	i_lp0_b2 => s_coeff_array(2),
	i_lp0_a1 => s_coeff_array(3),
	i_lp0_a2 => s_coeff_array(4),
	     
	-- LPF1 biquad coefficients
	i_lp1_b0 => s_coeff_array(5),
	i_lp1_b1 => s_coeff_array(6),
	i_lp1_b2 => s_coeff_array(7),
	i_lp1_a1 => s_coeff_array(8),
	i_lp1_a2 => s_coeff_array(9),
	
	-- HPF0 biquad coefficients
	i_hp0_b0 => s_coeff_array(10),
	i_hp0_b1 => s_coeff_array(11),
	i_hp0_b2 => s_coeff_array(12),
	i_hp0_a1 => s_coeff_array(13),
	i_hp0_a2 => s_coeff_array(14),

	-- HPF1 biquad coefficients
	i_hp1_b0 => s_coeff_array(15),
	i_hp1_b1 => s_coeff_array(16),
	i_hp1_b2 => s_coeff_array(17),
	i_hp1_a1 => s_coeff_array(18),
	i_hp1_a2 => s_coeff_array(19)
	);
	
inst_load_coeffs : entity work.load_coeffs 
port map (
	i_rstn			=> i_rstn,
	i_clk_sys		=> i_clk_50Mhz,

	-- external spi interface
	i_ssn				=> i_ssn,
	i_sclk			=> i_sclk,
	i_mosi			=> i_mosi,
	o_miso			=> o_miso,

	-- internal audiosystem interface 
	i_coeff_addr		=> s_coeff_addr,
	o_coeff_data		=> s_coeff_data,
	o_coeffs_rdy		=> s_coeffs_rdy
	);

proc_sync_coeff_rdy : process(i_clk_50Mhz) is
begin
	if rising_edge(i_clk_50Mhz) then      
		s_coeffs_rdy_sync <= s_coeffs_rdy_sync(0) & s_coeffs_rdy;
	end if;
end process;
	
	
proc_load_coeffs : process(i_clk_50Mhz) is
begin
	if rising_edge(i_clk_50Mhz) then      
		case state_tbl is
      	when ST_IDLE =>
			s_coeff_addr <= 0; 
			if s_coeffs_rdy_sync = b"01" then
				state_tbl <= ST_ADDR;
			else
				state_tbl <= ST_IDLE;
			end if;

		when ST_ADDR =>
			state_tbl <= ST_DATA;

		when ST_DATA =>
			s_coeff_array(s_coeff_addr) <= signed(s_coeff_data);
			if s_coeff_addr = c_NCOEFFS-1 then
				state_tbl <= ST_IDLE;
			else
				s_coeff_addr <= s_coeff_addr + 1;
				state_tbl <= ST_ADDR;
			end if;
		end case;
	end if;
end process;
	
end rtl;
