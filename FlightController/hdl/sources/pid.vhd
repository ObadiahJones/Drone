Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pid is
  generic (
    BIT_WIDTH           : positive range 1 to 32 := 16; -- Common data bit-width (signed)
    SAMPLE_PERIOD       : positive range 1 to 4000 := 200 -- PID execution period in milliseconds
  );
  port (
    CLK                 : in std_logic; -- 200 MHz system clock
    RST                 : in std_logic; -- Active high synchronous reset
    KP                  : in std_logic_vector(BIT_WIDTH - 1 downto 0); -- Proportional coefficient
    KI                  : in std_logic_vector(BIT_WIDTH - 1 downto 0); -- Integral Coefficient
    KD                  : in std_logic_vector(BIT_WIDTH - 1 downto 0); -- Derivative Coefficient
    ENABLE              : in std_logic; -- PID Enable
    SAMPLE_FLAG         : out std_logic; -- Signals that SETPOINT and PROCESS_VAR will be registered on the next clock rising edge
    SETPOINT            : in std_logic_vector(BIT_WIDTH - 1 downto 0); -- Setpoint (must be valid during clock after SAMPLE_FLAG)
    PROCESS_VAR         : in std_logic_vector(BIT_WIDTH - 1 downto 0); -- Current process vartiable (must be valid during clock after SAMPLE_FLAG)
    CTRL_VAR            : out std_logic_vector(BIT_WIDTH - 1 downto 0); -- Output control variable (is valid when OUT_VALID is high)
    OUT_VALID           : out std_logic -- Signals valid data on CTRL_VAR bus
  );
end entity pid;

architecture behavioral of pid is

  signal dwell_counter_max          : unsigned(31 downto 0) := to_unsigned(200_000 * SAMPLE_PERIOD, 32);
  signal dwell_counter              : unsigned(31 downto 0) := (others => '0');
  signal loop_trigger               : std_logic := '0';
  signal sp_k0                      : signed(BIT_WIDTH - 1 downto 0) := (others => '0'); -- std_logic_vector(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal u_k0                       : signed(BIT_WIDTH - 1 downto 0) := (others => '0'); -- std_logic_vector(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal u_k1                       : signed(BIT_WIDTH - 1 downto 0) := (others => '0'); -- std_logic_vector(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal y_k0                       : signed(BIT_WIDTH - 1 downto 0) := (others => '0'); -- std_logic_vector(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal y_k1                       : signed(BIT_WIDTH - 1 downto 0) := (others => '0'); -- std_logic_vector(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal y_k2                       : signed(BIT_WIDTH - 1 downto 0) := (others => '0'); -- std_logic_vector(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal e_k0                       : signed(BIT_WIDTH - 1 downto 0) := (others => '0'); -- std_logic_vector(BIT_WIDTH - 1 downto 0) := (others => '0');
  signal e_k1                       : signed(BIT_WIDTH - 1 downto 0) := (others => '0'); -- std_logic_vector(BIT_WIDTH - 1 downto 0) := (others => '0');

  signal long0                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0'); -- std_logic_vector((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');
  signal long1                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0'); -- std_logic_vector((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');
  signal long2                      : signed((2 * BIT_WIDTH) - 1 downto 0) := (others => '0'); -- std_logic_vector((2 * BIT_WIDTH) - 1 downto 0) := (others => '0');

  type state_type is (stIdle, stFlag, stRegParams, stMultiply, stSum);
  signal state                      : std_logic_vector(3 downto 0) := (others => '0');

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
          dwell_counter <= dwell_counter - '1';
        else
          loop_trigger <= '0';
          dwell_counter <= dwell_counter_max - '1';
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
            e_k0 <= to_signed(SETPOINT) - to_signed(PROCESS_VAR);
            u_k1 <= u_k0;
            y_k2 <= y_k1;
            y_k1 <= y_k0;
            y_k0 <= to_signed(PROCESS_VAR);
            sp_k0 <= to_signed(SETPOINT);
            k_p <= to_signed(KP);
            k_i <= to_signed(KI);
            k_d <= to_signed(KD);
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
