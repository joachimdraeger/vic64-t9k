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
// Receiver module for the UART.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
module uart_rx #(
    parameter CLKS_PER_BIT = 64125000 / 32 / 9600
) (
    input wire clk,
    input wire rx_p,
    output reg [7:0] data,
    output reg data_ready
);

// States
localparam STATE_IDLE = 2'b00;
localparam STATE_START = 2'b01;
localparam STATE_DATA = 2'b10;
localparam STATE_STOP = 2'b11;

// Timing parameters (matching uart_tx)
localparam CNT_WIDTH = $clog2(CLKS_PER_BIT);
localparam HALF_BIT = CLKS_PER_BIT / 2;

reg [CNT_WIDTH-1:0] bit_cnt;
reg [2:0] bit_pos;
reg [1:0] state;

wire bit_done;
assign bit_done = (bit_cnt == CLKS_PER_BIT - 1);



// Initialize registers
initial begin
    state = STATE_IDLE;
    bit_pos = 0;
    bit_cnt = 0;
    data_ready = 0;
end

// State machine
always @(posedge clk) begin
    data_ready <= 0;  // Default state

    // must be before the case statement so that STATE_START can reset the counter
    if (state == STATE_IDLE)
        bit_cnt <= 0;
    else if (bit_cnt == CLKS_PER_BIT - 1)
        bit_cnt <= 0;
    else
        bit_cnt <= bit_cnt + CNT_WIDTH'(1);
    
    case (state)
        STATE_IDLE: begin
            if (!rx_p) begin  // Start bit detected
                state <= STATE_START;
                bit_pos <= 0;
            end
        end
        
        STATE_START: begin
            if (bit_cnt == HALF_BIT) begin  // Sample middle of start bit
                if (!rx_p) begin  // Confirm start bit is still low
                    state <= STATE_DATA;
                    bit_cnt <= 0;  // Reset counter for proper data bit alignment
                end
                else
                    state <= STATE_IDLE;  // False start
            end
        end
        
        STATE_DATA: begin
            if (bit_cnt == CLKS_PER_BIT - 1) begin  // Sample at end of bit
                data[bit_pos] <= rx_p;
                if (bit_pos == 7)
                    state <= STATE_STOP;
                else
                    bit_pos <= bit_pos + 3'd1;
            end
        end
        
        STATE_STOP: begin
            if (bit_done) begin
                if (rx_p) begin  // Valid stop bit
                    data_ready <= 1;
                end
                state <= STATE_IDLE;
            end
        end
        
        default: state <= STATE_IDLE;
    endcase
end

endmodule