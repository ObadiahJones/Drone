Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pwm_driver is
  generic (
    PWM_PERIOD          : positive range 1 to 1_000_000 := 1_000 -- PWM major period in microseconds
    PWM_SCHEME          : boolean := false -- PWM control scheme; true - centered; false - directional
  );
  port (
    CLK                 : in std_logic; -- 200 MHz system clock
    RST                 : in std_logic; -- Active high synchronous reset
    DUTY_CYCLE          : in std_logic_vector(31 downto 0); -- 32-bit signed duty cycle. 0x80000000 = -100%, 0x00000000 = 0%, 0x7FFFFFFF = 100%
    PWM_SIGNAL          : out std_logic; -- PWM driver signal
    PWM_DIR             : out std_logic -- Directional bit (not used in cenetered mode)
  );
end entity pwm_driver;

architecture behavioral of pwm_driver is

  constant dwell_counter_max        : unsigned(31 downto 0) := to_unsigned(200 * PWM_PERIOD, 32);
  constant pwm_counter_offset       : unsigned(31 downto 0) := (others => '0') when not PWM_SCHEME else dwell_counter_max / 2;

  signal dwell_counter              : unsigned(31 downto 0) := (others => '0');
  signal pwm_counter_val            : unsigned(63 downto 0) := (others => '0');

begin

  trigger_proc : process(CLK)
  begin
    if rising_edge(CLK) then
      if RST = '1' then
        PWM_SIGNAL <= '0';
        PWM_DIR <= '0';
        dwell_counter <= dwell_counter_max - '1';
        pwm_counter_val <= pwm_counter_offset;
      else
        if dwell_counter = to_unsigned(0, 32) then
          pwm_counter_val <= DUTY_CYCLE * unsigned('0' & (not dwell_counter_max(30 downto 0)));
          PWM_DIR <= DUTY_CYCLE(31);
          dwell_counter <= dwell_counter_max - '1';
        else
          dwell_counter <= dwell_counter - '1';
        end if;

        --if dwell_counter =
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
