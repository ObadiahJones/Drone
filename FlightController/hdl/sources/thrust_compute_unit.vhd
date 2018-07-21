-- Author: Oliver Johnson
-- Thrust Compute Unit entity
-- TODO implement overflow/underflow error catching

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
    IN_VECTOR           : in std_logic_array(2 downto 0)(BIT_WIDTH - 1 downto 0)
    OUT_VALID           : out std_logic; -- Signals valid data on all OUT_DATA buses
    OUT_DATA            : out std_logic_array(NUM_ROTORS - 1 downto 0)(BIT_WIDTH - 1 downto 0) -- Signed fixed-point unity power levels for all rotors
  );
end entity pid;

architecture behavioral of pid is

  signal long0                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0'); -- std_logic_vector((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');
  signal long1                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0'); -- std_logic_vector((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');
  signal long2                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0'); -- std_logic_vector((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');

  type state_type is (stIdle, stFlag, stRegParams, stMultiply, stSum);
  signal state                      : state_type := stIdle;

begin

  -- Process to trigger the PID execution once every SAMPLE_PERIOD milliseconds
  trigger_proc : process(CLK)
  begin
    if rising_edge(CLK) then
      if RST = '1' then
        loop_trigger <= '0';
        dwell_counter <= dwell_counter_max - '1';
      else
        if dwell_counter = to_unsigned(0, 32) then
          loop_trigger <= '1';
          dwell_counter <= dwell_counter_max - '1';
        else
          loop_trigger <= '0';
          dwell_counter <= dwell_counter - '1';
        end if;
      end if;
    end if;
  end process trigger_proc;

  pid_proc : process(CLK)
  begin
    if rising_edge(CLK) then
      if RST = '1' then
        state <= stIdle;
        CTRL_VAR <= (others => '0');
        OUT_VALID <= '0';
        SAMPLE_FLAG <= '0';
        u_k0 <= (others => '0');
        u_k1 <= (others => '0');
        y_k0 <= (others => '0');
        y_k1 <= (others => '0');
        y_k2 <= (others => '0');
        e_k0 <= (others => '0');
        e_k1 <= (others => '0');
      else
        case state is
          when stIdle =>
            CTRL_VAR <= (others => '0');
            OUT_VALID <= '0';
            SAMPLE_FLAG <= '0';
            if loop_trigger = '1' then
              state <= stFlag;
            end if;

          when stFlag =>
            SAMPLE_FLAG <= '1';
            state <= stRegParams;

          when stRegParams =>
            SAMPLE_FLAG <= '0';
            e_k1 <= e_k0;
            e_k0 <= signed(SETPOINT) - signed(PROCESS_VAR);
            u_k1 <= u_k0;
            y_k2 <= y_k1;
            y_k1 <= y_k0;
            y_k0 <= signed(PROCESS_VAR);
            sp_k0 <= signed(SETPOINT);
            k_p <= signed(KP);
            k_i <= signed(KI);
            k_d <= signed(KD);
            state <= stMultiply;

          when stMultiply =>
            long0 <= k_p * (y_k1 - y_k0);
            long1 <= k_i * e_k0;
            long2 <= k_d * ((y_k1(30 downto 1) & '0') - y_k2 - y_k0);
            state <= stSum;

          when stSum =>
            CTRL_VAR <= std_logic_vector(u_k1 +
                        long0((2 * BIT_WIDTH) - 1 downto BIT_WIDTH) +
                        long1((2 * BIT_WIDTH) - 1 downto BIT_WIDTH) +
                        long2((2 * BIT_WIDTH) - 1 downto BIT_WIDTH));
            u_k0     <= u_k1 +
                        long0((2 * BIT_WIDTH) - 1 downto BIT_WIDTH) +
                        long1((2 * BIT_WIDTH) - 1 downto BIT_WIDTH) +
                        long2((2 * BIT_WIDTH) - 1 downto BIT_WIDTH);
            OUT_VALID <= '1';
            state <= stIdle;

        end case;
      end if;
    end if;
  end process pid_proc;
end architecture behavioral;
