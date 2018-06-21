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
		HEX 	:		out	STD_LOGIC_VECTOR (6 downto 0);		--	Seven Segment Digit 0
		------------------------	VGA	------------------------
							-- Aqui as saidas para a vga--
		------------------------	SAIDA PARA REGRESSAO LINEAR	------------------------
		result			: out signed(4 downto 0)
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
	signal res	: std_logic_vector(4 downto 0);
	begin 
	
	resetn <= KEY(0);
	
	kbd_ctrl : kbdex_ctrl generic map(50000) port map(
		PS2_DAT, PS2_CLK, CLOCK_50, KEY(1), resetn,
		key_on, key_code(15 downto 0) => key0
	);
	process(PS2_CLK)
	begin
		if (rising_edge(PS2_CLK))then 	
			case key0 is
				when "0000000001110000" => res <= "00000"; -- 0 (70)
				when "0000000001101001" => res <= "00001"; -- 1 (69)
				when "0000000001110010" => res <= "00010"; -- 2 (72)
				when "0000000001111010" => res <= "00011"; -- 3 (7A)
				when "0000000001101011" => res <= "00100"; -- 4 (6B) 
				when "0000000001110011" => res <= "00101"; -- 5 (73)
				when "0000000001110100" => res <= "00110"; -- 6 (74)
				when "0000000001101100" => res <= "00111"; -- 7 (6C)
				when "0000000001110101" => res <= "01000"; -- 8 (75)
				when "0000000001111101" => res <= "01001"; -- 9 (7D)
				when "0000000001110001" => res <= "01010"; -- . (71)
				when "0000000001111011" => res <= "01011"; -- - (7B)
				when "0000000000001101" => res <= "01101"; -- TAB (0D)
				when "0000000001011010" => res <= "01100"; -- ENT (5A)
				when "0000000001100110" => res <= "01110"; -- BCK (66)  
				when others =>             res <= "01111"; -- Error
			end case;
		end if;
	end process;
	
	
	hexseg0: bin2hex port map(
		res(3 downto 0), HEX
	);
	
	result <= signed(res);

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
	
	-- No comments for you
	-- It was hard to write
	-- so it should be hard to read
	
end behavorial;
	