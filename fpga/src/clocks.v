// VIC64-T9K - C64 VIC-II video chip on the Tang Nano 9K
// https://github.com/joachimdraeger/vic64-t9k
// Copyright (C) 2025  Joachim Draeger

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

// -----------------------------------------------------------------------------
// Instantiates the clocks (see the gowin folder for the IP cores)
// - clk_5x: 157Mhz clock required for HDMI
// - clkdiv5: 32Mhz main clock
// - clk_2x_64_rpll: 64Mhz clock + 90 deg phase shift for PSRAM
//
// Notes:
// - Unsure if generating the 64Mhz clock from the 27 Mhz fpga system clock 
//   would be better
// - PSRAM should be stable up to 83 Mhz, but an attempt to use 83 Mhz has
//   led to timing closure issues and instability.
// -----------------------------------------------------------------------------

module clocks (
    input  wire clkin,        // Input clock 
    output wire clk32,        // 32MHz clock
    output wire clk64,        // 64MHz clock
    output wire clk64p,       // 64MHz clock shifted
    output wire clk157       // 157MHz clock
);

wire lock_5x;

clk_5x clk_5x_inst(
    .clkout(clk157), //output clkout
    .lock(lock_5x), //output lock
    .clkin(clkin) //input clkin
);

clkdiv5 clkdiv5_inst(
    .clkout(clk32), //output clkout
    .hclkin(clk157), //input hclkin
    .resetn(lock_5x) //input resetn
);

clk_2x_64_rpll clk_2x_64_rpll_inst(
    .reset(~lock_5x), //input reset
    .clkout(clk64), //output clkout
    .clkoutp(clk64p), //output clkoutp
    .clkin(clk32) //input clkin
);


endmodule
