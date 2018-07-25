-- Author: Oliver Johnson
-- Directional PWM Driver entity
-- TODO this doesn't work right now

Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pwm_driver is
  generic (
    PWM_PERIOD          : positive range 1 to 1_000_000 := 1_000; -- PWM major period in microseconds
    PWM_SCHEME          : boolean := false; -- PWM control scheme: false - directional; true - centered
    PRECISION           : positive range 1 to 32 := 16 -- Bits of precision
  );
  port (
    CLK                 : in std_logic; -- 200 MHz system clock
    RST                 : in std_logic; -- Active high synchronous reset
    DUTY_CYCLE          : in std_logic_vector(PRECISION - 1 downto 0); -- 32-bit signed duty cycle: 0x8000 = -100%, 0x0000 = 0%, 0x7FFF = 100%
    PWM_SIGNAL          : out std_logic; -- PWM driver signal
    PWM_DIR             : out std_logic -- Directional signal (only used with directional scheme)
  );
end entity pwm_driver;

architecture behavioral of pwm_driver is

  constant dwell_counter_max        : unsigned(PRECISION - 1 downto 0) := to_unsigned(200 * PWM_PERIOD, PRECISION);
  constant NULL_REG                 : std_logic_vector(PRECISION - 1 downto 0) := (others => '0');

  signal dwell_counter              : unsigned(PRECISION - 1 downto 0) := (others => '0');
  signal pwm_counter_val            : unsigned((2 * PRECISION) - 1 downto 0) := (others => '0');

begin

  pwm_proc : process(CLK)
  begin
    if rising_edge(CLK) then
      if RST = '1' then
        PWM_SIGNAL <= '0';
        PWM_DIR <= '0';
        dwell_counter <= dwell_counter_max - 1;
        pwm_counter_val <= (others => '0');
      else
        if DUTY_CYCLE = NULL_REG then
          PWM_SIGNAL <= '0';
          PWM_DIR <= '0';
        else
          if dwell_counter = to_unsigned(0, PRECISION) then
            pwm_counter_val <= DUTY_CYCLE * unsigned('0' & (not dwell_counter_max(PRECISION - 2 downto 0)));
            PWM_SIGNAL <= '0';
            dwell_counter <= dwell_counter_max - 1;
          else
            dwell_counter <= dwell_counter - 1;
          end if;

          if dwell_counter = pwm_counter_val + pwm_counter_offset((2 * PRECISION) - 1 downto PRECISION) then
            PWM_SIGNAL <= '1';
          end if;
        end if;
      end if;
    end if;
  end process pwm_proc;
end architecture behavioral;
