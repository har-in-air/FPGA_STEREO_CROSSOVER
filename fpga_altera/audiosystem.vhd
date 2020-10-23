----------------------------------------------------------------------------------
-- Engineer: github.com/YetAnotherElectronicsChannel
-- modified : github.com/har-in-air for 2-way active xover with slave i2s interface
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.params.all;

entity audiosystem is
port (
	i_rstn	: in std_logic;
	i_mck  	: in std_logic;
	i_bck 	: in std_logic;
	i_ws		: in std_logic;

	i_sdi 	: in std_logic;
	o_sdo_l 	: out std_logic;
	o_sdo_r 	: out std_logic;

    i_lp0_b0	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_lp0_b1	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_lp0_b2	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_lp0_a1	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_lp0_a2	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    
    i_lp1_b0	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_lp1_b1	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_lp1_b2	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_lp1_a1	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_lp1_a2	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    
    i_hp0_b0	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_hp0_b1	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_hp0_b2	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_hp0_a1	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_hp0_a2	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    
    i_hp1_b0	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_hp1_b1	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_hp1_b2	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_hp1_a1	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0');
    i_hp1_a2	: signed (c_COEFF_NBITS-1 downto 0) := (others=>'0')
	);
	
end audiosystem;

architecture rtl of audiosystem is
 
--i2s data control signals
signal s_sync			: std_logic:= '0';

-- 24bit i2s input to IIR filters
--signal s_i2s_l_in_24 : signed (23 downto 0):= (others=>'0');
--signal s_i2s_r_in_24 : signed (23 downto 0):= (others=>'0');

--  IIR i/o signals
signal s_iir_l_in		: signed (c_DATA_NBITS-1 downto 0) := (others=>'0');
signal s_iir_r_in		: signed (c_DATA_NBITS-1 downto 0) := (others=>'0');

signal s_iir_l_lp_out : signed (c_DATA_NBITS-1 downto 0) := (others=>'0');
signal s_iir_l_hp_out : signed (c_DATA_NBITS-1 downto 0) := (others=>'0');

signal s_iir_r_lp_out : signed (c_DATA_NBITS-1 downto 0) := (others=>'0');
signal s_iir_r_hp_out : signed (c_DATA_NBITS-1 downto 0) := (others=>'0');

-- 24bit resized output from IIR Filters
--signal s_i2s_l_lp_out_24 : signed (23 downto 0):= (others=>'0');
--signal s_i2s_l_hp_out_24 : signed (23 downto 0):= (others=>'0'); 

--signal s_i2s_r_lp_out_24 : signed (23 downto 0):= (others=>'0');
--signal s_i2s_r_hp_out_24 : signed (23 downto 0):= (others=>'0');


--signal s_test : signed(23 downto 0) := x"800100";

begin

-- resize 32bit iir output to 24bits for I2S transmitter
-- resize => keep sign, truncate to 24bits
--s_i2s_l_lp_out_24 <= resize(s_iir_l_lp_out, 24);
--s_i2s_l_hp_out_24 <= resize(s_iir_l_hp_out, 24);

--s_i2s_r_lp_out_24 <= resize(s_iir_r_lp_out, 24);
--s_i2s_r_hp_out_24 <= resize(s_iir_r_hp_out, 24);

inst_i2s_rxtx_slave : entity work.i2s_rxtx_slave
port map (
	i_rstn	=> i_rstn,
	i_mck	=> i_mck,
	i_bck	=> i_bck,
	i_ws	=> i_ws,

	i_sdi	=> i_sdi,
--	o_l24	=> s_i2s_l_in_24,-- serial to parallel input to IIR filter left channel
--	o_r24	=> s_i2s_r_in_24,-- serial to parallel input to IIR filter right channel
	o_l24	=> s_iir_l_in,-- serial to parallel input to IIR filter left channel
	o_r24	=> s_iir_r_in,-- serial to parallel input to IIR filter right channel
	o_sync	=> s_sync,-- parallel o_l24 and o_r24 data valid  input to IIR filters
	
--	i_l_lp_24	=> s_i2s_l_lp_out_24,-- parallel output from IIR filter left LPF
--	i_l_hp_24	=> s_i2s_l_hp_out_24,-- parallel output from IIR filter left HPF
	i_l_lp_24	=> s_iir_l_lp_out,-- parallel output from IIR filter left LPF
	i_l_hp_24	=> s_iir_l_hp_out,-- parallel output from IIR filter left HPF

--	i_r_lp_24	=> s_i2s_r_lp_out_24,-- parallel output from IIR filter right LPF
--	i_r_hp_24	=> s_i2s_r_hp_out_24,-- parallel output from IIR filter right HPF
	i_r_lp_24	=> s_iir_r_lp_out,-- parallel output from IIR filter right LPF
	i_r_hp_24	=> s_iir_r_hp_out,-- parallel output from IIR filter right HPF
	

	-- for i2s transmitter  test
--	i_l_lp_24	=> s_test,
--	i_l_hp_24	=> s_test,
--
--	i_r_lp_24	=> s_test,
--	i_r_hp_24	=> s_test,
	
	o_sdo_l	=> o_sdo_l,	-- serial I2S stream left channel LPF on ws=0, HPF on ws=1
	o_sdo_r	=> o_sdo_r	-- serial I2S stream right channel LPF on ws=0, HPF on ws=1
	);
	

-- resize 24bit left channel input for 32bit data  to IIR filters

--s_iir_l_in <= resize(s_i2s_l_in_24, 32);

inst_xover_iir_left : entity work.xover_iir
	port map (
    i_mck				=> i_mck,
    
    i_iir				=> s_iir_l_in,
    i_sample_valid	=> s_sync,
    o_iir_hpf			=> s_iir_l_hp_out,
    o_iir_lpf			=> s_iir_l_lp_out,
    o_sample_valid	=> open,
    o_busy				=> open,

	 -- LPF coefficients
    i_lp0_b0				=> i_lp0_b0,
    i_lp0_b1				=> i_lp0_b1,
    i_lp0_b2				=> i_lp0_b2,
    i_lp0_a1				=> i_lp0_a1,
    i_lp0_a2				=> i_lp0_a2,

    i_lp1_b0				=> i_lp1_b0,
    i_lp1_b1				=> i_lp1_b1,
    i_lp1_b2				=> i_lp1_b2,
    i_lp1_a1				=> i_lp1_a1,
    i_lp1_a2				=> i_lp1_a2,

	 -- HPF coefficients
    i_hp0_b0				=> i_hp0_b0,
    i_hp0_b1				=> i_hp0_b1,
    i_hp0_b2				=> i_hp0_b2,
    i_hp0_a1				=> i_hp0_a1,
    i_hp0_a2				=> i_hp0_a2,    

    i_hp1_b0				=> i_hp1_b0,
    i_hp1_b1				=> i_hp1_b1,
    i_hp1_b2				=> i_hp1_b2,
    i_hp1_a1				=> i_hp1_a1,
    i_hp1_a2				=> i_hp1_a2    
    );


-- resize 24bit right channel input for  32bit data input to IIR filter
--s_iir_r_in <= resize(s_i2s_r_in_24, 32);

inst_xover_iir_right : entity work.xover_iir
	port map (
    i_mck				=> i_mck,
    
    i_iir				=> s_iir_r_in,
    i_sample_valid	=> s_sync,
    o_iir_hpf			=> s_iir_r_hp_out,
    o_iir_lpf			=> s_iir_r_lp_out,
    o_sample_valid	=> open,
    o_busy				=> open,
	
	 -- LPF coefficients
    i_lp0_b0				=> i_lp0_b0,
    i_lp0_b1				=> i_lp0_b1,
    i_lp0_b2				=> i_lp0_b2,
    i_lp0_a1				=> i_lp0_a1,
    i_lp0_a2				=> i_lp0_a2,

    i_lp1_b0				=> i_lp1_b0,
    i_lp1_b1				=> i_lp1_b1,
    i_lp1_b2				=> i_lp1_b2,
    i_lp1_a1				=> i_lp1_a1,
    i_lp1_a2				=> i_lp1_a2,

	 -- HPF coefficients
    i_hp0_b0				=> i_hp0_b0,
    i_hp0_b1				=> i_hp0_b1,
    i_hp0_b2				=> i_hp0_b2,
    i_hp0_a1				=> i_hp0_a1,
    i_hp0_a2				=> i_hp0_a2,    

    i_hp1_b0				=> i_hp1_b0,
    i_hp1_b1				=> i_hp1_b1,
    i_hp1_b2				=> i_hp1_b2,
    i_hp1_a1				=> i_hp1_a1,
    i_hp1_a2				=> i_hp1_a2  
    );
    
end rtl;

