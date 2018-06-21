library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_main_fsm is
	port ( 
		clock			 : in std_logic;
		jump         : in std_logic := '0';
		state_cod    : out std_logic_vector(3 downto 0) := "1111"
	);
end vga_main_fsm;

architecture behavorial of vga_main_fsm is
	type state is (START, INPUTX1, WRITEX1, INPUTX2, WRITEX2, INPUTY1, WRITEY1, INPUTY2, WRITEY2, WAIT_RETURN, CLEAR, WRITE_GRAPH);
	constant CLOCK_DIV : integer := 5000000;
	
	signal slow_clock : std_logic := '0';
begin
	process(slow_clock)
		variable state_now: state := START;
	begin
		if (falling_edge(slow_clock) and (jump = '1' or state_now = START)) then
			case state_now is
				when START => state_now := INPUTX1;
				when INPUTX1 => state_now := WRITEX1;
				when WRITEX1 => state_now := INPUTX2;
				when INPUTX2 => state_now := WRITEX2;
				when WRITEX2 => state_now := INPUTY1;
				when INPUTY1 => state_now := WRITEY1;
				when WRITEY1 => state_now := INPUTY2;
				when INPUTY2 => state_now := WRITEY2;
				when WRITEY2 => state_now := WAIT_RETURN;
				when WAIT_RETURN => state_now := CLEAR;
				when CLEAR => state_now := WRITE_GRAPH;
				when WRITE_GRAPH => state_now := START;
			end case;
			
			case state_now is
				when START      => state_cod <= "1111";
				when INPUTX1    => state_cod <= "0000";
				when INPUTX2    => state_cod <= "0001";
				when INPUTY1    => state_cod <= "0010";
				when INPUTY2    => state_cod <= "0011";
				when WRITEX1    => state_cod <= "0100";
				when WRITEX2    => state_cod <= "0101";
				when WRITEY1    => state_cod <= "0110";
				when WRITEY2    => state_cod <= "0111";
				when WAIT_RETURN=> state_cod <= "1000";
				when CLEAR      => state_cod <= "1001";
				when WRITE_GRAPH=> state_cod <= "1010";
			end case;
		end if;
	end process;
	
	-- Clock Divider
	process(clock)
		variable i : integer := 0;
	begin
		if(falling_edge(clock)) then
			if (i <= CLOCK_DIV/2) then
				i := i + 1;
				slow_clock <= '0';
			elsif (i < CLOCK_DIV-1) then
				i := i + 1;
				slow_clock <= '1';
			else
				i := 0;
			end if;
		end if;
	end process;

end behavorial; 
		
					
					