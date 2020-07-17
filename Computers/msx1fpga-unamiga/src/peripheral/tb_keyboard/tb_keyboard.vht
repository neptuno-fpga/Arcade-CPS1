--
-- Copyright (c) 2016 - Fabio Belavenuto
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb is
end tb;

architecture testbench of tb is

	-- test target
	component keyboard
	port(
		clock_i			: in    std_logic;
		reset_i			: in    std_logic;
		-- MSX
		rows_coded_i	: in    std_logic_vector(3 downto 0);
		cols_o			: out   std_logic_vector(7 downto 0);
		keymap_addr_i	: in    std_logic_vector(9 downto 0);
		keymap_data_i	: in    std_logic_vector(7 downto 0);
		keymap_we_i		: in    std_logic;
		-- LEDs
		led_caps_i		: in    std_logic;
		-- PS/2 interface
		ps2_clk_io		: inout std_logic;
		ps2_data_io		: inout std_logic;
		--
		reset_o			: out   std_logic								:= '0';
		por_o				: out   std_logic								:= '0';
		reload_core_o	: out   std_logic								:= '0';
		extra_keys_o	: out   std_logic_vector(3 downto 0)	-- F11, Print Screen, Scroll Lock, Pause/Break
	);
	end component;

	signal tb_end			: std_logic;
	signal reset_s		: std_logic;
	signal clock_s		: std_logic;
	signal rows_coded_s	: std_logic_vector(3 downto 0);
	signal cols_s		: std_logic_vector(7 downto 0);
	signal led_caps_s	: std_logic;
	signal ps2_clk_s	: std_logic;
	signal ps2_data_s	: std_logic;

begin

	--  instance
	u_target: keyboard
	port map(
		clock_i			=> clock_s,
		reset_i			=> reset_s,
		-- MSX
		rows_coded_i	=> rows_coded_s,
		cols_o			=> cols_s,
		keymap_addr_i	=> (others => '0'),
		keymap_data_i	=> (others => '0'),
		keymap_we_i		=> '0',
		-- LEDs
		led_caps_i		=> led_caps_s,
		-- PS/2 interface
		ps2_clk_io		=> ps2_clk_s,
		ps2_data_io		=> ps2_data_s,
		--
		reset_o			=> open,
		por_o			=> open,
		reload_core_o	=> open,
		extra_keys_o	=> open
	);

	-- ----------------------------------------------------- --
	--  clock generator                                      --
	-- ----------------------------------------------------- --
	process
	begin
		if tb_end = '1' then
			wait;
		end if;
		clock_s <= '0';
		wait for 250 ns;		-- 2 MHz
		clock_s <= '1';
		wait for 250 ns;
	end process;

	-- ----------------------------------------------------- --
	--  test bench                                           --
	-- ----------------------------------------------------- --
	process
	begin
		-- init
		rows_coded_s	<= (others => '0');
		led_caps_s		<= '0';
		ps2_clk_s		<= 'Z';
		ps2_data_s		<= 'Z';

		-- reset
		reset_s		<= '1';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );
		reset_s		<= '0';
		wait until( rising_edge(clock_s) );
		wait until( rising_edge(clock_s) );

		wait for 20 us;
--		led_caps_s <= '1';

		wait for 120 us;

		-- wait
		tb_end <= '1';
		wait;
	end process;

end testbench;
