----------------------------------------------------------------------------------
-- Engineer: github.com/YetAnotherElectronicsChannel
-- modified : github.com/har-in-air for 2-way active xover, using 40bit (2.38)
-- fixed point arithmetic as opposed to 32bit (2.30) as I want the additional
-- fractional resolution for low frequency crossovers where some of the coefficients
-- can be small values.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.params.all;

entity xover_iir is
port (
    i_mck		: in std_logic := '0';
    
    i_iir		: in signed (c_IIR_NBITS-1 downto 0) := (others=>'0');
    i_sample_valid  : in std_logic := '0';
    
    o_iir_lpf	: out signed(c_IIR_NBITS-1 downto 0) := (others=>'0');
    o_iir_hpf	: out signed(c_IIR_NBITS-1 downto 0) := (others=>'0');
    o_sample_valid : out std_logic := '0';
    
    o_busy		: out std_logic := '0';

	-- a0, a1, a2, b1, b2 must be multiplied with 2^(c_IIR_NBITS-2) before
 
    i_lp_a0		: signed (c_IIR_NBITS-1 downto 0) := (others=>'0');
    i_lp_a1		: signed (c_IIR_NBITS-1 downto 0) := (others=>'0');
    i_lp_a2		: signed (c_IIR_NBITS-1 downto 0) := (others=>'0');
    i_lp_b1		: signed (c_IIR_NBITS-1 downto 0) := (others=>'0');
    i_lp_b2		: signed (c_IIR_NBITS-1 downto 0) := (others=>'0');
    
    i_hp_a0		: signed (c_IIR_NBITS-1 downto 0) := (others=>'0');
    i_hp_a1		: signed (c_IIR_NBITS-1 downto 0) := (others=>'0');
    i_hp_a2		: signed (c_IIR_NBITS-1 downto 0) := (others=>'0');
    i_hp_b1		: signed (c_IIR_NBITS-1 downto 0) := (others=>'0');
    i_hp_b2		: signed (c_IIR_NBITS-1 downto 0) := (others=>'0')
    );
end xover_iir;


architecture Behavioral of xover_iir is

--iir filter state machine
signal iir_state	: integer := 0;

--multiplier signals
signal s_mult_in_a	: signed (c_IIR_NBITS-1 downto 0) 	:= (others=>'0');
signal s_mult_in_b	: signed (c_IIR_NBITS-1 downto 0) 	:= (others=>'0');
signal s_mult_out	: signed (2*c_IIR_NBITS-1 downto 0)	:= (others=>'0');

--accumulator
signal s_accum		: signed ((c_IIR_NBITS+8)-1 downto 0)   := (others=>'0');

--registered input
signal s_iir_in		: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');

--delay registers
signal s_in_z1		: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');
signal s_in_z2		: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');

--signal s_lpfx_z1 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');
--signal s_lpfx_z2 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');

--signal s_hpfx_z1 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');
--signal s_hpfx_z2 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');

signal s_out_hpf_z1 : signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');
signal s_out_hpf_z2 : signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');

signal s_out_lpf_z1 : signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');
signal s_out_lpf_z2 : signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');

--registered outputs
signal s_iir_hpf 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');
signal s_iir_lpf 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');

begin

o_iir_lpf <= s_iir_lpf;
o_iir_hpf <= s_iir_hpf;

--synthesis tool infers built-in multiplier
process(s_mult_in_a, s_mult_in_b)
begin
s_mult_out <= s_mult_in_a * s_mult_in_b;
end process;

-- With mck = 256 * fs, we have plenty of clocks to work with before the next frame starts.
-- Here we're using 15 clocks for the 2-way lpf and hpf filters.
-- For a 3-way crossover, double that as we would need another lpf and hpf for the bandpass filter

proc_iir_sm : process (i_mck)
begin
if (rising_edge(i_mck)) then    
	case iir_state is
	when 0 =>
	--start process when valid sample arrives
    if (i_sample_valid = '1') then
        -- load multiplier with i_iir, i_hp_a0
        s_mult_in_a	<= i_iir;
        s_iir_in	<= i_iir;
        s_mult_in_b <= i_hp_a0;
        iir_state	<= 1;
        o_busy		<= '1';
    else
    	iir_state <= 0;
    end if;

    when 1 =>
        --save resized result of (i_iir * i_hp_a0) to accum
        --load multiplier with in_z1 and i_hp_a1
        s_accum		<= resize(shift_right(s_mult_out, c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= i_hp_a1;
        iir_state	<= 2;

    when 2 =>
        --accumulate resized result of (in_z1 * i_hp_a1) 
        --load multiplier with in_z2 and i_hp_a2
        s_accum		<= s_accum + resize(shift_right(s_mult_out, c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= i_hp_a2;
        iir_state	<= 3;

    when 3 =>
        --accumulate resized result of (in_z2 * i_hp_a2)
        --load multiplier with out_z1_hpf and i_hp_b1
        s_accum		<= s_accum + resize(shift_right(s_mult_out, c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_out_hpf_z1;
        s_mult_in_b	<= i_hp_b1;
        iir_state	<= 4;

  	when 4 => 
        --accumulate negative resized result of (out_z1_hpf * i_hp_b1)
        --load multiplier with out_z2_hpf and i_hp_b2
        s_accum		<= s_accum - resize(shift_right(s_mult_out, c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_out_hpf_z2;
        s_mult_in_b	<= i_hp_b2;
        iir_state	<= 5;
	
    when 5 =>
        --accumulate negative resized result of (out_z2_hpf * i_hp_b2)
        s_accum		<= s_accum - resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        iir_state	<= 6;
        
    when 6 =>
        --save resized accumulator to output_HPF
        --save HPF output delay registers
        s_iir_hpf		<= resize(s_accum, c_IIR_NBITS);
        s_out_hpf_z1	<= resize(s_accum, c_IIR_NBITS);
        s_out_hpf_z2	<= s_out_hpf_z1;
		iir_state		<= 7;

	when 7 =>
        -- load multiplier with i_iir * i_lp_a0
        s_mult_in_a	<= i_iir;
        s_iir_in	<= i_iir;
        s_mult_in_b	<= i_lp_a0;
        iir_state	<= 8;

    when 8 =>
        --save resized result of (i_iir * i_lp_a0) in accum
        --load multiplier with in_z1 and i_lp_a1
        s_accum		<= resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= i_lp_a1;
        iir_state	<= 9;

    when 9 =>
        --accumulate resized result of (in_z1 * i_lp_a1)
        --load multiplier with in_z2 and i_lp_a2
        s_accum		<= s_accum + resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= i_lp_a2;
        iir_state	<= 10;

    when 10 =>
        --accumulate resized result of (in_z2 * i_lp_a2)
        --load multiplier with out_z1_lpf and i_lp_b1
        s_accum		<= s_accum + resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_out_lpf_z1;
        s_mult_in_b	<= i_lp_b1;
        iir_state	<= 11;

    when 11 =>
        --accumulate negative resized result of (out_z1_lpf * i_lp_b1)
        --load multiplier with out_z2_lpf and i_lp_b2
        s_accum		<= s_accum - resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_out_lpf_z2;
        s_mult_in_b	<= i_lp_b2;
        iir_state	<= 12;

    when 12 =>
        --accumulate negative result of (out_z2_lpf * i_lp_b2)
        s_accum		<= s_accum - resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        iir_state	<= 13;
        
    when 13 =>
        --save resized accumulator to output_LPF
        --save LPF output delay registers
		--save input delay registers
        s_iir_lpf		<= resize(s_accum, c_IIR_NBITS);
        s_out_lpf_z1	<= resize(s_accum, c_IIR_NBITS);
        s_out_lpf_z2	<= s_out_lpf_z1;
        s_in_z2			<= s_in_z1;
        s_in_z1			<= s_iir_in;
        o_sample_valid	<= '1';
        iir_state		<= 14;
        
    when 14 =>
      	--reset output valid pulse and busy flag
      	--return to idle
        o_sample_valid	<= '0';
        o_busy			<= '0';
        iir_state		<= 0;
    
    when others =>
    	iir_state <= 0;     

	end case;
end if;
end process;
end Behavioral;
