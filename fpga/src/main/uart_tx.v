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

// Inspired by https://github.com/lushaylabs/tangnano9k-series-examples/tree/62687c5adf966ad17a3b0388e937c9a31f0b17b1/uart


// -----------------------------------------------------------------------------
// Transmitter module for the UART.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
// UART Transmitter module
module uart_tx #(
    parameter CLKS_PER_BIT = 64125000 / 32 / 9600
) (
    input wire clk,
    input start,        // Trigger to start transmission
    input [7:0] data,      // Data register as input reg
    output wire busy,   // Changed from reg to wire
    output reg tx_p
);

localparam STATE_IDLE    = 2'b00;
localparam STATE_START   = 2'b01;
localparam STATE_DATA    = 2'b10;
localparam STATE_STOP    = 2'b11;

reg [2:0] bitpos;
reg [1:0] state;

// Calculate the number of clock cycles per bit
localparam CNT_WIDTH = $clog2(CLKS_PER_BIT);
reg [CNT_WIDTH-1:0] bit_cnt;

// Control signals
wire bit_done;
assign bit_done = (bit_cnt == CLKS_PER_BIT - 1);
assign busy = (state != STATE_IDLE);

// Initialize registers
initial begin
    tx_p = 1'b1;
    state = STATE_IDLE;
    bitpos = 0;
    bit_cnt = 0;
end

// Bit counter
always @(posedge clk) begin
    if (state == STATE_IDLE)
        bit_cnt <= 0;
    else if (bit_cnt == CLKS_PER_BIT - 1)
        bit_cnt <= 0;
    else
        bit_cnt <= bit_cnt + CNT_WIDTH'(1);
end

// State machine
always @(posedge clk) begin
    case (state)
        STATE_IDLE: begin
            tx_p <= 1'b1;
            if (start) begin
                state <= STATE_START;
                bitpos <= 0;
            end
        end
        
        STATE_START: begin
            tx_p <= 1'b0;  // Start bit is always 0
            if (bit_done)
                state <= STATE_DATA;
        end
        
        STATE_DATA: begin
            tx_p <= data[bitpos];
            if (bit_done) begin
                if (bitpos == 7)
                    state <= STATE_STOP;
                else
                    bitpos <= bitpos + 3'd1;
            end
        end
        
        STATE_STOP: begin
            tx_p <= 1'b1;  // Stop bit is always 1
            if (bit_done)
                state <= STATE_IDLE;
        end
        
        default: begin
            tx_p <= 1'b1;
            state <= STATE_IDLE;
        end
    endcase
end

endmodule