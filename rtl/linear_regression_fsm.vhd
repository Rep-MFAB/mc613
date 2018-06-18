library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity linear_regression_fsm is
	generic (
		WORDSIZE		: NATURAL	:= 64;
		BITS_OF_ADDR	: NATURAL	:= 10
	);
	port ( 
		clock			 : in std_logic;
		jump         : in std_logic := '0';
		state_cod    : out std_logic_vector(2 downto 0) := "111"
	);
end linear_regression_fsm;

architecture behavorial of linear_regression_fsm is
	type state is (COMECAR, ESCRITA, LEITURA, PROCESSO, ITERAR, ESPERA);
begin
	process(clock)
		variable state_now: state := ESPERA;
	begin
		if (falling_edge(clock)) then
			case state_now is
				when COMECAR => state_now := ESCRITA;
				when ESCRITA => state_now := LEITURA;
				when LEITURA => state_now := PROCESSO;
				when PROCESSO => 
					if(jump = '0') then 
						state_now := LEITURA;
					else 
						state_now := ITERAR;
					end if;
				when ITERAR => 
					if(jump = '0') then 
						state_now := LEITURA;
					else 
						state_now := ESPERA;
					end if;
				when ESPERA => 
					if(jump = '1') then 
						state_now := ESPERA;
					else 
						state_now := COMECAR;
					end if;
			end case;
			
			case state_now is
				when COMECAR  => state_cod <= "000";
				when ESCRITA  => state_cod <= "001";
				when LEITURA  => state_cod <= "010";
				when PROCESSO => state_cod <= "011";
				when ITERAR   => state_cod <= "100";
				when ESPERA   => state_cod <= "111";
			end case;
		end if;
	end process;

end behavorial; 
		
					
					