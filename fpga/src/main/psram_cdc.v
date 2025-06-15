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
// Provides clock domain crossing for the PSRAM interface between the main 
// clock domain (32MHz) and the PSRAM clock domain (64MHz).
// Essential for timing closure - without CDC, synthesis timing becomes
// unreliable and stability issues have been observed.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
module psram_cdc (
    input clk32,
    input clk64,
    input resetn,
    input read_in,
    input write_in,
    input [21:0] addr_in,
    input [15:0] din_in,
    input [15:0] dout_in,
    input busy_in,

    output wire read_out,
    output wire write_out,
    output reg [21:0] addr_out,
    output reg [15:0] din_out,
    output reg [15:0] dout_out,
    output reg busy_out // TODO derive from state
);

reg read_int;
reg write_int;
reg busy_int;

localparam STATE_IDLE       = 2'd0;
localparam STATE_WAIT_BUSY  = 2'd1;
localparam STATE_WAIT       = 2'd2;

reg [1:0] state = STATE_IDLE;

initial begin
    addr_out <= 22'd0;
    din_out <= 16'd0;
    dout_out <= 16'd0;
    busy_out <= 1'b0;

    read_int <= 1'b0;
    write_int <= 1'b0;
end

always @(posedge clk32) begin
    busy_int <= busy_in;
end    

always @(posedge clk32) begin
    case (state)
        STATE_IDLE: begin
            if (read_in) begin
                busy_out <= 1'b1;
                addr_out <= addr_in;
                read_int <= 1'b1;
                state <= STATE_WAIT_BUSY;
            end else if (write_in) begin
                busy_out <= 1'b1;
                addr_out <= addr_in;
                din_out <= din_in;
                write_int <= 1'b1;
                state <= STATE_WAIT_BUSY;
            end
        end
        STATE_WAIT_BUSY: begin
            read_int <= 0;
            write_int <= 0;
            if (busy_int) begin
                state <= STATE_WAIT;
            end
        end
        STATE_WAIT: begin
            if (!busy_int) begin
                dout_out <= dout_in;
                busy_out <= 1'b0;
                state <= STATE_IDLE;
            end
        end
    endcase
end

cdc_single_strobe write_strobe_sync (
    .src_signal(write_int),
    .dst_clk(clk64),
    .dst_signal(write_out)
);

cdc_single_strobe read_strobe_sync (
    .src_signal(read_int),
    .dst_clk(clk64),
    .dst_signal(read_out)
);

endmodule