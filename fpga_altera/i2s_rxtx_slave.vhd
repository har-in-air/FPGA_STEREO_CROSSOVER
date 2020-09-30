--------------------------------------------------------------------------
-- github.com/har-in-air I2S slave interface clocked with I2S MCK
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library work;
use work.all;

entity i2s_rxtx_slave is
port (
	i_rstn	: in std_logic;
	i_mck	: in std_logic;
	i_bck	: in std_logic;
	i_ws	: in std_logic;
	
	i_sdi	: in std_logic; -- rx serial input
	o_l24	: out signed(23 downto 0) := (others => '0'); -- rx parallel output left
	o_r24	: out signed(23 downto 0) := (others => '0'); -- rx parallel output right
	o_sync: out std_logic := '0'; -- rx parallel out data valid pulse

	i_l_lp_24	: in signed(23 downto 0); -- tx parallel input left lowpass
	i_l_hp_24	: in signed(23 downto 0); -- tx parallel input left highpass
	i_r_lp_24	: in signed(23 downto 0); -- tx parallel input right lowpass
	i_r_hp_24	: in signed(23 downto 0); -- tx parallel input right highpass
	o_sdo_l	: out std_logic := '0'; -- tx serial output left (lpf+hpf)	
	o_sdo_r	: out std_logic := '0' -- tx serial output right (lpf+hpf)
	);
end entity;


architecture rtl of i2s_rxtx_slave is

-- i2s rx shift registers
signal s_shift32_in_l	: std_logic_vector(31 downto 0) := (others => '0');
signal s_shift32_in_r	: std_logic_vector(31 downto 0) := (others => '0');

-- i2s rx serial to parallel output
signal s_ol24			: std_logic_vector(23 downto 0) := (others => '0');
signal s_or24			: std_logic_vector(23 downto 0) := (others => '0');

-- i2s tx shift registers
signal s_shift32_out_l_lp  : std_logic_vector(31 downto 0) := (others => '0');
signal s_shift32_out_l_hp  : std_logic_vector(31 downto 0) := (others => '0');

signal s_shift32_out_r_lp  : std_logic_vector(31 downto 0) := (others => '0');
signal s_shift32_out_r_hp  : std_logic_vector(31 downto 0) := (others => '0');

-- synchronization registers

--signal s_bckd : std_logic := '0';
--signal s_bckdd : std_logic := '0';
signal s_bck_sync : std_logic_vector(1 downto 0) := (others => '0');

signal s_bck_posedge : std_logic := '0';
signal s_bck_negedge : std_logic := '0';

--signal s_wsd	: std_logic := '0';
--signal s_wsdd	: std_logic := '0';
signal s_ws_sync : std_logic_vector(1 downto 0) := (others => '0');

signal s_sdid	: std_logic := '0';

signal s_ws_posedge	: std_logic := '0';
signal s_ws_negedge	: std_logic := '0';
signal s_ws_edge	: std_logic := '0';

signal s_sync		: std_logic := '0';

signal s_ibitinx : integer range 0 to 31 := 31;
signal s_obitinx : integer range 0 to 31 := 31;

signal s_flag : std_logic := '0';

begin
s_bck_posedge   <= '1' when s_bck_sync = "01" else '0'; -- (not s_bckdd) and s_bckd;
s_bck_negedge   <= '1' when s_bck_sync = "10" else '0'; -- (not s_bckd) and s_bckdd;

s_ws_posedge	<= '1' when s_ws_sync = "01" else '0'; --(not s_wsdd) and s_wsd;
s_ws_negedge	<= '1' when s_ws_sync = "10" else '0'; --(not s_wsd) and s_wsdd;

o_sync <= s_sync;

o_l24  <= signed(s_ol24);
o_r24  <= signed(s_or24);

proc_edge_detect : process(i_mck, i_rstn)
begin
	if i_rstn = '0' then
		--s_bckd   <= '0';
		--s_bckdd  <= '0';
		--s_wsd    <= '0';
		--s_wsdd   <= '0';
		s_bck_sync <= (others => '0');
		s_ws_sync <= (others => '0');
		s_sdid    <= '0';
	elsif falling_edge(i_mck) then
		--s_bckd   <= i_bck;
		--s_bckdd  <= s_bckd;
		--s_wsd    <= i_ws;
		--s_wsdd   <= s_wsd;
		s_bck_sync <= s_bck_sync(0) & i_bck;
		s_ws_sync <= s_ws_sync(0) & i_ws;
		s_sdid	 <= i_sdi;
	end if;
end process proc_edge_detect;



-- input captured on bck falling edge
proc_shift_in : process(i_mck, i_rstn) 
begin
	if i_rstn = '0' then
		s_shift32_in_l		<= (others => '0');
		s_shift32_in_r		<= (others => '0');
		s_sync				<= '0';
		s_ibitinx			<= 31;
	elsif falling_edge(i_mck) then
		if s_bck_negedge = '1' then
			if i_ws = '0' then
				s_shift32_in_l(s_ibitinx) <= s_sdid;
			else
				s_shift32_in_r(s_ibitinx) <= s_sdid;
			end if;
			if s_ibitinx > 0 then
				s_ibitinx <= s_ibitinx - 1;			
			end if;
		end if;
		if s_ws_negedge = '1' then -- complete frame received, load parallel out registers and flag output valid
			s_ol24 <= s_shift32_in_l(31 downto 8); -- works with 16bit or 24bit data, for 16bit, the lower byte is 0
			s_or24 <= s_shift32_in_r(31 downto 8);
			s_sync <= '1';
			s_ibitinx <= 31;
		elsif s_ws_posedge = '1' then -- l/r transition
			s_ibitinx <= 31;
		else
			s_sync <= '0';
		end if;
	end if;
end process;


---- output shifted on bck rising edge
proc_shift_out : process(i_mck, i_rstn) 
begin
	if i_rstn = '0' then
		s_shift32_out_l_lp	<= (others => '0');
		s_shift32_out_l_hp	<= (others => '0');
		s_shift32_out_r_lp	<= (others => '0');
		s_shift32_out_r_hp	<= (others => '0');
		s_obitinx				<= 31;
	elsif falling_edge(i_mck) then
		if s_ws_negedge = '1' then -- load parallel input upto 24bits
			s_shift32_out_l_lp <= std_logic_vector(i_l_lp_24) & x"00"; 
			s_shift32_out_l_hp <= std_logic_vector(i_l_hp_24) & x"00"; 
			s_shift32_out_r_lp <= std_logic_vector(i_r_lp_24) & x"00"; 
			s_shift32_out_r_hp <= std_logic_vector(i_r_hp_24) & x"00"; 
			s_obitinx <= 31;
		elsif s_ws_posedge = '1' then -- l/r transition
			s_obitinx <= 31;
		elsif s_bck_posedge = '1' then
			if i_ws = '0' then
				o_sdo_l <= s_shift32_out_l_lp(s_obitinx); -- place lp filtered data in ws= 0 channel
				o_sdo_r <= s_shift32_out_r_lp(s_obitinx);
			else
				o_sdo_l <= s_shift32_out_l_hp(s_obitinx); -- place hp filtered data in ws= 1 channel
				o_sdo_r <= s_shift32_out_r_hp(s_obitinx);
			end if;
			if s_obitinx > 0 then
				s_obitinx <= s_obitinx - 1;
			end if;
		end if;
	end if;
end process;

end architecture rtl;

