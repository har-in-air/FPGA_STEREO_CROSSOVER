--------------------------------------------------------------------------
-- github.com/har-in-air
-- Quartus prime infers dpram in block ram
--------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.all;
use work.params.all;

entity dpram is
	port 	(	
	d_a	: in std_logic_vector(c_COEFF_NBITS-1 downto 0) := (others => '0');
	d_b	: in std_logic_vector(c_COEFF_NBITS-1 downto 0) := (others => '0');
	addr_a	: in natural range 0 to c_NCOEFFS-1 := 0;
	addr_b	: in natural range 0 to c_NCOEFFS-1 := 0;
	we_a	: in std_logic := '0';
	we_b	: in std_logic := '0';
	clk	: in std_logic;
	q_a	: out std_logic_vector(c_COEFF_NBITS-1 downto 0);
	q_b	: out std_logic_vector(c_COEFF_NBITS-1 downto 0)
	);	
end dpram;

architecture rtl of dpram is
	
	-- Build a 2-D array type for the RAM
	subtype word_t is std_logic_vector(c_COEFF_NBITS-1 downto 0);
	type memory_t is array(c_NCOEFFS-1 downto 0) of word_t;
	
	-- Declare the RAM
	shared variable ram : memory_t;

begin
	process(clk)
	begin
		if(rising_edge(clk)) then 
			q_a <= ram(addr_a);
			q_b <= ram(addr_b);
			if(we_a = '1') then
				ram(addr_a) := d_a;
				q_a <= d_a; -- write-through
			end if;
			if(we_b = '1') then
				ram(addr_b) := d_b;
				q_b <= d_b; -- write-through
			end if;
		end if;
	end process;
	
end rtl;

