library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity linear_regression is
	generic (
		WORDSIZE		: NATURAL	:= 64;
		BITS_OF_ADDR	: NATURAL	:= 10
	);
	port ( 
		x	   	: in signed(WORDSIZE-1 DOWNTO 0);
		y	   	: in signed(WORDSIZE-1 DOWNTO 0);
		run		: in std_logic;
		theta0  	: out signed(WORDSIZE-1 DOWNTO 0);
		theta1	: out signed(WORDSIZE-1 DOWNTO 0)
	);
end linear_regression;

architecture behavioral of linear_regression is
	component Ram
		generic (
			WORDSIZE		: NATURAL	:= 64;
			BITS_OF_ADDR	: NATURAL	:= 10
		);
		port (
			clock   : IN	STD_LOGIC;
			we      : IN	STD_LOGIC;
			address : IN	INTEGER;
			datain  : IN	SIGNED(WORDSIZE-1 DOWNTO 0);
			dataout : OUT	SIGNED(WORDSIZE-1 DOWNTO 0)
		);
	end component;
	constant alpha  	 : integer := 42;
	constant x_addr 	 : integer:= 256;
	constant y_addr 	 : integer := 512;
	constant size_addr : integer := 1023;
	signal size			 : signed(WORDSIZE-1 DOWNTO 0);
	signal size_after	 : signed(WORDSIZE-1 DOWNTO 0);
	signal w_size      : std_logic;
	signal tmp			 : signed(WORDSIZE-1 DOWNTO 0);
	signal new_x		 : signed(WORDSIZE-1 DOWNTO 0);
	signal new_y		 : signed(WORDSIZE-1 DOWNTO 0);
	signal curr_pos	 : signed(WORDSIZE-1 DOWNTO 0);
begin
	write_size: ram port map (
		clock => w_size,
		we => '1',
		address => size_addr,
		datain => size,
		dataout => open
	);
	read_size: ram port map (
		clock => w_size,
		we => '0',
		address => size_addr,
		datain => tmp,
		dataout => size_after
	);
	write_x: ram port map (
		clock => (run or w_size),
		we => w_size,
		address => x_addr+to_integer(size),
		datain => x,
		dataout => open
	);	
	read_x: ram port map (
		clock => (run or w_size),
		we => '0',
		address => x_addr+to_integer(curr_pos),
		datain => x,
		dataout => new_x
	);
	write_y: ram port map (
		clock => (run or w_size),
		we => w_size,
		address => y_addr+to_integer(size),
		datain => y,
		dataout => open
	);
	read_y: ram port map (
		clock => (run or w_size),
		we => '0',
		address => y_addr+to_integer(curr_pos),
		datain => y,
		dataout => new_y
	);
	process(run, x, y)
	begin
		if (rising_edge(run)) then
			size <= size + 1;
			w_size <= '1';
			for i in 0 to 256 loop
				if(i <= size) then
					curr_pos <= to_signed(i, WORDSIZE);
				end if;
			end loop;	
		end if;
		w_size <= '0';
	end process;
	
	theta0 <= new_x;
	theta1 <= new_y;
end behavioral;