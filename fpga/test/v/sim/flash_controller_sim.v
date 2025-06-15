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
module flash_controller_sim (
    input wire clk,
    input wire reset,

    input wire [23:0] flash_addr,
    input wire request_read_addr,
    input wire request_read_next,

    output reg d_ready,
    output reg [7:0] d_out 

);

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

reg [7:0] dummy_data = 1;



initial begin
    d_ready = 0;
    d_out = 0;
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
                d_ready <= 0;
                if (read_addr_requested) begin
                    state <= STATE_INIT_READ;
                    read_addr_requested <= 0;   
                end
            end
            
            STATE_INIT_READ: begin
                delay_counter <= 0;
                bit_pos <= 31;
                dummy_data <= flash_addr[7:0] + 1;
                state <= STATE_SEND_READ_ADDR;
            end
            
            STATE_SEND_READ_ADDR: begin
                if (delay_counter == 0) begin
                    delay_counter <= 1;
                end
                else begin
                    delay_counter <= 0;
                    if (bit_pos == 0) begin
                        state <= STATE_READ_DATA;
                        bit_pos <= 7;  // Prepare to read 8 bits
                    end
                    else begin
                        bit_pos <= bit_pos - 1;
                    end 
                end
            end
            
            STATE_READ_DATA: begin
                if (delay_counter == 0) begin
                    delay_counter <= 1;
                end
                else begin
                    delay_counter <= 0;
                    d_out <= 8'hFF; // fake the intermediate shifting state
                    if (bit_pos == 0) begin
                        d_out <= dummy_data;
                        dummy_data <= dummy_data + 1;
                        state <= STATE_READ_IDLE;
                        d_ready <= 1;
                    end
                    else begin
                        bit_pos <= bit_pos - 1;
                    end 
                end
            end
            
            STATE_READ_IDLE: begin
                if (read_next_requested) begin
                    state <= STATE_READ_DATA;
                    d_ready <= 0;
                    bit_pos <= 7; 
                    delay_counter <= 0;
                    read_next_requested <= 0;
                end else if (read_addr_requested) begin
                    state <= STATE_INIT;
                    d_ready <= 0;
                end
            end
            
            default: begin
                state <= STATE_INIT;
            end
        endcase
    end
end


endmodule