----------------------------------------------------------------------------------
-- Engineer: github.com/YetAnotherElectronicsChannel
-- modified : github.com/har-in-air for 2-way active xover
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity xover_iir is
port (
    i_mck		: in std_logic := '0';
    
    i_iir		: in signed (31 downto 0) := (others=>'0');
    i_sample_valid  : in std_logic := '0';
    
    o_iir_lpf	: out signed(31 downto 0) := (others=>'0');
    o_iir_hpf	: out signed(31 downto 0) := (others=>'0');
    o_sample_valid : out std_logic := '0';
    
    o_busy		: out std_logic := '0';

	-- a0, a1, a2, b1, b2 must be multiplied with 2^30 before
 
    i_lp_a0		: integer := 0;
    i_lp_a1		: integer := 0;
    i_lp_a2		: integer := 0;
    i_lp_b1		: integer := 0;
    i_lp_b2		: integer := 0;
    
    i_hp_a0		: integer := 0;
    i_hp_a1		: integer := 0;
    i_hp_a2		: integer := 0;
    i_hp_b1		: integer := 0;
    i_hp_b2		: integer := 0
    );
end xover_iir;


architecture Behavioral of xover_iir is

signal state : integer := 0;

--signals for multiplier
signal s_mult_in_a 	: signed (31 downto 0) 	:= (others=>'0');
signal s_mult_in_b 	: signed (31 downto 0) 	:= (others=>'0');
signal s_mult_out 	: signed (63 downto 0)	:= (others=>'0');

--temp regs and delay regs
signal s_temp 		: signed (39 downto 0)   := (others=>'0');
signal s_temp_in 	: signed (31 downto 0)	:= (others=>'0');
signal s_in_z1 	: signed (31 downto 0)	:= (others=>'0');
signal s_in_z2 	: signed (31 downto 0)	:= (others=>'0');

signal s_out_z1_hpf 	: signed (31 downto 0)	:= (others=>'0');
signal s_out_z2_hpf 	: signed (31 downto 0)	:= (others=>'0');

signal s_out_z1_lpf 	: signed (31 downto 0)	:= (others=>'0');
signal s_out_z2_lpf 	: signed (31 downto 0)	:= (others=>'0');

signal s_iir_hpf 	: signed (31 downto 0)	:= (others=>'0');
signal s_iir_lpf 	: signed (31 downto 0)	:= (others=>'0');

begin

o_iir_lpf <= s_iir_lpf;
o_iir_hpf <= s_iir_hpf;

-- multiplier
process(s_mult_in_a, s_mult_in_b)
begin
s_mult_out <= s_mult_in_a * s_mult_in_b;
end process;

-- with mck = 256 * fs, we have plenty of clocks to work with, here we're using 15 clocks for the 2-way lpf and hpf filters
-- for a 3-way digital xover, double that as we would need another lpf and hpf for the bandpass filter

process (i_mck)
begin
if (rising_edge(i_mck)) then    

	--start process when valid sample arrives
    if (i_sample_valid = '1' and state = 0) then
        -- load multiplier with samplein * i_hp_a0
        s_mult_in_a	<= i_iir;
        s_temp_in	<= i_iir;
        s_mult_in_b <= to_signed(i_hp_a0,32);
        state		<= 1;
        o_busy		<= '1';

    elsif (state = 1) then
        --save result of (samplein * i_hp_a0) to temp and apply right-shift of 30
        --and load multiplier with in_z1 and i_hp_a1
        s_temp		<= resize(shift_right(s_mult_out,30),40);
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= to_signed(i_hp_a1,32);
        state		<= 2;

     elsif (state = 2) then
        --save and sum up result of (in_z1 * i_hp_a1) to temp and apply right-shift of 30
        --and load multiplier with in_z2 and i_hp_a2
        s_temp		<= s_temp + resize(shift_right(s_mult_out,30),40);
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= to_signed(i_hp_a2,32);
        state		<= 3;

         
      elsif (state = 3) then
        --save and sum up result of (in_z2 * i_hp_a2) to temp and apply right-shift of 30
        -- and load multiplier with out_z1_hpf and i_hp_b1
        s_temp		<= s_temp + resize(shift_right(s_mult_out,30),40);
        s_mult_in_a	<= s_out_z1_hpf;
        s_mult_in_b	<= to_signed(i_hp_b1,32);
        state		<= 4;

      elsif (state = 4) then
        --save and sum up (negative) result of (out_z1_hpf * i_hp_b1) and apply right-shift of 30
        --and load multiplier with out_z2_hpf and i_hp_b2
        s_temp		<= s_temp - resize(shift_right(s_mult_out,30),40);
        s_mult_in_a	<= s_out_z2_hpf;
        s_mult_in_b	<= to_signed(i_hp_b2,32);
        state		<= 5;

      elsif (state = 5) then
        --save and sum up (negative) result of (out_z2_hpf * i_hp_b2) and apply right-shift of 30
        s_temp	<= s_temp - resize(shift_right(s_mult_out,30),40);
        state	<= 6;
        
      elsif (state = 6) then
        --save result to output_HPF, save all HPF output delay registers
        s_iir_hpf		<= resize(s_temp,32);
        s_out_z1_hpf	<= resize(s_temp,32);
        s_out_z2_hpf	<= s_out_z1_hpf;
		state			<= 7;

		elsif (state = 7) then
        -- load multiplier with samplein * i_lp_a0
        s_mult_in_a	<= i_iir;
        s_temp_in	<= i_iir;
        s_mult_in_b	<= to_signed(i_lp_a0,32);
        state		<= 8;

     elsif (state = 8) then
        --save result of (samplein* i_lp_a0) to temp and apply right-shift of 30
        --and load multiplier with in_z1 and i_lp_a1
        s_temp		<= resize(shift_right(s_mult_out,30),40);
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= to_signed(i_lp_a1,32);
        state		<= 9;

     elsif (state = 9) then
        --save and sum up result of (in_z1 * i_lp_a1) to temp and apply right-shift of 30
        --and load multiplier with in_z2 and i_lp_a2
        s_temp		<= s_temp + resize(shift_right(s_mult_out,30),40);
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= to_signed(i_lp_a2,32);
        state		<= 10;

         
      elsif (state = 10) then
        --save and sum up result of (in_z2 * i_lp_a2) to temp and apply right-shift of 30
        -- and load multiplier with out_z1_lpf and i_lp_b1
        s_temp		<= s_temp + resize(shift_right(s_mult_out,30),40);
        s_mult_in_a	<= s_out_z1_lpf;
        s_mult_in_b	<= to_signed(i_lp_b1,32);
        state		<= 11;

      elsif (state = 11) then
        --save and sum up (negative) result of (out_z1_lpf * i_lp_b1) and apply right-shift of 30
        --and load multiplier with out_z2_lpf and i_lp_b2
        s_temp		<= s_temp - resize(shift_right(s_mult_out,30),40);
        s_mult_in_a	<= s_out_z2_lpf;
        s_mult_in_b	<= to_signed(i_lp_b2,32);
        state		<= 12;

      elsif (state = 12) then
        --save and sum up (negative) result of (out_z2_lpf * i_lp_b2) and apply right-shift of 30
        s_temp		<= s_temp - resize(shift_right(s_mult_out,30),40);
        state		<= 13;
        
      elsif (state = 13) then
        --save result to output_LPF, save all LPF output delay registers
		  -- save input delay registers
        s_iir_lpf		<= resize(s_temp,32);
        s_out_z1_lpf	<= resize(s_temp,32);
        s_out_z2_lpf	<= s_out_z1_lpf;
        s_in_z2			<= s_in_z1;
        s_in_z1			<= s_temp_in;
        o_sample_valid	<= '1';
        state			<= 14;
        
      elsif (state = 14) then
        o_sample_valid	<= '0';
        state			<= 0;
        o_busy			<= '0';
      end if;      

end if;
end process;
end Behavioral;
