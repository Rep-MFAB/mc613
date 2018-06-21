LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use IEEE.numeric_std.all;

ENTITY main IS
	PORT (
		SW				: IN STD_LOGIC_VECTOR(9 downto 0);
		CLOCK_50				: IN STD_LOGIC;
		KEY				: IN STD_LOGIC_VECTOR(3 downto 0);
		PS2_DAT 	:		inout	STD_LOGIC;	--	PS2 Data
		PS2_CLK		:		inout	STD_LOGIC;		--	PS2 Clock
		VGA_R, VGA_G, VGA_B	: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		VGA_HS, VGA_VS		: OUT STD_LOGIC;
		VGA_BLANK_N, VGA_SYNC_N : OUT STD_LOGIC;
		LEDR                      : out std_logic_vector(9 downto 0);
		HEX0 	:		out	STD_LOGIC_VECTOR (6 downto 0);		--	Seven Segment Digit 0 
		HEX5 	:		out	STD_LOGIC_VECTOR (6 downto 0);		--	Seven Segment Digit 5 
		VGA_CLK : OUT STD_LOGIC
	);
END ENTITY;

ARCHITECTURE behavior OF main IS
	component teclado is
		port
		(
			CLOCK_50	: 	in	STD_LOGIC;
			KEY 	:		in	STD_LOGIC_VECTOR (3 downto 0);
			SW 	:		in	STD_LOGIC_VECTOR (9 downto 0);
			PS2_DAT 	:		inout	STD_LOGIC;	--	PS2 Data
			PS2_CLK		:		inout	STD_LOGIC;		--	PS2 Clock
			HEX 	:		out	STD_LOGIC_VECTOR (6 downto 0);		--	Seven Segment Digit 0
			result			: out signed(4 downto 0)
		);
	end component;
	
	signal key_result : signed(4 downto 0);
	
	component vga_main is
		generic (
			WORDSIZE		: NATURAL	:= 64
		);
		port (    
			CLOCK_50                  : in  std_logic;
			key_result			        : in signed(4 downto 0);
			VGA_R, VGA_G, VGA_B       : out std_logic_vector(7 downto 0);
			HEX 	                    : out STD_LOGIC_VECTOR (6 downto 0);
			VGA_HS, VGA_VS            : out std_logic;
			VGA_BLANK_N, VGA_SYNC_N   : out std_logic;
			VGA_CLK                   : out std_logic;
			LEDR                      : out std_logic_vector(9 downto 0)
		);
	end component;
BEGIN
	keyboard: teclado port map(
		CLOCK_50 => CLOCK_50,
		KEY => KEY,
		SW => SW,
		PS2_DAT => PS2_DAT,
		PS2_CLK => PS2_CLK,
		HEX => HEX5,
		result => key_result
	);
	screen: vga_main port map(
		CLOCK_50 => CLOCK_50,
		VGA_R => VGA_R,
		VGA_G => VGA_G,
		VGA_B => VGA_B,
		VGA_HS => VGA_HS,
		VGA_VS => VGA_VS,
		VGA_BLANK_N => VGA_BLANK_N,
		VGA_SYNC_N => VGA_SYNC_N,
		VGA_CLK => VGA_CLK,
		LEDR => LEDR,
		HEX => HEX0,
		key_result => key_result
	);
	
END ARCHITECTURE;