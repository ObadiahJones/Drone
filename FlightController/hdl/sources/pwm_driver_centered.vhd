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
    DUTY_CYCLE          : in std_logic_vector(31 downto 0); -- 32-bit signed duty cycle: 0x80000000 = -100%, 0x00000000 = 0%, 0x7FFFFFFF = 100%
    PWM_SIGNAL          : out std_logic -- PWM driver signal
  );
end entity pwm_driver;

architecture behavioral of pwm_driver is

  constant dwell_counter_max        : unsigned(31 downto 0) := to_unsigned(200 * PWM_PERIOD, 32);
  constant pwm_counter_offset       : unsigned(31 downto 0) := dwell_counter_max / 2;

  signal dwell_counter              : unsigned(31 downto 0) := (others => '0');
  signal pwm_counter_val            : unsigned(63 downto 0) := (others => '0');

begin

  pwm_proc : process(CLK)
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
  end process pwm_proc;
end architecture behavioral;
