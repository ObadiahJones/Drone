LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;

entity UART_Master is
	GENERIC(
		sysCLK		: integer := 50; -- in MHz
		buad		: integer := 9600);
	Port(
		iCLK		: in std_logic; -- system Clock
		-- control signals
		enableS		: in std_logic; -- enable send
		enableR		: in std_logic; -- enable recieve
		parity		: in std_logic; --
		stopBits	: in std_logic; -- 0 = 1 stop bit, 1 = 2 stop bits
		parityBit	: in std_logic; -- 0 no parity bit, 1 has parity bit
		sendBusy	: out std_logic;
		recieveBusy	: out std_logic;
		error		: out std_logic;
		-- interface signals
		rX			: in std_logic;
		tX			: out std_logic;
		-- data registers
		sendB		: in std_logic_vector(7 downto 0);
		receiveB	: out std_logic_vector(7 downto 0));
end UART_Master;

architecture behavioral of UART_Master is
type sendMachine is (Ready, StartBit, DataBit, ParityBit, StopBit, StopBit2);
type receiveMachine is (Ready, StartBit, DataBit, ParityBit, StopBit, StopBit2, ClearData);

sendState		: sendMachine := Ready;
sendReceive		: receiveMachine := Ready;

sendPointer		: integer := 7;
receivePointer	: integer := 7;
receiveBTemp	: std_logic_vector(7 downto 0);

dataBitsHigh	: integer := 0;

baudCLK			: std_logic;

begin

--Baud Clock generator -- assumes input clock of 50 MHz
process(iCLK)
begin



end process;

--Send
process(baudCLK)
begin
if rising_edge(baudCLK) then
	case sendState is
		when Ready =>
			sendBusy <= '0';
			if (sendEnable = '1') then
				sendState <= StartBit;
			end if;
		when StartBit =>
			tX <= '0';
			sendBusy <= '1';
			sendState <= DataBit
		when DataBit =>
			sendPointer = sendPointer - 1;
			tX <= sendB(sendPointer);
			if (sendPointer = 0) then
				sendState <= ParityBit;
			else
				sendState <= DataBit;
			end if;
		when ParityBit =>
			tX <= parity;
			sendState <= StopBit
		when StopBit =>
			tX <= '1'
			if (stopBits = 1 and ) then
				sendState <= Stopbit2
			else
				sendState <= Ready;
			end if;
		when StopBit2 =>
			tX <= '1';
			sendState <= Ready
	end case;
end if;
end process;


--Recieve
process(baudCLK)
begin
if rising_edge(baudCLK) then
	case receiveState is
		when Ready =>
			receiveBusy <= '0';
			if receiveEnable = '1' then
				receiveState <= StartBit;
			end if;
		when StartBit =>
			if (rX = '0') then
				receiveState <= dataBit
			end if;
		when DataBit =>
			receivePointer <= receivePointer - 1;
			receiveB(receivePointer) <= rX;

			if (rX = 1)
				dataBitsHigh <= dataBitsHigh + 1;
			end if;

			if (sendPointer = 0) then
				sendState <= ParityBit;
			else
				sendState <= DataBit;
			end if;
		when ParityBit =>
			if rX = 1 then

			else

			end if;
		when StopBit =>
		when StopBit2 =>
		when ClearData =>
end if;
end process;


end architecture;
