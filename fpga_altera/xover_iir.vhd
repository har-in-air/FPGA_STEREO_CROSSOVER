----------------------------------------------------------------------------------
-- Engineer: github.com/YetAnotherElectronicsChannel
-- modified : github.com/har-in-air for 2-way active crossover, using 40bit (4.36)
-- biquad filter coefficient precision.
-- Low-pass and high-pass filters are 4th order butterworth filters, implemented
-- as cascaded 2nd order Butterworth filters 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.all;
use work.params.all;

entity xover_iir is
port (
    i_mck		: in std_logic := '0';
    
    i_iir		: in signed (c_DATA_NBITS-1 downto 0) := (others=>'0');
    i_sample_valid  : in std_logic := '0';
    
    o_iir_lpf	: out signed(c_DATA_NBITS-1 downto 0) := (others=>'0');
    o_iir_hpf	: out signed(c_DATA_NBITS-1 downto 0) := (others=>'0');
    o_sample_valid : out std_logic := '0';
    
    o_busy		: out std_logic := '0';

	-- b0, b1, b2, a1, a2 are fixed point 4.36 signed 2's complement 
 
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
end xover_iir;


architecture Behavioral of xover_iir is

--iir filter state machine
signal iir_state	: integer := 0;

--multiplier signals
signal s_mult_in_a	: signed (c_DATA_NBITS-1 downto 0) 	:= (others=>'0'); -- data sample
signal s_mult_in_b	: signed (c_COEFF_NBITS-1 downto 0) 	:= (others=>'0'); -- coefficient
signal s_mult_out	: signed (c_MULT_NBITS-1 downto 0)	:= (others=>'0'); -- multiplication result

--accumulator
signal s_mult_out_resize	: signed (c_ACCUM_NBITS-1 downto 0)   := (others=>'0');
signal s_accum				: signed (c_ACCUM_NBITS-1 downto 0)   := (others=>'0');
signal s_accum_resize 		: signed (c_DATA_NBITS-1 downto 0); 

--Fourth order filter implemented as cascaded 2nd-order Butterworth filters

--registered input and delay registers
signal s_iir_in	    : signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');

signal s_in_z1		: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');
signal s_in_z2		: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');

-- lpf biquad0 filter outputs and delayed output registers
signal s_lpfx       : signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');
signal s_lpfxo_z1 	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');
signal s_lpfxo_z2 	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');

-- lpf biquad1 filter delayed inputs
signal s_lpfxi_z1 	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');
signal s_lpfxi_z2 	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');

-- hpf biquad0 filter outputs and delay registers
signal s_hpfx       : signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');
signal s_hpfxo_z1 	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');
signal s_hpfxo_z2 	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');

-- hpf biquad1 filter delayed inputs
signal s_hpfxi_z1 	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');
signal s_hpfxi_z2 	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');

-- final lpf outputs and delay registers
signal s_iir_lpf    : signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');
signal s_iir_lpf_z1	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');
signal s_iir_lpf_z2	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');

-- final hpf outputs and delay registers
signal s_iir_hpf    : signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');
signal s_iir_hpf_z1	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');
signal s_iir_hpf_z2	: signed (c_DATA_NBITS-1 downto 0)	:= (others=>'0');


begin

o_iir_lpf <= s_iir_lpf;
o_iir_hpf <= s_iir_hpf;

s_accum_resize      <= resize(shift_right(s_accum, c_COEFF_FBITS), c_DATA_NBITS);
s_mult_out_resize   <= resize(s_mult_out, c_ACCUM_NBITS);

--synthesis tool infers built-in multiplier
proc_multiply : process(s_mult_in_a, s_mult_in_b)
begin
	s_mult_out <= s_mult_in_a * s_mult_in_b;
end process;

-- A new data input sample (L+R) arrives every 1/fs seconds. 
-- With mck = 256 * fs, we have 256 clocks to work with before the next sample arrives.
-- We're using 29 clocks for the crossover lpf and hpf filters. Each 4th order filter is
-- implemented as a cascade of biquad butterworth filters. 

proc_iir_sm : process (i_mck)
begin
if (rising_edge(i_mck)) then    
	case iir_state is
	when 0 =>
	-- idle state, start when valid sample arrives
-- HPF biquad 0
    if (i_sample_valid = '1') then
        -- load multiplier with i_iir, i_hp0_b0
        s_mult_in_a	<= i_iir;
        s_iir_in    <= i_iir;
        s_mult_in_b	<= i_hp0_b0;
        o_busy		<= '1';
        iir_state	<= 1;
    else
    	iir_state <= 0;
    end if;

    when 1 =>
        --save (i_iir * i_hp0_b0) to accum
        --load multiplier with s_in_z1 and i_hp0_b1
        s_accum		<= s_mult_out_resize;
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= i_hp0_b1;
        iir_state	<= 2;

    when 2 =>
        --accumulate  (s_in_z1 * i_hp0_b1) 
        --load multiplier with s_in_z2 and i_hp0_b2
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= i_hp0_b2;
        iir_state	<= 3;

    when 3 =>
        --accumulate  (s_in_z2 * i_hp0_b2)
        --load multiplier with s_hpfxo_z1 and i_hp0_a1
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_hpfxo_z1;
        s_mult_in_b	<= i_hp0_a1;
        iir_state	<= 4;

  	when 4 => 
        --accumulate negative (s_hpfxo_z1 * i_hp0_a1)
        --load multiplier with s_hpfxo_z2 and i_hp0_a2
        s_accum		<= s_accum - s_mult_out_resize;
        s_mult_in_a	<= s_hpfxo_z2;
        s_mult_in_b	<= i_hp0_a2;
        iir_state	<= 5;
	
    when 5 =>
        --accumulate negative (s_hpfxo_z2 * i_hp0_a2)
        s_accum		<= s_accum - s_mult_out_resize;
        iir_state	<= 6;
        
    when 6 =>
        --save resized accumulator to s_hpfx (intermediate output)
        --save s_hpfx delay registers
        s_hpfx		<= s_accum_resize; 
        s_hpfxo_z1	<= s_accum_resize; 
        s_hpfxo_z2	<= s_hpfxo_z1;
		  iir_state	<= 7;

-- HPF biquad 1

	when 7 =>
        -- load multiplier with s_hpfx, i_hp1_b0
        s_mult_in_a	<= s_hpfx;
        s_mult_in_b	<= i_hp1_b0;
        iir_state	<= 8;

    when 8 =>
        --save (s_hpfx * i_hp1_b0) to accum
        --load multiplier with s_hpfxi_z1 and i_hp1_b1
        s_accum		<= s_mult_out_resize;
        s_mult_in_a	<= s_hpfxi_z1;
        s_mult_in_b	<= i_hp1_b1;
        iir_state	<= 9;

    when 9 =>
        --accumulate (s_hpfxi_z1 * i_hp1_b1) 
        --load multiplier with s_hpfxi_z2 and i_hp1_b2
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_hpfxi_z2;
        s_mult_in_b	<= i_hp1_b2;
        iir_state	<= 10;

    when 10 =>
        --accumulate (s_hpfxi_z2 * i_hp1_b2)
        --load multiplier with s_iir_hpf_z1 and i_hp1_a1
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_iir_hpf_z1;
        s_mult_in_b	<= i_hp1_a1;
        iir_state	<= 11;

  	when 11 => 
        --accumulate negative (s_iir_hpf_z1 * i_hp1_a1)
        --load multiplier with s_iir_hpf_z2 and i_hp1_a2
        s_accum		<= s_accum - s_mult_out_resize;
        s_mult_in_a	<= s_iir_hpf_z2;
        s_mult_in_b	<= i_hp1_a2;
        iir_state	<= 12;
	
    when 12 =>
        --accumulate negative (s_iir_hpf_z2 * i_hp1_a2)
        s_accum		<= s_accum - s_mult_out_resize;
        iir_state	<= 13;
        
    when 13 =>
        --save resized accumulator to s_iir_hpf output
        --save s_iir_hpf delay registers
        s_iir_hpf		<= s_accum_resize;
        s_iir_hpf_z1	<= s_accum_resize;
        s_iir_hpf_z2	<= s_iir_hpf_z1;
		  
		  s_hpfxi_z1 	<= s_hpfx;
		  s_hpfxi_z2 	<= s_hpfxi_z1;
		  iir_state		<= 14;

---LPF biquad 0

	when 14 =>
        -- load multiplier with i_iir * i_lp0_b0
        s_mult_in_a	<= s_iir_in;
        s_mult_in_b	<= i_lp0_b0;
        iir_state	<= 15;

    when 15 =>
        --save (i_iir * i_lp0_b0) in accum
        --load multiplier with s_in_z1 and i_lp0_b1
        s_accum		<= s_mult_out_resize;
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= i_lp0_b1;
        iir_state	<= 16;

    when 16 =>
        --accumulate (s_in_z1 * i_lp0_b1)
        --load multiplier with s_in_z2 and i_lp0_b2
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= i_lp0_b2;
        iir_state	<= 17;

    when 17 =>
        --accumulate (s_in_z2 * i_lp0_b2)
        --load multiplier with s_lpfxo_z1 and i_lp0_a1
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_lpfxo_z1;
        s_mult_in_b	<= i_lp0_a1;
        iir_state	<= 18;

    when 18 =>
        --accumulate negative (s_lpfxo_z1 * i_lp0_a1)
        --load multiplier with s_lpfxo_z2 and i_lp0_a2
        s_accum		<= s_accum - s_mult_out_resize;
        s_mult_in_a	<= s_lpfxo_z2;
        s_mult_in_b	<= i_lp0_a2;
        iir_state	<= 19;

    when 19 =>
        --accumulate negative  (s_lpfxo_z2 * i_lp0_a2)
        s_accum		<= s_accum - s_mult_out_resize;
        iir_state	<= 20;
        
    when 20 =>
        --save resized accumulator to s_lpfx
        --save lpfx delay registers
        s_lpfx		<= s_accum_resize;
        s_lpfxo_z1	<= s_accum_resize;
        s_lpfxo_z2	<= s_lpfxo_z1;
        iir_state	<= 21;

-- LPF Butterworth 1
	when 21 =>
        -- load multiplier with s_lpfx * i_lp1_b0
        s_mult_in_a	<= s_lpfx;
        s_mult_in_b	<= i_lp1_b0;
        iir_state	<= 22;

    when 22 =>
        --save (s_lpfx * i_lp1_b0) in accum
        --load multiplier with s_lpfxi_z1 and i_lp1_b1
        s_accum		<= s_mult_out_resize;
        s_mult_in_a	<= s_lpfxi_z1;
        s_mult_in_b	<= i_lp1_b1;
        iir_state	<= 23;

    when 23 =>
        --accumulate (s_lpfxi_z1 * i_lp1_b1)
        --load multiplier with s_lpfxi_z2 and i_lp1_b2
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_lpfxi_z2;
        s_mult_in_b	<= i_lp1_b2;
        iir_state	<= 24;

    when 24 =>
        --accumulate (s_lpfxi_z2 * i_lp1_b2)
        --load multiplier with s_iir_lpf_z1 and i_lp1_a1
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_iir_lpf_z1;
        s_mult_in_b	<= i_lp1_a1;
        iir_state	<= 25;

    when 25 =>
        --accumulate negative (s_iir_lpf_z1 * i_lp1_a1)
        --load multiplier with s_iir_lpf_z2 and i_lp1_a2
        s_accum		<= s_accum - s_mult_out_resize;
        s_mult_in_a	<= s_iir_lpf_z2;
        s_mult_in_b	<= i_lp1_a2;
        iir_state	<= 26;

    when 26 =>
        --accumulate negative (s_iir_lpf_z2 * i_lp1_a2)
        s_accum		<= s_accum - s_mult_out_resize;
        iir_state	<= 27;
        
    when 27 =>
        --save resized accumulator to s_iir_lpf
        --save s_iir_lpf delay registers
        s_iir_lpf		<= s_accum_resize;
        s_iir_lpf_z1	<= s_accum_resize;
        s_iir_lpf_z2	<= s_iir_lpf_z1;
		  
  		  s_lpfxi_z1 	<= s_lpfx;
		  s_lpfxi_z2 	<= s_lpfxi_z1;

		--save input delay registers
        s_in_z1		<= s_iir_in;
        s_in_z2		<= s_in_z1;
        --generate output valid pulse
        o_sample_valid	<= '1';
        iir_state		<= 28;       
        
    when 28 =>
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
