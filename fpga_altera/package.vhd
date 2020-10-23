library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package PARAMS is
  constant c_CMD_NBITS		: integer := 8;
  constant c_COEFF_NBITS	: integer := 40;  
  constant c_COEFF_FBITS    : integer := 36;
  constant c_NCOEFFS		: integer := 20;
  constant c_MULT_NBITS		: integer := 72;
  constant c_ACCUM_NBITS	: integer := 80;
end package PARAMS;

package body PARAMS is
end package body PARAMS;
