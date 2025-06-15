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
// Implements IO controller for the LEDs. LED 6 is reserved to indicate errors.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
module io_leds (
    input clk,      
    input bus_access_strobe,
    input [15:0] a,
    input ext_io_en,
    input r_w_n,
    input [7:0] d_in,
    output reg [4:0] leds
);

// Initialize LEDs
initial begin
    leds = 5'b11111;
end

wire is_led_addr = (a == 16'hDEFF);

always @(posedge clk) begin
    if (bus_access_strobe && ext_io_en && is_led_addr && !r_w_n) begin
        leds[4:0] <= d_in[4:0];  // Set LEDs from lower 5 bits of data bus
    end
end

endmodule
