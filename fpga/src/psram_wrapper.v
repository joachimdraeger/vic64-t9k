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
// Wraps psram controller with clock domain crossing logic
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
module psram_wrapper (
    input clk32,
    input clk64,      
    input clk64p,     
    input resetn,
    input read,
    input write,
    input byte_write,
    input [21:0] addr,
    input [15:0] din,
    output [15:0] dout,
    output busy,
    output [1:0] O_psram_ck,
    inout [1:0] IO_psram_rwds,
    inout [15:0] IO_psram_dq,
    output [1:0] O_psram_cs_n
);

wire psram_r_strobe;
wire psram_w_strobe;
wire [21:0] psram_addr;
wire [15:0] psram_d_in;
wire [15:0] psram_d_out;
wire psram_busy;

PsramController #(
    .LATENCY(3),
    .FREQ(63_000_000)
) psram_controller_inst (
    .clk(clk64),
    .clk_p(clk64p),
    .resetn(resetn),
    .write(psram_w_strobe),
    .read(psram_r_strobe),
    .byte_write(1'b1),
    .addr(psram_addr),
    .din(psram_d_in),
    .dout(psram_d_out),
    .busy(psram_busy),       

    .O_psram_ck(O_psram_ck),
    .IO_psram_rwds(IO_psram_rwds),
    .IO_psram_dq(IO_psram_dq),
    .O_psram_cs_n(O_psram_cs_n)
);

psram_cdc psram_cdc_inst (
    .clk32(clk32),
    .clk64(clk64),
    .resetn(resetn),
    .read_in(read),
    .write_in(write),
    .addr_in(addr),
    .din_in(din),
    .dout_in(psram_d_out),
    .busy_in(psram_busy),

    .read_out(psram_r_strobe),
    .write_out(psram_w_strobe),
    .addr_out(psram_addr),
    .din_out(psram_d_in),
    .dout_out(dout),
    .busy_out(busy)
);

endmodule