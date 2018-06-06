library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FPU is
	generic (
		WORDSIZE		: NATURAL	:= 64
	);
	
		port (
		a	   : in signed(WORDSIZE-1 DOWNTO 0);
		b	   : in signed(WORDSIZE-1 DOWNTO 0);
		opt   : in std_logic_vector(1 downto 0);
		c  	: out signed(WORDSIZE-1 DOWNTO 0)
	);
end entity;

architecture rtl of FPU is
	signal result : signed(2*WORDSIZE-1 DOWNTO 0);
	signal aux : std_logic_vector((WORDSIZE*2)-1 downto 0);
	signal quocient : signed(WORDSIZE-1 DOWNTO 0);
begin
	process(opt)
		begin
			if (opt = "00") then
				c <= a + b;
			end if;
			if (opt = "01") then
				c <= a - b;
			end if;
			if (opt = "10") then
				result <= a * b;
				aux <= std_logic_vector(result);
				c <= signed(aux((WORDSIZE*2 - WORDSIZE/2)-1 downto (WORDSIZE/2)));
			end if;
			if (opt = "11") then
				quocient <= shift_right(b, 32);
				c <= a / quocient;
			end if;
	end process;	
end rtl;
	