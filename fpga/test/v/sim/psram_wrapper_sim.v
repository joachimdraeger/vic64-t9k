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


`timescale 1ns/1ps
module psram_wrapper_sim (
    input clk32,
    input clk64,           
    input resetn,
    input read,
    input write,
    input byte_write,
    input [21:0] addr,
    input [15:0] din,
    output reg [15:0] dout,
    output reg busy
);

wire psram_w_strobe;
wire [21:0] psram_addr;
wire [15:0] psram_d_in;
wire psram_busy;

psram_stub psram_stub_inst (
    .clk(clk64),
    .resetn(resetn),
    .write(psram_w_strobe),
    .read(1'b0),
    .byte_write(1'b1),
    .addr(psram_addr),
    .din(psram_d_in),
    .busy(psram_busy)
);

psram_cdc psram_cdc_inst (
    .clk32(clk32),
    .clk64(clk64),
    .resetn(resetn),
    .read_in(read),
    .write_in(write),
    .addr_in(addr),
    .din_in(din),
    .dout_in(16'h0),
    .busy_in(psram_busy),

    .write_out(psram_w_strobe),
    .addr_out(psram_addr),
    .din_out(psram_d_in),
    .busy_out(busy)
);

endmodule