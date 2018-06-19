library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity linear_regression is
	generic (
		WORDSIZE		: NATURAL	:= 64;
		BITS_OF_ADDR	: NATURAL	:= 10
	);
	port ( 
		clock		: in std_logic;
		x	   	: in signed(WORDSIZE-1 DOWNTO 0);
		y	   	: in signed(WORDSIZE-1 DOWNTO 0);
		run		: in std_logic;
		theta0  	: out signed(WORDSIZE-1 DOWNTO 0) := to_signed(2**32, WORDSIZE);
		theta1	: out signed(WORDSIZE-1 DOWNTO 0) := to_signed(2**32, WORDSIZE)
	);
end linear_regression;

architecture behavioral of linear_regression is
	component ram
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
	
	type state is (ESCRITA, LEITURA, ESPERA);
	component linear_regression_fsm
		generic (
			WORDSIZE		: NATURAL	:= 64;
			BITS_OF_ADDR	: NATURAL	:= 7
		);
		port ( 
			clock		 : in std_logic;
			jump      : in std_logic;
			state_cod : out std_logic_vector(2 downto 0) := "111"
		);
	end component;
	constant alpha  	 : signed(WORDSIZE-1 DOWNTO 0) := to_signed(1, WORDSIZE);
	constant x_addr 	 : integer:= 0;
	constant y_addr 	 : integer := 0;
	constant size_addr : integer := 0;
	constant total_itt : integer := 2;
	signal clock_states: std_logic := '0';
	signal w_size      : std_logic := '0';
	signal w_x  	    : std_logic := '0';
	signal w_y         : std_logic := '0';
	signal size			 : signed(WORDSIZE-1 DOWNTO 0) := to_signed(0, WORDSIZE);
	signal size_after	 : signed(WORDSIZE-1 DOWNTO 0) := to_signed(0, WORDSIZE);
	signal new_x		 : signed(WORDSIZE-1 DOWNTO 0);
	signal new_y		 : signed(WORDSIZE-1 DOWNTO 0);
	signal curr_pos	 : signed(WORDSIZE-1 DOWNTO 0) := to_signed(0, WORDSIZE);
	signal curr_itt	 : integer := 0;
	signal next_state  : std_logic := '0';
	signal state_cod   : std_logic_vector(2 downto 0) := "111";
	signal new_theta0	 : signed(WORDSIZE-1 DOWNTO 0) := to_signed(1, WORDSIZE);
	signal new_theta1	 : signed(WORDSIZE-1 DOWNTO 0) := to_signed(1, WORDSIZE);
begin
	-- State Machine
	fsm: linear_regression_fsm port map (
		clock => clock and run,
		jump => next_state,
		state_cod => state_cod
	);
	
	-- Memories (256 words each)
	mem_size: ram port map (
		clock => clock,
		we => w_size,
		address => size_addr,
		datain => size,
		dataout => size_after
	);
	mem_x: ram port map (
		clock => clock,
		we => w_x,
		address => x_addr+to_integer(curr_pos),
		datain => x,
		dataout => new_x
	);
	mem_y: ram port map (
		clock => clock,
		we => w_y,
		address => y_addr+to_integer(curr_pos),
		datain => y,
		dataout => new_y
	);
	
	process(clock)
		variable sum_0 : signed(WORDSIZE-1 DOWNTO 0) := to_signed(0, WORDSIZE);
		variable sum_1 : signed(WORDSIZE-1 DOWNTO 0) := to_signed(0, WORDSIZE);
		variable h   : signed(WORDSIZE-1 DOWNTO 0) := to_signed(0, WORDSIZE);
		
		variable start_loop : std_logic;

	begin
		if (rising_edge(clock)) then
			if(run = '1') then
				if(state_cod = "000") then
					next_state <= '0';
					
				-- Escrever novo ponto na memoria
				elsif(state_cod = "001") then
					if(w_size = '0') then
						
						size <= size_after + 1;
						curr_pos <= size;
						w_x <= '1';
						w_y <= '1';
						w_size <= '1';
						sum_0 := to_signed(0, WORDSIZE);
						sum_1 := to_signed(0, WORDSIZE);
						new_theta0 <= to_signed(1, WORDSIZE);
						new_theta1 <= to_signed(1, WORDSIZE);
						
						start_loop := '1';
					end if;
					
				-- Iterar sobre os dados
				elsif(state_cod = "010") then
					if(start_loop = '1') then
						curr_pos <= to_signed(0, WORDSIZE);
						w_size <= '0';
						w_x <= '0';
						w_y <= '0';
						start_loop := '0';
					else
						curr_pos <= curr_pos + 1;	
					end if;
				elsif(state_cod = "011") then
					if(curr_pos >= size-1) then
						next_state <= '1';
					end if;
					
					-- Aqui jas regressao linear
					
					h := new_theta0 + signed(std_logic_vector(new_theta1 * new_x)((WORDSIZE*2 - WORDSIZE/2)-1 downto (WORDSIZE/2)));
					--h := new_theta0 + signed(std_logic_vector(new_theta1 * new_x)(WORDSIZE-1 downto 0));
					sum_0 := sum_0 + signed(std_logic_vector((h - new_y) * (h - new_y))((WORDSIZE*2 - WORDSIZE/2)-1 downto (WORDSIZE/2)));
					--sum_0 := sum_0 + signed(std_logic_vector((h - new_y) * (h - new_y))(WORDSIZE-1 downto 0));
					sum_1 := sum_0 + signed(std_logic_vector(signed(std_logic_vector((h - new_y) * (h - new_y))((WORDSIZE*2 - WORDSIZE/2)-1 downto (WORDSIZE/2))) * new_x)((WORDSIZE*2 - WORDSIZE/2)-1 downto (WORDSIZE/2)));
					--sum_1 := sum_1 + signed(std_logic_vector(signed(std_logic_vector((h - new_y) * (h - new_y))(WORDSIZE-1 downto 0)) * new_x)(WORDSIZE-1 downto 0));
					
				elsif (state_cod = "100") then
					curr_pos <= to_signed(0, WORDSIZE);
					--Danger Will Robinson: uncomment for really slow simulation
					new_theta0 <= new_theta0 - signed(std_logic_vector(alpha * sum_0)(WORDSIZE-1 downto 0)) / signed(std_logic_vector(to_signed(2, WORDSIZE) * size)(WORDSIZE-1 downto 0));
					new_theta1 <= new_theta1 - signed(std_logic_vector(alpha * sum_1)(WORDSIZE-1 downto 0)) / signed(std_logic_vector(to_signed(2, WORDSIZE) * size)(WORDSIZE-1 downto 0));
					if(curr_itt < total_itt) then
						curr_itt <= curr_itt + 1;
						next_state <= '0';
						start_loop := '1';
						sum_0 := to_signed(0, WORDSIZE);
						sum_1 := to_signed(0, WORDSIZE);
					else
						curr_itt <= 0;
						next_state <= '1';
					end if;
				end if;
			else
				next_state <= '0';
			end if;
		end if;
	end process;
	
	theta0 <= new_theta0;
	theta1 <= new_theta1;
end behavioral;