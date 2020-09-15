library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package PARAMS is
  constant c_CMD_NBITS		: integer := 8;
  constant c_IIR_NBITS	   : integer := 40;  
  constant c_NUM_REGS		: integer := 16;
  constant c_SYS_CLK_FREQ	: integer := 50_000_000;
end package PARAMS;

package body PARAMS is
end package body PARAMS;
