-- Author: Oliver Johnson
-- Thrust Compute Unit testbench

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.common_pkg.all;

entity test_thrust_compute_unit is
  generic (
    BIT_WIDTH           : positive range 1 to 32 := 16; -- Common data bit-width (signed)
    NUM_ROTORS          : positive range 2 to 8 := 4  -- Number of rotors
  );
end entity test_thrust_compute_unit;

architecture behavioral of test_thrust_compute_unit is

  function GEN_ROTOR_POS (NUM_ROTORS : positive; BIT_WIDTH : positive; ALIGN_PLUS : boolean) return std_logic_array is
    variable ret_val  : std_logic_array(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) := (others => (others => '0'));
    variable offset   : integer := 0;
    variable pi       : integer := 2**(BIT_WIDTH - 1) - 1;
    variable neg_pi   : integer := -(2**(BIT_WIDTH - 1));
  begin
    if ALIGN_PLUS then
      offset := 0;
    else
      offset := pi / NUM_ROTORS;
    end if;

    for i in 0 to NUM_ROTORS - 1 loop
      ret_val(i) := std_logic_vector(to_signed((i * 2 * pi / NUM_ROTORS) + offset + neg_pi, BIT_WIDTH));
    end loop;

    return ret_val;
  end function GEN_ROTOR_POS;

  -- Vector of rotor angular positions (signed): 0x8000 = -pi rad, 0x0000 = 0 rad, 0x7FFF = pi rad
  constant ROTOR_POS          : std_logic_array(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) := GEN_ROTOR_POS(NUM_ROTORS, BIT_WIDTH, false);

  signal clk                  : std_logic := '0';
  signal master_rst           : std_logic := '0';
  signal enable               : std_logic := '0';
  signal ready                : std_logic := '0';
  signal vector               : std_logic_array(2 downto 0)(BIT_WIDTH - 1 downto 0) := (others => (others => '0'));
  signal out_valid            : std_logic := '0';
  signal out_data             : std_logic_array(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) := (others => (others => '0'));

begin
  -- generate clock (200 MHz)
  clk <= not clk after 2.5 ns;

  -- generate stimulus to unit under test
  stimulus_proc : process
  begin
    master_rst <= '1';
    wait for 10 ns;
    master_rst <= '0';

    wait for 10 ns;
    wait until rising_edge(clk);
    wait until ready = '1';

    vector(0) <= x"0020";
    vector(1) <= x"80FF";
    vector(2) <= x"0000";
    enable <= '1';
    wait until rising_edge(clk);
    enable <= '0';

    wait for 100 ns;
    assert false report "SIMULATION COMPLETE" severity failure;
  end process stimulus_proc;

  -- instantiate unit under test
  uut : entity work.thrust_compute_unit
  generic map (
    BIT_WIDTH     => BIT_WIDTH,
    NUM_ROTORS    => NUM_ROTORS,
    ROTOR_POS     => ROTOR_POS
  )
  port map (
    CLK           => clk,
    RST           => master_rst,
    ENABLE        => enable,
    READY         => ready,
    IN_VECTOR     => vector,
    OUT_VALID     => out_valid,
    OUT_DATA      => out_data
  );

end architecture behavioral;
