-- Author: Oliver Johnson
-- Thrust Compute Unit entity
-- TODO implement overflow/underflow error catching
-- TODO figure out how the hell to scope the data bounds because we have -pi to pi, and operate between -1 to 1

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.common_pkg.all;

entity thrust_compute_unit is
  generic (
    BIT_WIDTH           : positive range 1 to 32 := 16; -- Common data bit-width (signed)
    NUM_ROTORS          : positive range 2 to 8 := 4; -- Number of rotors
    ROTOR_POS           : std_logic_array(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) := (x"1FFF", x"5FFF", x"9FFF", x"DFFF") -- Vector of rotor angular positions (signed): 0x8000 = -pi rad, 0x0000 = 0 rad, 0x7FFF = pi rad
  );
  port (
    CLK                 : in std_logic; -- 200 MHz system clock
    RST                 : in std_logic; -- Active high synchronous reset
    ENABLE              : in std_logic; -- Module Enable
    READY               : out std_logic; -- Status bit; high when module can accept a new input, low otherwise
    IN_VECTOR           : in std_logic_array(2 downto 0)(BIT_WIDTH - 1 downto 0); -- Target vector
    OUT_VALID           : out std_logic; -- Signals valid data on all OUT_DATA buses
    OUT_DATA            : out std_logic_array(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) -- Signed fixed-point unity power levels for all rotors
  );
end entity thrust_compute_unit;

architecture behavioral of thrust_compute_unit is

  constant NULL_SHORT               : signed(BIT_WIDTH - 1 downto 0) := (others => '0');
  constant SATUR_SHORT              : signed(BIT_WIDTH - 1 downto 0) := (others => '1');
  constant SATUR_P_SHORT            : signed(BIT_WIDTH - 1 downto 0) := '0' & SATUR_SHORT(BIT_WIDTH - 2 downto 0);
  constant SATUR_N_SHORT            : signed(BIT_WIDTH - 1 downto 0) := '1' & NULL_SHORT(BIT_WIDTH - 2 downto 0);

  constant COS_THETA                : signed_vector(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) := (others => (others => '0')); -- TODO cosine function to initialize array
  constant SIN_THETA                : signed_vector(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) := (others => (others => '0')); -- TODO sine function to initialize array

  signal x_val                      : signed(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal y_val                      : signed(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal z_val                      : signed(BIT_WIDTH - 1 downto 0) := (others => '0');

  signal long0                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');
  signal long1                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');
  signal long2                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');

  signal short_vec0                 : signed_vector(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) := (others => (others => '0'));
  signal long_vec0                  : signed_vector(NUM_ROTORS - 1 downto 0)((2 * BIT_WIDTH) - 1 downto 0) := (others => (others => '0'));
  signal long_vec1                  : signed_vector(NUM_ROTORS - 1 downto 0)((2 * BIT_WIDTH) - 1 downto 0) := (others => (others => '0'));
  signal long_vec2                  : signed_vector(NUM_ROTORS - 1 downto 0)((2 * BIT_WIDTH) - 1 downto 0) := (others => (others => '0'));

  signal sqrt_in_valid              : std_logic := '0';
  signal sqrt_in_data               : std_logic_vector(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal sqrt_out_valid             : std_logic := '0';
  signal sqrt_out_data              : std_logic_vector(BIT_WIDTH - 1 downto 0) := (others => '0');

  type state_type is (stIdle, stOne, stTwo, stThree, stFour);
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
        short_vec0 <= (others => (others => '0'));
        long_vec0 <= (others => (others => '0'));
        long_vec1 <= (others => (others => '0'));
        long_vec2 <= (others => (others => '0'));

        sqrt_in_data <= (others => '0');
        sqrt_in_valid <= '0';
        sqrt_out_data <= (others => '0');
        sqrt_out_valid <= '0';

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
              array_gen0 : for i in 0 to NUM_ROTORS - 1 loop
                long_vec0(i) <= signed(IN_VECTOR(0)) * COS_THETA(i);
              end loop array_gen0;
              state <= stOne;
            else
              READY <= '1';
              x_val <= (others => '0');
              y_val <= (others => '0');
              z_val <= (others => '0');
              long0 <= (others => '0');
              long1 <= (others => '0');
              long2 <= (others => '0');
              short_vec0 <= (others => (others => '0'));
              long_vec0 <= (others => (others => '0'));
              long_vec1 <= (others => (others => '0'));
              long_vec2 <= (others => (others => '0'));

              sqrt_in_data <= (others => '0');
              sqrt_in_valid <= '0';
              sqrt_out_data <= (others => '0');
              sqrt_out_valid <= '0';
            end if;

          when stOne =>
            sqrt_in_data <= std_logic_vector(long0(BIT_WIDTH - 1 downto 0) + long1(BIT_WIDTH - 1 downto 0));
            sqrt_in_valid <= '1';
            long2 <= long0(BIT_WIDTH - 1 downto 0) / (long0(BIT_WIDTH - 1 downto 0) + long1(BIT_WIDTH - 1 downto 0)); -- TODO How the fuck does this synthesize?
            array_gen1 : for i in 0 to NUM_ROTORS - 1 loop
              short_vec0(i) <= z_val + long_vec0(i)(BIT_WIDTH - 1 downto 0);
            end loop array_gen1;
            state <= stTwo;

          when stTwo =>
            if sqrt_out_valid = '1' then
              sqrt_in_data <= std_logic_vector(SATUR_P_SHORT - long2(BIT_WIDTH - 1 downto 0));
              sqrt_in_valid <= '1';
              array_gen2 : for i in 0 to NUM_ROTORS - 1 loop
                long_vec1(i) <= signed(sqrt_out_data) * SIN_THETA(i);
              end loop array_gen2;
              state <= stThree;
            else
              sqrt_in_data <= (others => '0');
              sqrt_in_valid <= '0';
            end if;

          when stThree =>
            if sqrt_out_valid = '1' then
              array_gen3 : for i in 0 to NUM_ROTORS - 1 loop
                long_vec2(i) <= (long_vec1(i)(BIT_WIDTH - 1 downto 0) * signed(sqrt_out_data)) + short_vec0(i);
              end loop array_gen3;
              state <= stFour;
            else
              sqrt_in_data <= (others => '0');
              sqrt_in_valid <= '0';
            end if;

          when stFour =>
            OUT_VALID <= '1';
            array_gen4 : for i in 0 to NUM_ROTORS - 1 loop
              OUT_DATA(i) <= std_logic_vector(long_vec2(i)(BIT_WIDTH - 1 downto 0));
            end loop array_gen4;
            state <= stIdle;

        end case;
      end if;
    end if;
  end process pipeline_proc;

  sqrt_inst : entity work.sqrt
    port map (
      aclk                      => CLK,
      aresetn                   => not RST,
      s_axis_cartesian_tvalid   => sqrt_in_valid,
      s_axis_cartesian_tdata    => sqrt_in_data,
      m_axis_dout_tvalid        => sqrt_out_valid,
      m_axis_dout_tdata         => sqrt_out_data
    );
end architecture behavioral;
