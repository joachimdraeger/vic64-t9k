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
// This module implements a DMA controller for copying from SPI Flash memory to
// PSRAM. It is used to mirror ROMs into PSRAM during startup since flash would be 
// too slow for random access.
// -----------------------------------------------------------------------------


`timescale 1ns/1ps
module flash_dma (
    input wire clk,

    output reg flash_dma_enabled, // Indicates DMA is active (initially disabled)

    input wire [23:0] flash_src_addr,
    input wire [21:0] psram_dst_addr,
    input wire [15:0] data_length,
    input wire start,
    output reg busy,
    
    // Flash controller interface
    output reg [23:0] flash_addr,
    output reg flash_req_r_addr,
    output reg flash_req_r_next,
    input wire flash_d_ready,
    input wire [7:0] flash_d_out,
    
    // PSRAM controller interface for DMA operations
    output reg psram_w_strobe,
    output reg [21:0] psram_addr,
    output reg [15:0] psram_d_in,
    input wire psram_busy
    
);

reg [15:0] data_count = 16'h0;

localparam STATE_IDLE            = 3'd0; 
localparam STATE_WAIT_FLASH_BUSY = 3'd1;
localparam STATE_NEXT            = 3'd2;
localparam STATE_WAIT_PSRAM_BUSY = 3'd3;
localparam STATE_WAIT_PSRAM      = 3'd4;

reg [2:0] state = STATE_IDLE;

initial begin
    flash_dma_enabled = 1'b0;
    // Initialize all outputs to 0
    flash_addr = 24'h0;
    flash_req_r_addr = 1'b0;
    flash_req_r_next = 1'b0;
    psram_addr = 22'h0;
    psram_d_in = 16'h0;
    psram_w_strobe = 1'b0;
    busy = 1'b0;
end

always @(posedge clk) begin
    flash_req_r_addr <= 1'b0;
    flash_req_r_next <= 1'b0;
    psram_w_strobe <= 1'b0;

    case (state)
        STATE_IDLE: begin
            busy <= 1'b0;
            flash_dma_enabled <= 1'b0;
            if (start) begin
                busy <= 1'b1;
                flash_dma_enabled <= 1'b1;
                data_count <= data_length;
                psram_addr <= psram_dst_addr - 22'd1;
                flash_addr <= flash_src_addr;
                state <= STATE_WAIT_FLASH_BUSY;
                flash_req_r_addr <= 1'b1;
            end
        end
        STATE_WAIT_FLASH_BUSY: begin
            // When flash controller was in read next state, d_ready will be 1 for a clock cycle
            if (!flash_d_ready) begin
                state <= STATE_NEXT;
            end
        end
        STATE_NEXT: begin
            if (flash_d_ready && !psram_busy) begin
                psram_d_in <= {flash_d_out, flash_d_out};
                psram_addr <= psram_addr + 22'd1;
                psram_w_strobe <= 1'b1;
                if (data_count != 16'd0) begin 
                    data_count <= data_count - 16'd1;
                    if (data_count != 16'd1) begin
                        flash_req_r_next <= 1'b1;
                    end
                end 
                state <= STATE_WAIT_PSRAM_BUSY;
            end
        end
        STATE_WAIT_PSRAM_BUSY: begin
            if (psram_busy) begin    
                if (data_count != 16'h0) begin
                    state <= STATE_NEXT;
                end else begin
                    state <= STATE_WAIT_PSRAM;
                end
            end
        end
        STATE_WAIT_PSRAM: begin
            if (!psram_busy) begin            
                state <= STATE_IDLE;
            end 
        end
        
    endcase 
end

endmodule 