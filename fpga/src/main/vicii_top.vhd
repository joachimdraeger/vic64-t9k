-- VIC64-T9K - C64 VIC-II video chip on the Tang Nano 9K
-- https://github.com/joachimdraeger/vic64-t9k
-- Copyright (C) 2025  Joachim Draeger

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.


-- -----------------------------------------------------------------------------
-- Wrapper for the vic module. Sets fixed parameters and connects the rgb color
-- lookup table.
-- -----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vic_top is
    port (
        -- Clock and control
        clk32        : in  std_logic;
        phi          : in  std_logic;
        reset        : in  std_logic;
        enablePixel  : in  std_logic;
        enableVic    : in  std_logic;
        
        -- Video output
        hSync        : out std_logic;
        vSync        : out std_logic;
        r            : out unsigned(7 downto 0);
        g            : out unsigned(7 downto 0);
        b            : out unsigned(7 downto 0);
        
        -- Bus control
        vic_ba       : out std_logic;  -- 0 when VIC is requesting the bus, 1 when bus available to CPU
        vic_aec      : out std_logic;  -- 1 when VIC is accessing the address
        vic_addr     : out unsigned(15 downto 0);  -- Address of the VIC
        vic_di       : in unsigned(7 downto 0);
        vic_color_di : in unsigned(3 downto 0);

        vic_cs       : in std_logic;
        r_wn         : in std_logic;
        bus_addr     : in unsigned(15 downto 0);
        cpu_data_out : in unsigned(7 downto 0);

        vic_do       : out unsigned(7 downto 0)
    );
end entity vic_top;

architecture rtl of vic_top is

    constant ntscMode : std_logic := '0';

    signal vicColorIndex: unsigned(3 downto 0);
    signal vic_addr14   : unsigned(13 downto 0);
    signal vic_we       : std_logic;  

begin

    -- Create the write enable signal
    vic_we <= not r_wn;

    vic: entity work.video_vicii_656x
    generic map (
        registeredAddress => true,
        emulateRefresh => true,
        emulateLightpen => true,
        emulateGraphics => true
    )			
    port map (
        clk => clk32,
        reset => reset,
        enaPixel => enablePixel,
        enaData => enableVic,
        phi => phi,
        
        baSync => '0',
        ba => vic_ba,
        -- ba_dma => vicBa_dma,

        mode6569 => (not ntscMode),
        mode6567old => '0',
        mode6567R8 => ntscMode,
        mode6572 => '0',
        
        turbo_en => '0',
        -- turbo_state => turbo_state,
        variant => "00", -- vic_variant,  -- 00 - NMOS, 01 - HMOS, 10 - old HMOS

        cs => vic_cs,
        we => vic_we,  -- Use the internal signal
        lp_n => '1', -- light pen  cia1_pbi(4),

        aRegisters => bus_addr(5 downto 0),
        diRegisters => cpu_data_out,
        di => vic_di,
        diColor => vic_color_di,
        do => vic_do,

        vicAddr => vic_addr14,
        addrValid => vic_aec,
        
        hsync => hSync,
        vsync => vSync,
        colorIndex => vicColorIndex
        -- debugX  => debugX,
        -- debugY  => debugY,
        -- irq_n => irq_vic
    );    

    -- Zero out the upper 2 bits of vic_addr and connect the lower 14 bits to vicAddr from the component
    vic_addr <= "00" & vic_addr14;

    colorlookup: entity work.fpga64_rgbcolor
    port map (
        index => vicColorIndex,
        r => r,
        g => g,
        b => b
    );
    

end architecture rtl;