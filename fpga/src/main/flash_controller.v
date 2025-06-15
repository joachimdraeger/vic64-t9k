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
// This module provides an abstraction layer for SPI Flash memory operations.
// It supports:
// - Reading data from a specific 24-bit address
// - Reading consecutive bytes after an initial address read
// - Handles all SPI timing and protocol details internally
// -----------------------------------------------------------------------------


`timescale 1ns/1ps
module flash_controller (
    input wire clk,
    input wire reset,

    input wire [23:0] flash_addr,
    input wire request_read_addr,
    input wire request_read_next,

    output reg d_ready,
    output reg [7:0] d_out, 

    // SPI Flash interface
    output reg flash_clk,      // Flash clock
    input wire flash_miso,     // Flash MISO (input from flash)
    output reg flash_mosi,     // Flash MOSI (output to flash)
    output reg flash_cs        // Flash chip select (active low)
);

// Flash commands
localparam CMD_READ     = 8'h03;   // Read data command

// State machine states
localparam STATE_INIT           = 4'd0;  // Idle state
localparam STATE_INIT_READ      = 4'd1;  // Starting read operation
localparam STATE_SEND_READ_ADDR = 4'd2;  // Sending command + address
localparam STATE_READ_DATA      = 4'd3;  // Reading data
localparam STATE_READ_IDLE      = 4'd4;  // Data ready    

reg [3:0] state = STATE_INIT;        // State machine state
reg [4:0] bit_pos;                   // Counter for bit operations
reg delay_counter = 0;               // Counter for timing delays. We're currently banging a bit out on every clock cycle.

reg read_addr_requested = 0;
reg read_next_requested = 0;    

// Internal data registers
reg [31:0] data_to_send = 0;         // Data to shift out to flash (command + address)

// Initialize output registers
initial begin
    d_ready = 0;
    d_out = 8'h00;
    flash_clk = 0;
    flash_mosi = 0;
    flash_cs = 1;
end

// State machine for flash operations
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= STATE_INIT;
    end else begin
        if (request_read_addr) begin
            read_addr_requested <= 1;
        end
        if (request_read_next) begin
            read_next_requested <= 1;
        end 
        case (state)
            STATE_INIT: begin
                flash_cs <= 1;          // Keep CS high while idle
                flash_clk <= 0;
                d_ready <= 0;
                if (read_addr_requested) begin
                    state <= STATE_INIT_READ;
                    read_addr_requested <= 0;   
                end
            end
            
            STATE_INIT_READ: begin
                delay_counter <= 0;
                flash_cs <= 0;          // Activate CS (active low)
                data_to_send <= {CMD_READ, flash_addr}; // Command + address
                bit_pos <= 31;      // 8 bits for command + 24 bits for address
                state <= STATE_SEND_READ_ADDR;
            end
            
            STATE_SEND_READ_ADDR: begin
                if (delay_counter == 0) begin
                    flash_clk <= 0;
                    flash_mosi <= data_to_send[bit_pos]; 
                    delay_counter <= 1;
                end
                else begin
                    delay_counter <= 0;
                    flash_clk <= 1;     // Toggle clock high

                    if (bit_pos == 0) begin
                        state <= STATE_READ_DATA;
                        bit_pos <= 7;  // Prepare to read 8 bits
                    end
                    else begin
                        bit_pos <= bit_pos - 5'd1;
                    end 
                end
            end
            
            STATE_READ_DATA: begin
                if (delay_counter == 0) begin
                    flash_clk <= 0;     // Toggle clock low
                    delay_counter <= 1;
                end
                else begin
                    delay_counter <= 0;
                    flash_clk <= 1;     // Toggle clock high
                    d_out <= {d_out[6:0], flash_miso};
                    
                    if (bit_pos == 0) begin
                        state <= STATE_READ_IDLE;
                        d_ready <= 1;
                    end
                    else begin
                        bit_pos <= bit_pos - 5'd1;
                    end 
                end
            end
            
            // unsure if the flash supports holding this over long periods of time
            STATE_READ_IDLE: begin
                flash_clk <= 1; 
                if (read_next_requested) begin
                    state <= STATE_READ_DATA;
                    d_ready <= 0;
                    bit_pos <= 7; 
                    delay_counter <= 0;
                    read_next_requested <= 0;
                end else if (read_addr_requested) begin
                    state <= STATE_INIT;
                    flash_cs <= 1; 
                    d_ready <= 0;
                end
            end
            
            default: begin
                flash_cs <= 1; 
                state <= STATE_INIT;
            end
        endcase
    end
end

endmodule
