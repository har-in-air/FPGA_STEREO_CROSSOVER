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

signal iir_state : integer := 0;

--signals for multiplier
signal s_mult_in_a 	: signed (c_IIR_NBITS-1 downto 0) 	:= (others=>'0');
signal s_mult_in_b 	: signed (c_IIR_NBITS-1 downto 0) 	:= (others=>'0');
signal s_mult_out 	: signed (2*c_IIR_NBITS-1 downto 0)	:= (others=>'0');

--temp regs and delay regs
signal s_temp 		: signed ((c_IIR_NBITS+8)-1 downto 0)   := (others=>'0');
signal s_temp_in 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');
signal s_in_z1 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');
signal s_in_z2 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');

signal s_out_z1_hpf 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');
signal s_out_z2_hpf 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');

signal s_out_z1_lpf 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');
signal s_out_z2_lpf 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');

signal s_iir_hpf 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');
signal s_iir_lpf 	: signed (c_IIR_NBITS-1 downto 0)	:= (others=>'0');

begin

o_iir_lpf <= s_iir_lpf;
o_iir_hpf <= s_iir_hpf;

-- multiplier
process(s_mult_in_a, s_mult_in_b)
begin
s_mult_out <= s_mult_in_a * s_mult_in_b;
end process;

-- With mck = 256 * fs, we have plenty of clocks to work with before the next frame starts.
-- Here we're using 15 clocks for the 2-way lpf and hpf filters.
-- For a 3-way crossover, double that as we would need another lpf and hpf for the bandpass filter

process (i_mck)
begin
if (rising_edge(i_mck)) then    

	--start process when valid sample arrives
    if (i_sample_valid = '1' and iir_state = 0) then
        -- load multiplier with samplein * i_hp_a0
        s_mult_in_a	<= i_iir;
        s_temp_in	<= i_iir;
        s_mult_in_b <= i_hp_a0;
        iir_state		<= 1;
        o_busy		<= '1';

    elsif (iir_state = 1) then
        --save result of (samplein * i_hp_a0) to temp and apply right-shift of 30
        --and load multiplier with in_z1 and i_hp_a1
        s_temp		<= resize(shift_right(s_mult_out, c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= i_hp_a1;
        iir_state		<= 2;

     elsif (iir_state = 2) then
        --save and sum up result of (in_z1 * i_hp_a1) to temp and apply right-shift of 30
        --and load multiplier with in_z2 and i_hp_a2
        s_temp		<= s_temp + resize(shift_right(s_mult_out, c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= i_hp_a2;
        iir_state		<= 3;

         
      elsif (iir_state = 3) then
        --save and sum up result of (in_z2 * i_hp_a2) to temp and apply right-shift of 30
        -- and load multiplier with out_z1_hpf and i_hp_b1
        s_temp		<= s_temp + resize(shift_right(s_mult_out, c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_out_z1_hpf;
        s_mult_in_b	<= i_hp_b1;
        iir_state		<= 4;

      elsif (iir_state = 4) then
        --save and sum up (negative) result of (out_z1_hpf * i_hp_b1) and apply right-shift of 30
        --and load multiplier with out_z2_hpf and i_hp_b2
        s_temp		<= s_temp - resize(shift_right(s_mult_out, c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_out_z2_hpf;
        s_mult_in_b	<= i_hp_b2;
        iir_state		<= 5;

      elsif (iir_state = 5) then
        --save and sum up (negative) result of (out_z2_hpf * i_hp_b2) and apply right-shift of 30
        s_temp	<= s_temp - resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        iir_state	<= 6;
        
      elsif (iir_state = 6) then
        --save result to output_HPF, save all HPF output delay registers
        s_iir_hpf		<= resize(s_temp, c_IIR_NBITS);
        s_out_z1_hpf	<= resize(s_temp, c_IIR_NBITS);
        s_out_z2_hpf	<= s_out_z1_hpf;
		  iir_state			<= 7;

		elsif (iir_state = 7) then
        -- load multiplier with samplein * i_lp_a0
        s_mult_in_a	<= i_iir;
        s_temp_in	<= i_iir;
        s_mult_in_b	<= i_lp_a0;
        iir_state		<= 8;

     elsif (iir_state = 8) then
        --save result of (samplein* i_lp_a0) to temp and apply right-shift of 30
        --and load multiplier with in_z1 and i_lp_a1
        s_temp		<= resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= i_lp_a1;
        iir_state		<= 9;

     elsif (iir_state = 9) then
        --save and sum up result of (in_z1 * i_lp_a1) to temp and apply right-shift of 30
        --and load multiplier with in_z2 and i_lp_a2
        s_temp		<= s_temp + resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= i_lp_a2;
        iir_state		<= 10;

         
      elsif (iir_state = 10) then
        --save and sum up result of (in_z2 * i_lp_a2) to temp and apply right-shift of 30
        -- and load multiplier with out_z1_lpf and i_lp_b1
        s_temp		<= s_temp + resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_out_z1_lpf;
        s_mult_in_b	<= i_lp_b1;
        iir_state		<= 11;

      elsif (iir_state = 11) then
        --save and sum up (negative) result of (out_z1_lpf * i_lp_b1) and apply right-shift of 30
        --and load multiplier with out_z2_lpf and i_lp_b2
        s_temp		<= s_temp - resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        s_mult_in_a	<= s_out_z2_lpf;
        s_mult_in_b	<= i_lp_b2;
        iir_state		<= 12;

      elsif (iir_state = 12) then
        --save and sum up (negative) result of (out_z2_lpf * i_lp_b2) and apply right-shift of 30
        s_temp		<= s_temp - resize(shift_right(s_mult_out,c_IIR_NBITS-2), c_IIR_NBITS+8);
        iir_state		<= 13;
        
      elsif (iir_state = 13) then
        --save result to output_LPF, save all LPF output delay registers
		  -- save input delay registers
        s_iir_lpf		<= resize(s_temp, c_IIR_NBITS);
        s_out_z1_lpf	<= resize(s_temp, c_IIR_NBITS);
        s_out_z2_lpf	<= s_out_z1_lpf;
        s_in_z2			<= s_in_z1;
        s_in_z1			<= s_temp_in;
        o_sample_valid	<= '1';
        iir_state			<= 14;
        
      elsif (iir_state = 14) then
        o_sample_valid	<= '0';
        iir_state			<= 0;
        o_busy			<= '0';
      end if;      

end if;
end process;
end Behavioral;
