library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Ram is
  GENERIC (
			WORDSIZE		: NATURAL	:= 64;
			BITS_OF_ADDR	: NATURAL	:= 10;
			MIF_FILE		: STRING	:= "memory.mif"
		);
		PORT (
			clock   : IN	STD_LOGIC;
			we      : IN	STD_LOGIC;
			address : IN	INTEGER;
			datain  : IN	SIGNED(WORDSIZE-1 DOWNTO 0);
			dataout : OUT	SIGNED(WORDSIZE-1 DOWNTO 0)
		);
end Ram;

architecture rtl of Ram is

	type mem_array is array ((2**(BITS_OF_ADDR))-1 downto 0) of signed((WORDSIZE-1) downto 0);
	signal mem : mem_array;
	
begin
	process(Clock)
		begin
			if rising_edge(clock) then
				if (we = '1') then
					mem(address) <= datain;
				end if;
			end if;
		end process;
		dataout <= datain when we = '1' else
				mem(address);
end rtl;