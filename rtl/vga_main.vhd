-------------------------------------------------------------------------------
-- Title      : exemplo
-- Project    : 
-------------------------------------------------------------------------------
-- File       : exemplo.vhd
-- Author     : Rafael Auler
-- Company    : 
-- Created    : 2010-03-26
-- Last update: 2018-04-05
-- Platform   : 
-- Standard   : VHDL'2008
-------------------------------------------------------------------------------
-- Description: Fornece um exemplo de uso do módulo VGACON para a disciplina
--              MC613.
--              Este módulo possui uma máquina de estados simples que se ocupa
--              de escrever na memória de vídeo (atualizar o quadro atual) e,
--              em seguida, de atualizar a posição de uma "bola" que percorre
--              toda a tela, quicando pelos cantos.
-------------------------------------------------------------------------------
-- Copyright (c) 2010 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2010-03-26  1.0      Rafael Auler    Created
-- 2018-04-05  1.1      IBFelzmann      Adapted for DE1-SoC
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_main is
	generic (
		WORDSIZE		: NATURAL	:= 64
	);
	port (    
		CLOCK_50                  : in  std_logic;
		key_result					  : in signed(4 downto 0);
		LEDR                      : out std_logic_vector(9 downto 0);
		HEX                       : out STD_LOGIC_VECTOR (6 downto 0);
		VGA_R, VGA_G, VGA_B       : out std_logic_vector(7 downto 0);
		VGA_HS, VGA_VS            : out std_logic;
		VGA_BLANK_N, VGA_SYNC_N   : out std_logic;
		VGA_CLK                   : out std_logic
	);
end vga_main;

architecture comportamento of vga_main is

	component linear_regression is
		generic (
			WORDSIZE		: NATURAL	:= 64;
			BITS_OF_ADDR	: NATURAL	:= 10
		);
		port ( 
			clock		: in std_logic;
			x	   	: in signed(WORDSIZE-1 DOWNTO 0);
			y	   	: in signed(WORDSIZE-1 DOWNTO 0);
			run		: in std_logic;
			theta0  	: out signed(WORDSIZE-1 DOWNTO 0) := to_signed(2**33, WORDSIZE);
			theta1	: out signed(WORDSIZE-1 DOWNTO 0) := to_signed(2**33, WORDSIZE);
			finished : out std_logic
		);
	end component;
	
	
	signal x	       : signed(WORDSIZE-1 DOWNTO 0) := to_signed(2**33, WORDSIZE);
	signal y	       : signed(WORDSIZE-1 DOWNTO 0) := to_signed(2**33, WORDSIZE);
	signal theta0	 : signed(WORDSIZE-1 DOWNTO 0) := to_signed(2**33, WORDSIZE);
	signal theta1	 : signed(WORDSIZE-1 DOWNTO 0) := to_signed(2**33, WORDSIZE);
	signal start_lin_reg : std_logic := '0';
	signal finished_lin_reg : std_logic := '0';
	
	-- State Machine
	
	component vga_main_fsm
		port ( 
			clock		 : in std_logic;
			jump      : in std_logic;
			state_cod : out std_logic_vector(3 downto 0) := "1111"
		);
	end component;
	
	signal next_state  : std_logic := '0';
	signal state_code   : std_logic_vector(3 downto 0) := "1111";
	
	-- 7 Segments Display
	
	component bin2hex
		port(
			SW  : in std_logic_vector(3 downto 0);
			HEX0: out std_logic_vector(6 downto 0)
		);
	end component;	
  -- Interface com a memória de vídeo do controlador

  signal we : std_logic := '1';                        -- write enable ('1' p/ escrita)
  signal addr : integer range 0 to 12287;       -- endereco mem. vga
  signal pixel : std_logic_vector(2 downto 0);  -- valor de cor do pixel
  signal pixel_code : std_logic_vector(2 downto 0) := "011";                 -- os 3 bits do vetor acima
  signal pixel_x : std_logic;
  signal pixel_y : std_logic;

  -- Sinais dos contadores de linhas e colunas utilizados para percorrer
  -- as posições da memória de vídeo (pixels) no momento de construir um quadro.
  
  signal line : integer range 0 to 95;  -- linha atual
  signal col : integer range 0 to 127;  -- coluna atual

  signal col_rstn : std_logic;          -- reset do contador de colunas
  signal col_enable : std_logic;        -- enable do contador de colunas

  signal line_rstn : std_logic;          -- reset do contador de linhas
  signal line_enable : std_logic;        -- enable do contador de linhas

  signal fim_escrita : std_logic;       -- '1' quando um quadro terminou de ser
                                        -- escrito na memória de vídeo

  -- Sinais que armazem a posição de uma bola, que deverá ser desenhada
  -- na tela de acordo com sua posição.

  signal pos_x : integer range 1 to 123 := 1;  -- coluna atual da bola
  signal pos_y : integer range -30 to 90 := 1;   -- linha atual da bola

  signal atualiza_pos_x : std_logic;    -- se '1' = bola muda sua pos. no eixo x
  signal atualiza_pos_y : std_logic;    -- se '1' = bola muda sua pos. no eixo y

  -- Especificação dos tipos e sinais da máquina de estados de controle
  type estado_t is (show_splash, inicio, constroi_quadro, move_bola);
  signal estado: estado_t := show_splash;
  signal proximo_estado: estado_t := show_splash;

  -- Sinais para um contador utilizado para atrasar a atualização da
  -- posição da bola, a fim de evitar que a animação fique excessivamente
  -- veloz. Aqui utilizamos um contador de 0 a 1250000, de modo que quando
  -- alimentado com um clock de 50MHz, ele demore 25ms (40fps) para contar até o final.
  
  signal contador : integer range 0 to 1250000 - 1;  -- contador
  signal timer : std_logic;        -- vale '1' quando o contador chegar ao fim
  signal timer_rstn, timer_enable : std_logic;
  
  signal sync, blank: std_logic;

begin  -- comportamento

	-- State Machine
	fsm: vga_main_fsm port map (
		clock => CLOCK_50,
		jump => next_state,
		state_cod => state_code
	);
	
	LEDR(0) <= '1' when state_code = "0000" else '0';
	LEDR(1) <= '1' when state_code = "0100" else '0';
	LEDR(2) <= '1' when state_code = "0001" else '0';
	LEDR(3) <= '1' when state_code = "0101" else '0';
	LEDR(4) <= '1' when state_code = "0010" else '0';
	LEDR(5) <= '1' when state_code = "0110" else '0';
	LEDR(6) <= '1' when state_code = "0011" else '0';
	LEDR(7) <= '1' when state_code = "0100" else '0';
	LEDR(8) <= '1' when state_code = "1000" else '0';
	LEDR(9) <= '1' when state_code = "1010" else '0';
	hexseg0: bin2hex port map(
		state_code, HEX
	);


  -- Aqui instanciamos o controlador de vídeo, 128 colunas por 96 linhas
  -- (aspect ratio 4:3). Os sinais que iremos utilizar para comunicar
  -- com a memória de vídeo (para alterar o brilho dos pixels) são
  -- write_clk (nosso clock), write_enable ('1' quando queremos escrever
  -- o valor de um pixel), write_addr (endereço do pixel a escrever)
  -- e data_in (valor do brilho do pixel RGB, 1 bit pra cada componente de cor)
  vga_controller: entity work.vgacon port map (
    clk50M       => CLOCK_50,
    rstn         => '1',
    red          => VGA_R,
    green        => VGA_G,
    blue         => VGA_B,
    hsync        => VGA_HS,
    vsync        => VGA_VS,
    write_clk    => CLOCK_50,
    write_enable => we,
    write_addr   => addr,
    data_in      => pixel,
    vga_clk      => VGA_CLK,
    sync         => sync,
    blank        => blank);
  VGA_SYNC_N <= NOT sync;
  VGA_BLANK_N <= NOT blank;
  
  -- Algoritmo de regressao linear
  lin_reg: linear_regression port map (
		clock		=> CLOCK_50,
		x	   	=> x,
		y	   	=> y,
		run		=> start_lin_reg,
		theta0  	=> theta0,
		theta1	=> theta1,
		finished => finished_lin_reg
  );
  
  fim_escrita <= '1' when (line = 95) and (col = 127)
                 else '0'; 
	
  -----------------------------------------------------------------------------
  -- Abaixo estão processos relacionados com a atualização da posição da
  -- bola. Todos são controlados por sinais de enable de modo que a posição
  -- só é de fato atualizada quando o controle (uma máquina de estados)
  -- solicitar.
  -----------------------------------------------------------------------------

  -- purpose: Este processo irá atualizar a posiçao do x e y da funçao
  -- type   : sequential
  -- inputs : CLOCK_50
  -- outputs: pos_x
  process (CLOCK_50)
     variable cur_key : signed(4 downto 0);
	  variable pixel_num : integer := 0;
  begin  -- process p_atualiza_pos_x
    if rising_edge(CLOCK_50) then  -- rising clock edge
		next_state <= '0';
		case state_code is
			when "0000" =>
				if (key_result < 10) then
					cur_key := key_result;
					x(9 downto 0) <= signed(cur_key) * 10;
					pixel_num := 0;
					next_state <= '1';
				end if;
			when "0100" =>
				case cur_key is
					when "00000" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17;
								pos_y <= -12;
							when 4 =>
								pos_x <= 17;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17;
								pos_y <= -10;
							when 6 =>
								pos_x <= 17;
								pos_y <= -9;
							when 7 =>
								pos_x <= 17;
								pos_y <= -8;
							when 8 =>
								pos_x <= 16;
								pos_y <= -8;
							when 9 =>
								pos_x <= 15;
								pos_y <= -8;
							when 10 =>
								pos_x <= 15;
								pos_y <= -9;
							when 11 =>
								pos_x <= 15;
								pos_y <= -10;
							when 12 =>
								pos_x <= 15;
								pos_y <= -11;
							when 13 =>
								pos_x <= 15;
								pos_y <= -12;
							when others =>
								next_state <= '1';					
						end case;
					when "00001" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17;
								pos_y <= -12;
							when 4 =>
								pos_x <= 16;
								pos_y <= -11;
							when 5 =>
								pos_x <= 16;
								pos_y <= -10;
							when 6 =>
								pos_x <= 16;
								pos_y <= -9;
							when 7 =>
								pos_x <= 16;
								pos_y <= -8;
							when 8 =>
								pos_x <= 15;
								pos_y <= -9;
							when others =>
								next_state <= '1';	
						end case;
					when "00010" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17;
								pos_y <= -12;
							when 5 =>
								pos_x <= 15;
								pos_y <= -11;
							when 6 =>
								pos_x <= 15;
								pos_y <= -10;
							when 7 =>
								pos_x <= 16;
								pos_y <= -10;
							when 8 =>
								pos_x <= 17;
								pos_y <= -10;
							when 9 =>
								pos_x <= 17;
								pos_y <= -9;
							when 10 =>
								pos_x <= 17;
								pos_y <= -8;
							when 11 =>
								pos_x <= 16;
								pos_y <= -8;
							when 12 =>
								pos_x <= 15;
								pos_y <= -8;
							when others =>
								next_state <= '1';
							end case;
					when "00011" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17;
								pos_y <= -12;
							when 4 =>
								pos_x <= 17;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17;
								pos_y <= -10;
							when 6 =>
								pos_x <= 16;
								pos_y <= -10;
							when 7 =>
								pos_x <= 15;
								pos_y <= -10;
							when 8 =>
								pos_x <= 17;
								pos_y <= -9;
							when 9 =>
								pos_x <= 17;
								pos_y <= -8;
							when 10 =>
								pos_x <= 16;
								pos_y <= -8;
							when 11 =>
								pos_x <= 15;
								pos_y <= -8;
							when others =>
								next_state <= '1';
							end case;
					when "00100" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 17;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 17;
								pos_y <= -11;
							when 3 =>
								pos_x <= 17;
								pos_y <= -10;
							when 4 =>
								pos_x <= 17;
								pos_y <= -9;
							when 5 =>
								pos_x <= 17;
								pos_y <= -8;
							when 6 =>
								pos_x <= 16;
								pos_y <= -10;
							when 7 =>
								pos_x <= 15;
								pos_y <= -10;
							when 8 =>
								pos_x <= 15;
								pos_y <= -9;
							when 9 =>
								pos_x <= 15;
								pos_y <= -8;
							when others =>
								next_state <= '1';	
						end case;
					when "00101" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17;
								pos_y <= -12;
							when 4 =>
								pos_x <= 17;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17;
								pos_y <= -10;
							when 6 =>
								pos_x <= 16;
								pos_y <= -10;
							when 7 =>
								pos_x <= 15;
								pos_y <= -10;
							when 8 =>
								pos_x <= 15;
								pos_y <= -9;
							when 9 =>
								pos_x <= 15;
								pos_y <= -8;
							when 10 =>
								pos_x <= 16;
								pos_y <= -8;
							when 11 =>
								pos_x <= 17;
								pos_y <= -8;
							when others =>
								next_state <= '1';
						end case;
					when "00110" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17;
								pos_y <= -12;
							when 4 =>
								pos_x <= 15;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17;
								pos_y <= -11;
							when 6 =>
								pos_x <= 15;
								pos_y <= -10;
							when 7 =>
								pos_x <= 16;
								pos_y <= -10;
							when 8 =>
								pos_x <= 17;
								pos_y <= -10;
							when 9 =>
								pos_x <= 15;
								pos_y <= -9;
							when 10 =>
								pos_x <= 15;
								pos_y <= -8;
							when 11 =>
								pos_x <= 16;
								pos_y <= -8;
							when 12 =>
								pos_x <= 17;
								pos_y <= -8;
							when others =>
								next_state <= '1';
						end case;
					when "00111" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 17;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 17;
								pos_y <= -11;
							when 3 =>
								pos_x <= 17;
								pos_y <= -10;
							when 4 =>
								pos_x <= 17;
								pos_y <= -9;
							when 5 =>
								pos_x <= 17;
								pos_y <= -8;
							when 6 =>
								pos_x <= 16;
								pos_y <= -8;
							when 7 =>
								pos_x <= 15;
								pos_y <= -8;
							when others =>
								next_state <= '1';
						end case;
						when "01000" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16;
									pos_y <= -12;
								when 3 =>
									pos_x <= 17;
									pos_y <= -12;
								when 4 =>
									pos_x <= 17;
									pos_y <= -11;
								when 5 =>
									pos_x <= 17;
									pos_y <= -10;
								when 6 =>
									pos_x <= 17;
									pos_y <= -9;
								when 7 =>
									pos_x <= 17;
									pos_y <= -8;
								when 8 =>
									pos_x <= 16;
									pos_y <= -8;
								when 9 =>
									pos_x <= 15;
									pos_y <= -8;
								when 10 =>
									pos_x <= 15;
									pos_y <= -9;
								when 11 =>
									pos_x <= 15;
									pos_y <= -10;
								when 12 =>
									pos_x <= 15;
									pos_y <= -11;
								when 13 =>
									pos_x <= 15;
									pos_y <= -12;
								when 14 =>
									pos_x <= 16;
									pos_y <= -10;
								when others =>
									next_state <= '1';		
							end case;
						when "01001" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16;
									pos_y <= -12;
								when 3 =>
									pos_x <= 17;
									pos_y <= -12;
								when 4 =>
									pos_x <= 17;
									pos_y <= -11;
								when 5 =>
									pos_x <= 17;
									pos_y <= -10;
								when 6 =>
									pos_x <= 17;
									pos_y <= -9;
								when 7 =>
									pos_x <= 17;
									pos_y <= -8;
								when 8 =>
									pos_x <= 16;
									pos_y <= -8;
								when 9 =>
									pos_x <= 15;
									pos_y <= -8;
								when 10 =>
									pos_x <= 15;
									pos_y <= -9;
								when 11 =>
									pos_x <= 15;
									pos_y <= -10;
								when 12 =>
									pos_x <= 15;
									pos_y <= -12;
								when 13 =>
									pos_x <= 16;
									pos_y <= -10;
								when others =>
									next_state <= '1';		
							end case;
						when others => next_state <= '1';
					end case;
			when "0001" =>
				if (key_result < 10) then
					cur_key := key_result;
					x(9 downto 0) <= x(9 downto 0) + signed(cur_key) * 1;
					pixel_num := 0;
					next_state <= '1';
				end if;
			when "0101" =>
				case cur_key is
						when "00000" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15+5;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16+5;
									pos_y <= -12;
								when 3 =>
									pos_x <= 17+5;
									pos_y <= -12;
								when 4 =>
									pos_x <= 17+5;
									pos_y <= -11;
								when 5 =>
									pos_x <= 17+5;
									pos_y <= -10;
								when 6 =>
									pos_x <= 17+5;
									pos_y <= -9;
								when 7 =>
									pos_x <= 17+5;
									pos_y <= -8;
								when 8 =>
									pos_x <= 16+5;
									pos_y <= -8;
								when 9 =>
									pos_x <= 15+5;
									pos_y <= -8;
								when 10 =>
									pos_x <= 15+5;
									pos_y <= -9;
								when 11 =>
									pos_x <= 15+5;
									pos_y <= -10;
								when 12 =>
									pos_x <= 15+5;
									pos_y <= -11;
								when 13 =>
									pos_x <= 15+5;
									pos_y <= -12;
								when others =>
									next_state <= '1';					
							end case;
						when "00001" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15+5;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16+5;
									pos_y <= -12;
								when 3 =>
									pos_x <= 17+5;
									pos_y <= -12;
								when 4 =>
									pos_x <= 16+5;
									pos_y <= -11;
								when 5 =>
									pos_x <= 16+5;
									pos_y <= -10;
								when 6 =>
									pos_x <= 16+5;
									pos_y <= -9;
								when 7 =>
									pos_x <= 16+5;
									pos_y <= -8;
								when 8 =>
									pos_x <= 15+5;
									pos_y <= -9;
								when others =>
									next_state <= '1';	
							end case;
						when "00010" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15+5;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16+5;
									pos_y <= -12;
								when 3 =>
									pos_x <= 17+5;
									pos_y <= -12;
								when 5 =>
									pos_x <= 15+5;
									pos_y <= -11;
								when 6 =>
									pos_x <= 15+5;
									pos_y <= -10;
								when 7 =>
									pos_x <= 16+5;
									pos_y <= -10;
								when 8 =>
									pos_x <= 17+5;
									pos_y <= -10;
								when 9 =>
									pos_x <= 17+5;
									pos_y <= -9;
								when 10 =>
									pos_x <= 17+5;
									pos_y <= -8;
								when 11 =>
									pos_x <= 16+5;
									pos_y <= -8;
								when 12 =>
									pos_x <= 15+5;
									pos_y <= -8;
								when others =>
									next_state <= '1';
								end case;
						when "00011" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15+5;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16+5;
									pos_y <= -12;
								when 3 =>
									pos_x <= 17+5;
									pos_y <= -12;
								when 4 =>
									pos_x <= 17+5;
									pos_y <= -11;
								when 5 =>
									pos_x <= 17+5;
									pos_y <= -10;
								when 6 =>
									pos_x <= 16+5;
									pos_y <= -10;
								when 7 =>
									pos_x <= 15+5;
									pos_y <= -10;
								when 8 =>
									pos_x <= 17+5;
									pos_y <= -9;
								when 9 =>
									pos_x <= 17+5;
									pos_y <= -8;
								when 10 =>
									pos_x <= 16+5;
									pos_y <= -8;
								when 11 =>
									pos_x <= 15+5;
									pos_y <= -8;
								when others =>
									next_state <= '1';
								end case;
						when "00100" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 17+5;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 17+5;
									pos_y <= -11;
								when 3 =>
									pos_x <= 17+5;
									pos_y <= -10;
								when 4 =>
									pos_x <= 17+5;
									pos_y <= -9;
								when 5 =>
									pos_x <= 17+5;
									pos_y <= -8;
								when 6 =>
									pos_x <= 16+5;
									pos_y <= -10;
								when 7 =>
									pos_x <= 15+5;
									pos_y <= -10;
								when 8 =>
									pos_x <= 15+5;
									pos_y <= -9;
								when 9 =>
									pos_x <= 15+5;
									pos_y <= -8;
								when others =>
									next_state <= '1';	
							end case;
						when "00101" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15+5;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16+5;
									pos_y <= -12+5;
								when 3 =>
									pos_x <= 17+5;
									pos_y <= -12;
								when 4 =>
									pos_x <= 17+5;
									pos_y <= -11;
								when 5 =>
									pos_x <= 17+5;
									pos_y <= -10;
								when 6 =>
									pos_x <= 16+5;
									pos_y <= -10;
								when 7 =>
									pos_x <= 15+5;
									pos_y <= -10;
								when 8 =>
									pos_x <= 15+5;
									pos_y <= -9;
								when 9 =>
									pos_x <= 15+5;
									pos_y <= -8;
								when 10 =>
									pos_x <= 16+5;
									pos_y <= -8;
								when 11 =>
									pos_x <= 17+5;
									pos_y <= -8;
								when others =>
									next_state <= '1';
							end case;
						when "00110" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15+5;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16+5;
									pos_y <= -12;
								when 3 =>
									pos_x <= 17+5;
									pos_y <= -12;
								when 4 =>
									pos_x <= 15+5;
									pos_y <= -11;
								when 5 =>
									pos_x <= 17+5;
									pos_y <= -11;
								when 6 =>
									pos_x <= 15+5;
									pos_y <= -10;
								when 7 =>
									pos_x <= 16+5;
									pos_y <= -10;
								when 8 =>
									pos_x <= 17+5;
									pos_y <= -10;
								when 9 =>
									pos_x <= 15+5;
									pos_y <= -9;
								when 10 =>
									pos_x <= 15+5;
									pos_y <= -8;
								when 11 =>
									pos_x <= 16+5;
									pos_y <= -8;
								when 12 =>
									pos_x <= 17+5;
									pos_y <= -8;
								when others =>
									next_state <= '1';
							end case;
						when "00111" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 17+5;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 17+5;
									pos_y <= -11;
								when 3 =>
									pos_x <= 17+5;
									pos_y <= -10;
								when 4 =>
									pos_x <= 17+5;
									pos_y <= -9;
								when 5 =>
									pos_x <= 17+5;
									pos_y <= -8;
								when 6 =>
									pos_x <= 16+5;
									pos_y <= -8;
								when 7 =>
									pos_x <= 15+5;
									pos_y <= -8;
								when others =>
									next_state <= '1';
							end case;
							when "01000" =>
								pixel_num := pixel_num + 1;
								case pixel_num is
									when 1 =>
										pos_x <= 15+5;
										pos_y <= -12;
										pixel_code <= "111";
									when 2 =>
										pos_x <= 16+5;
										pos_y <= -12;
									when 3 =>
										pos_x <= 17+5;
										pos_y <= -12;
									when 4 =>
										pos_x <= 17+5;
										pos_y <= -11;
									when 5 =>
										pos_x <= 17+5;
										pos_y <= -10;
									when 6 =>
										pos_x <= 17+5;
										pos_y <= -9;
									when 7 =>
										pos_x <= 17+5;
										pos_y <= -8;
									when 8 =>
										pos_x <= 16+5;
										pos_y <= -8;
									when 9 =>
										pos_x <= 15+5;
										pos_y <= -8;
									when 10 =>
										pos_x <= 15+5;
										pos_y <= -9;
									when 11 =>
										pos_x <= 15+5;
										pos_y <= -10;
									when 12 =>
										pos_x <= 15+5;
										pos_y <= -11;
									when 13 =>
										pos_x <= 15+5;
										pos_y <= -12;
									when 14 =>
										pos_x <= 16+5;
										pos_y <= -10;
									when others =>
										next_state <= '1';		
								end case;
							when "01001" =>
								pixel_num := pixel_num + 1;
								case pixel_num is
									when 1 =>
										pos_x <= 15+5;
										pos_y <= -12;
										pixel_code <= "111";
									when 2 =>
										pos_x <= 16+5;
										pos_y <= -12;
									when 3 =>
										pos_x <= 17+5;
										pos_y <= -12;
									when 4 =>
										pos_x <= 17+5;
										pos_y <= -11;
									when 5 =>
										pos_x <= 17+5;
										pos_y <= -10;
									when 6 =>
										pos_x <= 17+5;
										pos_y <= -9;
									when 7 =>
										pos_x <= 17+5;
										pos_y <= -8;
									when 8 =>
										pos_x <= 16+5;
										pos_y <= -8;
									when 9 =>
										pos_x <= 15+5;
										pos_y <= -8;
									when 10 =>
										pos_x <= 15+5;
										pos_y <= -9;
									when 11 =>
										pos_x <= 15+5;
										pos_y <= -10;
									when 12 =>
										pos_x <= 15+5;
										pos_y <= -12;
									when 13 =>
										pos_x <= 16+5;
										pos_y <= -10;
									when others =>
										next_state <= '1';		
								end case;
							when others => next_state <= '1';
						end case;	
			when "0010" =>
				if (key_result < 10) then
					y(9 downto 0) <= signed(cur_key) * 10;
					cur_key := key_result;
					pixel_num := 0;
					next_state <= '1';
				end if;
			when "0110" =>
				case cur_key is
					when "00000" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+64;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+64;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+64;
								pos_y <= -12;
							when 4 =>
								pos_x <= 17+64;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17+64;
								pos_y <= -10;
							when 6 =>
								pos_x <= 17+64;
								pos_y <= -9;
							when 7 =>
								pos_x <= 17+64;
								pos_y <= -8;
							when 8 =>
								pos_x <= 16+64;
								pos_y <= -8;
							when 9 =>
								pos_x <= 15+64;
								pos_y <= -8;
							when 10 =>
								pos_x <= 15+64;
								pos_y <= -9;
							when 11 =>
								pos_x <= 15+64;
								pos_y <= -10;
							when 12 =>
								pos_x <= 15+64;
								pos_y <= -11;
							when 13 =>
								pos_x <= 15+64;
								pos_y <= -12;
							when others =>
								next_state <= '1';					
						end case;
					when "00001" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+64;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+64;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+64;
								pos_y <= -12;
							when 4 =>
								pos_x <= 16+64;
								pos_y <= -11;
							when 5 =>
								pos_x <= 16+64;
								pos_y <= -10;
							when 6 =>
								pos_x <= 16+64;
								pos_y <= -9;
							when 7 =>
								pos_x <= 16+64;
								pos_y <= -8;
							when 8 =>
								pos_x <= 15+64;
								pos_y <= -9;
							when others =>
								next_state <= '1';	
						end case;
					when "00010" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+64;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+64;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+64;
								pos_y <= -12;
							when 5 =>
								pos_x <= 15+64;
								pos_y <= -11;
							when 6 =>
								pos_x <= 15+64;
								pos_y <= -10;
							when 7 =>
								pos_x <= 16+64;
								pos_y <= -10;
							when 8 =>
								pos_x <= 17+64;
								pos_y <= -10;
							when 9 =>
								pos_x <= 17+64;
								pos_y <= -9;
							when 10 =>
								pos_x <= 17+64;
								pos_y <= -8;
							when 11 =>
								pos_x <= 16+64;
								pos_y <= -8;
							when 12 =>
								pos_x <= 15+64;
								pos_y <= -8;
							when others =>
								next_state <= '1';
							end case;
					when "00011" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+64;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+64;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+64;
								pos_y <= -12;
							when 4 =>
								pos_x <= 17+64;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17+64;
								pos_y <= -10;
							when 6 =>
								pos_x <= 16+64;
								pos_y <= -10;
							when 7 =>
								pos_x <= 15+64;
								pos_y <= -10;
							when 8 =>
								pos_x <= 17+64;
								pos_y <= -9;
							when 9 =>
								pos_x <= 17+64;
								pos_y <= -8;
							when 10 =>
								pos_x <= 16+64;
								pos_y <= -8;
							when 11 =>
								pos_x <= 15+64;
								pos_y <= -8;
							when others =>
								next_state <= '1';
							end case;
					when "00100" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 17+64;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 17+64;
								pos_y <= -11;
							when 3 =>
								pos_x <= 17+64;
								pos_y <= -10;
							when 4 =>
								pos_x <= 17+64;
								pos_y <= -9;
							when 5 =>
								pos_x <= 17+64;
								pos_y <= -8;
							when 6 =>
								pos_x <= 16+64;
								pos_y <= -10;
							when 7 =>
								pos_x <= 15+64;
								pos_y <= -10;
							when 8 =>
								pos_x <= 15+64;
								pos_y <= -9;
							when 9 =>
								pos_x <= 15+64;
								pos_y <= -8;
							when others =>
								next_state <= '1';	
						end case;
					when "00101" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+64;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+64;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+64;
								pos_y <= -12;
							when 4 =>
								pos_x <= 17+64;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17+64;
								pos_y <= -10;
							when 6 =>
								pos_x <= 16+64;
								pos_y <= -10;
							when 7 =>
								pos_x <= 15+64;
								pos_y <= -10;
							when 8 =>
								pos_x <= 15+64;
								pos_y <= -9;
							when 9 =>
								pos_x <= 15+64;
								pos_y <= -8;
							when 10 =>
								pos_x <= 16+64;
								pos_y <= -8;
							when 11 =>
								pos_x <= 17+64;
								pos_y <= -8;
							when others =>
								next_state <= '1';
						end case;
					when "00110" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+64;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+64;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+64;
								pos_y <= -12;
							when 4 =>
								pos_x <= 15+64;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17+64;
								pos_y <= -11;
							when 6 =>
								pos_x <= 15+64;
								pos_y <= -10;
							when 7 =>
								pos_x <= 16+64;
								pos_y <= -10;
							when 8 =>
								pos_x <= 17+64;
								pos_y <= -10;
							when 9 =>
								pos_x <= 15+64;
								pos_y <= -9;
							when 10 =>
								pos_x <= 15+64;
								pos_y <= -8;
							when 11 =>
								pos_x <= 16+64;
								pos_y <= -8;
							when 12 =>
								pos_x <= 17+64;
								pos_y <= -8;
							when others =>
								next_state <= '1';
						end case;
					when "00111" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 17+64;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 17+64;
								pos_y <= -11;
							when 3 =>
								pos_x <= 17+64;
								pos_y <= -10;
							when 4 =>
								pos_x <= 17+64;
								pos_y <= -9;
							when 5 =>
								pos_x <= 17+64;
								pos_y <= -8;
							when 6 =>
								pos_x <= 16+64;
								pos_y <= -8;
							when 7 =>
								pos_x <= 15+64;
								pos_y <= -8;
							when others =>
								next_state <= '1';
						end case;
						when "01000" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15+64;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16+64;
									pos_y <= -12;
								when 3 =>
									pos_x <= 17+64;
									pos_y <= -12;
								when 4 =>
									pos_x <= 17+64;
									pos_y <= -11;
								when 5 =>
									pos_x <= 17+64;
									pos_y <= -10;
								when 6 =>
									pos_x <= 17+64;
									pos_y <= -9;
								when 7 =>
									pos_x <= 17+64;
									pos_y <= -8;
								when 8 =>
									pos_x <= 16+64;
									pos_y <= -8;
								when 9 =>
									pos_x <= 15+64;
									pos_y <= -8;
								when 10 =>
									pos_x <= 15+64;
									pos_y <= -9;
								when 11 =>
									pos_x <= 15+64;
									pos_y <= -10;
								when 12 =>
									pos_x <= 15+64;
									pos_y <= -11;
								when 13 =>
									pos_x <= 15+64;
									pos_y <= -12;
								when 14 =>
									pos_x <= 16+64;
									pos_y <= -10;
								when others =>
									next_state <= '1';		
							end case;
						when "01001" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15+64;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16+64;
									pos_y <= -12;
								when 3 =>
									pos_x <= 17+64;
									pos_y <= -12;
								when 4 =>
									pos_x <= 17+64;
									pos_y <= -11;
								when 5 =>
									pos_x <= 17+64;
									pos_y <= -10;
								when 6 =>
									pos_x <= 17+64;
									pos_y <= -9;
								when 7 =>
									pos_x <= 17+64;
									pos_y <= -8;
								when 8 =>
									pos_x <= 16+64;
									pos_y <= -8;
								when 9 =>
									pos_x <= 15+64;
									pos_y <= -8;
								when 10 =>
									pos_x <= 15+64;
									pos_y <= -9;
								when 11 =>
									pos_x <= 15+64;
									pos_y <= -10;
								when 12 =>
									pos_x <= 15+64;
									pos_y <= -12;
								when 13 =>
									pos_x <= 16+64;
									pos_y <= -10;
								when others =>
									next_state <= '1';		
							end case;
						when others => next_state <= '1';
					end case;
			when "0011" =>
				if (key_result < 10) then
					y(9 downto 0) <= y(9 downto 0) + signed(cur_key) * 1;
					cur_key := key_result;
					pixel_num := 0;
					next_state <= '1';
				end if;
			when "0111" =>
				case cur_key is
					when "00000" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+69;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+69;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+69;
								pos_y <= -12;
							when 4 =>
								pos_x <= 17+69;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17+69;
								pos_y <= -10;
							when 6 =>
								pos_x <= 17+69;
								pos_y <= -9;
							when 7 =>
								pos_x <= 17+69;
								pos_y <= -8;
							when 8 =>
								pos_x <= 16+69;
								pos_y <= -8;
							when 9 =>
								pos_x <= 15+69;
								pos_y <= -8;
							when 10 =>
								pos_x <= 15+69;
								pos_y <= -9;
							when 11 =>
								pos_x <= 15+69;
								pos_y <= -10;
							when 12 =>
								pos_x <= 15+69;
								pos_y <= -11;
							when 13 =>
								pos_x <= 15+69;
								pos_y <= -12;
							when others =>
								next_state <= '1';					
						end case;
					when "00001" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+69;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+69;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+69;
								pos_y <= -12;
							when 4 =>
								pos_x <= 16+69;
								pos_y <= -11;
							when 5 =>
								pos_x <= 16+69;
								pos_y <= -10;
							when 6 =>
								pos_x <= 16+69;
								pos_y <= -9;
							when 7 =>
								pos_x <= 16+69;
								pos_y <= -8;
							when 8 =>
								pos_x <= 15+69;
								pos_y <= -9;
							when others =>
								next_state <= '1';	
						end case;
					when "00010" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+69;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+69;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+69;
								pos_y <= -12;
							when 5 =>
								pos_x <= 15+69;
								pos_y <= -11;
							when 6 =>
								pos_x <= 15+69;
								pos_y <= -10;
							when 7 =>
								pos_x <= 16+69;
								pos_y <= -10;
							when 8 =>
								pos_x <= 17+69;
								pos_y <= -10;
							when 9 =>
								pos_x <= 17+69;
								pos_y <= -9;
							when 10 =>
								pos_x <= 17+69;
								pos_y <= -8;
							when 11 =>
								pos_x <= 16+69;
								pos_y <= -8;
							when 12 =>
								pos_x <= 15+69;
								pos_y <= -8;
							when others =>
								next_state <= '1';
							end case;
					when "00011" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+69;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+69;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+69;
								pos_y <= -12;
							when 4 =>
								pos_x <= 17+69;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17+69;
								pos_y <= -10;
							when 6 =>
								pos_x <= 16+69;
								pos_y <= -10;
							when 7 =>
								pos_x <= 15+69;
								pos_y <= -10;
							when 8 =>
								pos_x <= 17+69;
								pos_y <= -9;
							when 9 =>
								pos_x <= 17+69;
								pos_y <= -8;
							when 10 =>
								pos_x <= 16+69;
								pos_y <= -8;
							when 11 =>
								pos_x <= 15+69;
								pos_y <= -8;
							when others =>
								next_state <= '1';
							end case;
					when "00100" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 17+69;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 17+69;
								pos_y <= -11;
							when 3 =>
								pos_x <= 17+69;
								pos_y <= -10;
							when 4 =>
								pos_x <= 17+69;
								pos_y <= -9;
							when 5 =>
								pos_x <= 17+69;
								pos_y <= -8;
							when 6 =>
								pos_x <= 16+69;
								pos_y <= -10;
							when 7 =>
								pos_x <= 15+69;
								pos_y <= -10;
							when 8 =>
								pos_x <= 15+69;
								pos_y <= -9;
							when 9 =>
								pos_x <= 15+69;
								pos_y <= -8;
							when others =>
								next_state <= '1';	
						end case;
					when "00101" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+69;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+69;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+69;
								pos_y <= -12;
							when 4 =>
								pos_x <= 17+69;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17+69;
								pos_y <= -10;
							when 6 =>
								pos_x <= 16+69;
								pos_y <= -10;
							when 7 =>
								pos_x <= 15+69;
								pos_y <= -10;
							when 8 =>
								pos_x <= 15+69;
								pos_y <= -9;
							when 9 =>
								pos_x <= 15+69;
								pos_y <= -8;
							when 10 =>
								pos_x <= 16+69;
								pos_y <= -8;
							when 11 =>
								pos_x <= 17+69;
								pos_y <= -8;
							when others =>
								next_state <= '1';
						end case;
					when "00110" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 15+69;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 16+69;
								pos_y <= -12;
							when 3 =>
								pos_x <= 17+69;
								pos_y <= -12;
							when 4 =>
								pos_x <= 15+69;
								pos_y <= -11;
							when 5 =>
								pos_x <= 17+69;
								pos_y <= -11;
							when 6 =>
								pos_x <= 15+69;
								pos_y <= -10;
							when 7 =>
								pos_x <= 16+69;
								pos_y <= -10;
							when 8 =>
								pos_x <= 17+69;
								pos_y <= -10;
							when 9 =>
								pos_x <= 15+69;
								pos_y <= -9;
							when 10 =>
								pos_x <= 15+69;
								pos_y <= -8;
							when 11 =>
								pos_x <= 16+69;
								pos_y <= -8;
							when 12 =>
								pos_x <= 17+69;
								pos_y <= -8;
							when others =>
								next_state <= '1';
						end case;
					when "00111" =>
						pixel_num := pixel_num + 1;
						case pixel_num is
							when 1 =>
								pos_x <= 17+69;
								pos_y <= -12;
								pixel_code <= "111";
							when 2 =>
								pos_x <= 17+69;
								pos_y <= -11;
							when 3 =>
								pos_x <= 17+69;
								pos_y <= -10;
							when 4 =>
								pos_x <= 17+69;
								pos_y <= -9;
							when 5 =>
								pos_x <= 17+69;
								pos_y <= -8;
							when 6 =>
								pos_x <= 16+69;
								pos_y <= -8;
							when 7 =>
								pos_x <= 15+69;
								pos_y <= -8;
							when others =>
								next_state <= '1';
						end case;
						when "01000" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15+69;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16+69;
									pos_y <= -12;
								when 3 =>
									pos_x <= 17+69;
									pos_y <= -12;
								when 4 =>
									pos_x <= 17+69;
									pos_y <= -11;
								when 5 =>
									pos_x <= 17+69;
									pos_y <= -10;
								when 6 =>
									pos_x <= 17+69;
									pos_y <= -9;
								when 7 =>
									pos_x <= 17+69;
									pos_y <= -8;
								when 8 =>
									pos_x <= 16+69;
									pos_y <= -8;
								when 9 =>
									pos_x <= 15+69;
									pos_y <= -8;
								when 10 =>
									pos_x <= 15+69;
									pos_y <= -9;
								when 11 =>
									pos_x <= 15+69;
									pos_y <= -10;
								when 12 =>
									pos_x <= 15+69;
									pos_y <= -11;
								when 13 =>
									pos_x <= 15+69;
									pos_y <= -12;
								when 14 =>
									pos_x <= 16+69;
									pos_y <= -10;
								when others =>
									next_state <= '1';		
							end case;
						when "01001" =>
							pixel_num := pixel_num + 1;
							case pixel_num is
								when 1 =>
									pos_x <= 15+69;
									pos_y <= -12;
									pixel_code <= "111";
								when 2 =>
									pos_x <= 16+69;
									pos_y <= -12;
								when 3 =>
									pos_x <= 17+69;
									pos_y <= -12;
								when 4 =>
									pos_x <= 17+69;
									pos_y <= -11;
								when 5 =>
									pos_x <= 17+69;
									pos_y <= -10;
								when 6 =>
									pos_x <= 17+69;
									pos_y <= -9;
								when 7 =>
									pos_x <= 17+69;
									pos_y <= -8;
								when 8 =>
									pos_x <= 16+69;
									pos_y <= -8;
								when 9 =>
									pos_x <= 15+69;
									pos_y <= -8;
								when 10 =>
									pos_x <= 15+69;
									pos_y <= -9;
								when 11 =>
									pos_x <= 15+69;
									pos_y <= -10;
								when 12 =>
									pos_x <= 15+69;
									pos_y <= -12;
								when 13 =>
									pos_x <= 16+69;
									pos_y <= -10;
								when others =>
									next_state <= '1';		
							end case;
						when others => next_state <= '1';
					end case;
			when "1000" =>
				if (key_result = 12) then
					next_state <= '1';
				end if;
			when "1001" =>
				next_state <= '1';
				start_lin_reg <= '1';
				pixel_num := 0;
			when "1010" =>
				if (finished_lin_reg = '1' or start_lin_reg = '0') then
					start_lin_reg <= '0';
					pos_x <= pos_x + 1;
					pos_y <= (to_integer(theta0)/4295000) + ((to_integer(theta1)/4295000) * (pos_x+1));
					if (pixel_num = 40) then
						next_state <= '1';
					end if;
				end if;
			when others => --do nothing
				next_state <= '1';
		end case;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Brilho do pixel
  -----------------------------------------------------------------------------
  -- O brilho do pixel é branco quando os contadores de linha e coluna, que
  -- indicam o endereço do pixel sendo escrito para o quadro atual, casam com a
  -- posição da bola (sinais pos_x e pos_y). Caso contrário,
  -- o pixel é preto.
	
  pixel <= pixel_code;
  
  -- O endereço de memória pode ser construído com essa fórmula simples,
  -- a partir da linha e coluna atual
  addr  <= (5 + pos_x) + ((128 * 78) - (128 * pos_y));

  
end comportamento;
