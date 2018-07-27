-- Author: Oliver Johnson
-- Thrust Compute Unit entity
-- TODO implement overflow/underflow error catching
-- TODO figure out how the hell to scope the data bounds because we have -pi to pi, and operate between -1 to 1

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.common_pkg;

entity pid is
  generic (
    BIT_WIDTH           : positive range 1 to 32 := 16; -- Common data bit-width (signed)
    NUM_ROTORS          : positive range 2 to 8 := 4; -- Number of rotors
    ROTOR_POS           : std_logic_array(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) := (x"1FFF_FFFF", x"5FFF_FFFF", x"9FFF_FFFF", x"DFFF_FFFF") -- Vector of rotor angular positions (signed): 0x80000000 = -pi rad, 0x00000000 = 0 rad, 0x7FFFFFFF = pi rad
  );
  port (
    CLK                 : in std_logic; -- 200 MHz system clock
    RST                 : in std_logic; -- Active high synchronous reset
    ENABLE              : in std_logic; -- Module Enable
    READY               : out std_logic; -- Status bit; high when module can accept a new input, low otherwise
    IN_VECTOR           : in std_logic_array(2 downto 0)(BIT_WIDTH - 1 downto 0)
    OUT_VALID           : out std_logic; -- Signals valid data on all OUT_DATA buses
    OUT_DATA            : out std_logic_array(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) -- Signed fixed-point unity power levels for all rotors
  );
end entity pid;

architecture behavioral of pid is

  constant NULL_SHORT               : signed(BIT_WIDTH - 1 downto 0) := (others => '0');
  constant SATUR_P_SHORT            : signed(BIT_WIDTH - 1 downto 0) := '0' & (others => '1'); -- TODO Will this synthesize?
  constant SATUR_N_SHORT            : signed(BIT_WIDTH - 1 downto 0) := '1' & (others => '0'); -- NULL_SHORT(BIT_WIDTH - 2 downto 0);

  constant COS_THETA                : signed_vector(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0); -- TODO cosine function to initialize array
  constant SIN_THETA                : signed_vector(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0); -- TODO sine function to initialize array

  signal x_val                      : signed(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal y_val                      : signed(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal z_val                      : signed(BIT_WIDTH - 1 downto 0) := (others => '0');

  signal long0                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');
  signal long1                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');
  signal long2                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');
  signal long3                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');
  signal long4                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');

  signal short_vec0                 : signed_vector(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal long_vec0                  : signed_vector(NUM_ROTORS - 1 downto 0)((2 * BIT_WIDTH) - 1 downto 0) := (others => (others => '0'));
  signal long_vec1                  : signed_vector(NUM_ROTORS - 1 downto 0)((2 * BIT_WIDTH) - 1 downto 0) := (others => (others => '0'));
  signal long_vec2                  : signed_vector(NUM_ROTORS - 1 downto 0)((2 * BIT_WIDTH) - 1 downto 0) := (others => (others => '0'));

  type state_type is (stIdle, stFlag, stRegParams, stMultiply, stSum);
  signal state                      : state_type := stIdle;

begin
  pipeline_proc : process(CLK)
  begin
    if rising_edge(CLK) then
      if RST = '1' then
        READY <= '0';
        OUT_VALID <= '0';
        OUT_DATA <= (others => (others => '0'));

        x_val <= (others => '0');
        y_val <= (others => '0');
        z_val <= (others => '0');
        long0 <= (others => '0');
        long1 <= (others => '0');
        long2 <= (others => '0');
        long3 <= (others => '0');
        long4 <= (others => '0');
        short_vec0 <= (others => (others => '0'));
        long_vec0 <= (others => (others => '0'));
        long_vec1 <= (others => (others => '0'));
        long_vec2 <= (others => (others => '0'));

      else
        case state is
          when stIdle =>
            OUT_VALID <= '0';
            OUT_DATA <= (others => (others => '0'));

            if ENABLE = '1' then
              READY <= '0';
              x_val <= signed(IN_VECTOR(0));
              y_val <= signed(IN_VECTOR(1));
              z_val <= signed(IN_VECTOR(2));
              long0 <= signed(IN_VECTOR(0)) * signed(IN_VECTOR(0));
              long1 <= signed(IN_VECTOR(1)) * signed(IN_VECTOR(1));
              array_gen0 : for i in 0 to NUM_ROTORS - 1 generate
                long_vec0(i) <= signed(IN_VECTOR(0)) * COS_THETA(i);
              end generate array_gen0;
              state <= stOne;
            else
              READY <= '1';
              x_val <= (others => '0');
              y_val <= (others => '0');
              z_val <= (others => '0');
              long0 <= (others => '0');
              long1 <= (others => '0');
              long2 <= (others => '0');
              long3 <= (others => '0');
              long4 <= (others => '0');
              short_vec0 <= (others => (others => '0'));
              long_vec0 <= (others => (others => '0'));
              long_vec1 <= (others => (others => '0'));
              long_vec2 <= (others => (others => '0'));
            end if;

          when stOne =>
            long2 <= sqrt(long0(BIT_WIDTH - 1 downto 0) + long1(BIT_WIDTH - 1 downto 0)); -- TODO determine if this will work / is the best implementation
            long3 <= long0(BIT_WIDTH - 1 downto 0) / (long0(BIT_WIDTH - 1 downto 0) + long1(BIT_WIDTH - 1 downto 0)); --How the fuck does this synthesize?
            array_gen1 : for i in 0 to NUM_ROTORS - 1 generate
              short_vec0(i) <= z_val + long_vec0(i)(BIT_WIDTH - 1 downto 0);
            end generate array_gen1;
            state <= stTwo;

          when stTwo =>
            long4 <= sqrt(SATUR_P_SHORT - long3(BIT_WIDTH - 1 downto 0)); -- TODO determine if this will work / is the best implementation
            array_gen2 : for i in 0 to NUM_ROTORS - 1 generate
              long_vec1(i) <= long2(BIT_WIDTH - 1 downto 0) * SIN_THETA(i);
            end generate array_gen2;
            state <= stThree;

          when stThree =>
            array_gen3 : for i in 0 to NUM_ROTORS - 1 generate
              long_vec2(i) <= (long_vec1(i)(BIT_WIDTH - 1 downto 0) * long4(BIT_WIDTH - 1 downto 0)) + short_vec0(i);
            end generate array_gen3;
            state <= stFour;

          when stFour =>
            OUT_VALID <= '1';
            array_gen4 : for i in 0 to NUM_ROTORS - 1 generate
              OUT_DATA(i) <= long_vec2(i)(BIT_WIDTH - 1 downto 0);
            end generate array_gen4;
            state <= stIdle;

        end case;
      end if;
    end if;
end architecture behavioral;
