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
		goto_next    : in std_logic := '0';
		state_cod    : out std_logic_vector(2 downto 0) := "111"
	);
end linear_regression_fsm;

architecture behavorial of linear_regression_fsm is
	type state is (COMECAR, ESCRITA, LEITURA, PROCESSO, ITERAR, ESPERA);
	signal state_now, next_state: state := ESPERA;
	signal jump : std_logic;
begin
	jump <= goto_next;
	
	process(state_now, jump)
	begin
		case state_now is
			when COMECAR => next_state <= ESCRITA;
			when ESCRITA => next_state <= LEITURA;
			when LEITURA => next_state <= PROCESSO;
			when PROCESSO => 
				if(jump = '0') then 
					next_state <= LEITURA;
				else 
					next_state <= ITERAR;
				end if;
			when ITERAR => 
				if(jump = '0') then 
					next_state <= LEITURA;
				else 
					next_state <= ESPERA;
				end if;
			when ESPERA => 
				if(jump = '0') then 
					next_state <= ESPERA;
				else 
					next_state <= COMECAR;
				end if;
		end case;
	end process;
	
	process(clock)
	begin
		if (rising_edge(clock)) then
			state_now <= next_state;
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
		
					
					