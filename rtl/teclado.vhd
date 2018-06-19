LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
 
entity teclado is
	port
	(
		------------------------	Clock Input	 	------------------------
		CLOCK_50	: 	in	STD_LOGIC;											--	50 MHz
		
		------------------------	Push Button		------------------------
		KEY 	:		in	STD_LOGIC_VECTOR (3 downto 0);		--	Pushbutton[3:0]

		------------------------	DPDT Switch		------------------------
		SW 	:		in	STD_LOGIC_VECTOR (9 downto 0);			--	Toggle Switch[9:0]
					
		------------------------	PS2		--------------------------------
		PS2_DAT 	:		inout	STD_LOGIC;	--	PS2 Data
		PS2_CLK		:		inout	STD_LOGIC;		--	PS2 Clock
				------------------------	7-SEG Dispaly	------------------------
		HEX0 	:		out	STD_LOGIC_VECTOR (6 downto 0);		--	Seven Segment Digit 0
		HEX1 	:		out	STD_LOGIC_VECTOR (6 downto 0);		--	Seven Segment Digit 1
		HEX2 	:		out	STD_LOGIC_VECTOR (6 downto 0);		--	Seven Segment Digit 2
		HEX3 	:		out	STD_LOGIC_VECTOR (6 downto 0);		--	Seven Segment Digit 3
		------------------------	VGA	------------------------
							-- Aqui as saidas para a vga--
		------------------------	SAIDA PARA REGRESSAO LINEAR	------------------------
		result			: out signed(15 downto 0)
	);
end;

architecture behavorial of teclado is
	component kbdex_ctrl
		generic(
			clkfreq : integer
		);
		port(
			ps2_data	:	inout	std_logic;
			ps2_clk		:	inout	std_logic;
			clk				:	in 	std_logic;
			en				:	in 	std_logic;
			resetn		:	in 	std_logic;
			key_on		:	out	std_logic_vector(2 downto 0);
			key_code	:	out	std_logic_vector(47 downto 0)
		);
	end component;
	component bin2hex
		port(
			SW  : in std_logic_vector(3 downto 0);
			HEX0: out std_logic_vector(6 downto 0)
		);
	end component;	
	signal CLOCKHZ, resetn 	: std_logic;
	signal key0 				: std_logic_vector(15 downto 0);
	signal key_on		: std_logic_vector( 2 downto 0);
	signal k				: std_logic_vector(15 downto 0);
	signal tmp				: std_logic_vector(15 downto 0);
	signal res	: std_logic_vector(15 downto 0);
	begin 
	
	resetn <= KEY(0);
	
	kbd_ctrl : kbdex_ctrl generic map(50000) port map(
		PS2_DAT, PS2_CLK, CLOCK_50, KEY(1), resetn,
		key_on, key_code(15 downto 0) => key0
	);
	process(PS2_DAT)
	variable iterator : integer := 1;
	variable r	: std_logic_vector(15 downto 0) := "0000000000000000";
	begin
		if (rising_edge(PS2_DAT))then 	
			case key0 is
				when "0000000001110000" => k <= "0000000000000000"; -- 0 (70)
				when "0000000001101001" => k <= "0000000000000001"; -- 1 (69)
				when "0000000001110010" => k <= "0000000000000010"; -- 2 (72)
				when "0000000001111010" => k <= "0000000000000011"; -- 3 (7A)
				when "0000000001101011" => k <= "0000000000000100"; -- 4 (6B) 
				when "0000000001110011" => k <= "0000000000000101"; -- 5 (73)
				when "0000000001110100" => k <= "0000000000000110"; -- 6 (74)
				when "0000000001101100" => k <= "0000000000000111"; -- 7 (6C)
				when "0000000001110101" => k <= "0000000000001000"; -- 8 (75)
				when "0000000001111101" => k <= "0000000000001001"; -- 9 (7D)
				when "0000000001110001" => k <= "0000000000001010"; -- . (71)
				when "0000000001111011" => k <= "0000000000001011"; -- - (7B)
				when "0000000000001101" => k <= "0000000000001101"; -- TAB (0D)
				when "0000000001011010" => k <= "0000000000001100"; -- ENT (5A)
				when "0000000001100110" => k <= "0000000000001110"; -- BCK (66)  
				when others => k <= "1000000000000000"; -- Error
			end case;
			if (k /= "0000000000001100" and k /= "1000000000000000" and k /= "0000000000001010" 
			and k /= "0000000000001011" and k /= "0000000000001101" and k/= "0000000000001110") then
					tmp <= std_logic_vector(signed(k)*iterator)(15 downto 0);
					r := std_logic_vector(signed(r)+signed(tmp));
					iterator := iterator + 1;
			end if;
		end if;
		res <= r;
	end process;
	
	
	hexseg0: bin2hex port map(
		res(3 downto 0), HEX0
	);
	hexseg1: bin2hex port map(
		res(7 downto 4), HEX1
	);
	hexseg2: bin2hex port map(
		res(11 downto 8), HEX2
	);
	hexseg3: bin2hex port map(
		res(15 downto 12), HEX3
	);

	process(CLOCK_50)
		constant F_HZ : integer := 5;
		
		constant DIVIDER : integer := 50000000/F_HZ;
		variable count : integer range 0 to DIVIDER := 0;		
	begin
		if(rising_edge(CLOCK_50)) then
			if count < DIVIDER / 2 then
				CLOCKHZ <= '1';
			else 
				CLOCKHZ <= '0';
			end if;
			if count = DIVIDER then
				count := 0;
			end if;
			count := count + 1;			
		end if;
	end process;	
end behavorial;
	