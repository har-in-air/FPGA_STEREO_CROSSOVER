--------------------------------------------------------------------------
-- github.com/har-in-air
-- Quartus prime infers dual clock 16x32 dpram in block ram
--------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.all;
use work.params.all;

entity dpram_async_clks is
	port 	(	
	d_a	: in std_logic_vector(c_REG_NBITS-1 downto 0) := (others => '0');
	d_b	: in std_logic_vector(c_REG_NBITS-1 downto 0) := (others => '0');
	addr_a	: in natural range 0 to c_NUM_REGS-1 := 0;
	addr_b	: in natural range 0 to c_NUM_REGS-1 := 0;
	we_a	: in std_logic := '0';
	we_b	: in std_logic := '0';
	clk_a	: in std_logic;
	clk_b	: in std_logic;
	q_a	: out std_logic_vector(c_REG_NBITS-1 downto 0);
	q_b	: out std_logic_vector(c_REG_NBITS-1 downto 0)
	);	
end dpram_async_clks;

architecture rtl of dpram_async_clks is
	
	-- Build a 2-D array type for the RAM
	subtype word_t is std_logic_vector(c_REG_NBITS-1 downto 0);
	type memory_t is array(c_NUM_REGS-1 downto 0) of word_t;
	
	-- Declare the RAM
	shared variable ram : memory_t;

begin

	-- Port A
	process(clk_a)
	begin
		if(rising_edge(clk_a)) then 
			if(we_a = '1') then
				ram(addr_a) := d_a;
			end if;
			q_a <= ram(addr_a);
		end if;
	end process;
	
	-- Port B
	process(clk_b)
	begin
		if(rising_edge(clk_b)) then
			if(we_b = '1') then
				ram(addr_b) := d_b;
			end if;
			q_b <= ram(addr_b);
		end if;
	end process;
end rtl;

