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
// Simple IO interface to the SPI Flash controller. Supports setting the 24-bit
// address and consecutive reads. The flash controller is fast enough to provide
// consecutive data in a single CPU cycle, so using the flash_d_ready signal is 
// only needed when setting the address.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
module flash_io (
    input wire clk,                // System clock
    input wire bus_access_strobe,  // Enable bus access
    input wire [15:0] a,           // Address bus
    input wire select,             // Module select signal
    input wire r_w_n,              // Read/Write control (1=read, 0=write)
    input wire [7:0] d_in,         // Data input bus
    output reg [7:0] d_out,        // Data output bus
    
    // SPI Flash interface connections (now external)
    input wire flash_d_ready,   // Signal indicating data is ready from flash controller
    input wire [7:0] flash_d_out,  // Data output from flash controller
    output reg [23:0] flash_addr,  // 24-bit flash address
    output reg flash_req_r_addr, // Request to read from specific address
    output reg flash_req_r_next  // Request to read next byte
);

// Register addresses using 3 LSB bits for decoding
localparam STATUS_REG   = 3'd0;   // 0xDE08: Flash status register
localparam ADDR_HIGH    = 3'd1;   // 0xDE09: Address high byte (A23-A16)
localparam ADDR_MID     = 3'd2;   // 0xDE0A: Address middle byte (A15-A8) 
localparam ADDR_LOW     = 3'd3;   // 0xDE0B: Address low byte (A7-A0)
localparam DATA_REG     = 3'd4;   // 0xDE0C: Data register - reads byte at current address
// 3'd5, 3'd6, 3'd7 reserved for future use

// Internal registers
// Address decoding for registers
wire [2:0] reg_addr = a[2:0];

// Handle register reads/writes
always @(posedge clk) begin
    flash_req_r_addr <= 0;
    flash_req_r_next <= 0;  

    if (bus_access_strobe) begin
        // Handle register writes
        if (select && !r_w_n) begin
            case (reg_addr)
                ADDR_HIGH: flash_addr[23:16] <= d_in;
                ADDR_MID: flash_addr[15:8] <= d_in;
                ADDR_LOW: flash_addr[7:0] <= d_in;
                default: begin end // Do nothing for other registers
            endcase
            if (reg_addr == ADDR_HIGH || reg_addr == ADDR_MID || reg_addr == ADDR_LOW) begin
                flash_req_r_addr <= 1;
            end
        end
        
        // Handle register reads
        if (select && r_w_n) begin
            case (reg_addr)
                STATUS_REG: d_out <= {7'b0000000, flash_d_ready};
                ADDR_HIGH: d_out <= flash_addr[23:16];
                ADDR_MID: d_out <= flash_addr[15:8];
                ADDR_LOW: d_out <= flash_addr[7:0];
                DATA_REG: begin
                    if (flash_d_ready) begin 
                        d_out <= flash_d_out;
                        flash_req_r_next <= 1;
                        flash_addr <= flash_addr + 24'd1;
                    end
                    else begin
                        d_out <= 8'h00;  // TODO trigger underflow error
                    end
                end
                default: d_out <= 8'h00;
            endcase
        end
    end
end

endmodule 