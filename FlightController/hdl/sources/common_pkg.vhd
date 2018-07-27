Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package common_pkg is
  type std_logic_array is array (natural range <>) of std_logic_vector;
  type signed_vector is array (natural range <>) of signed;
  type unsigned_vector is array (natural range <>) of unsigned;
end common_pkg;
