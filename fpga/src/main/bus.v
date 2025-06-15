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
// This module implements bus logic to control which devices are enabled for
// certain addresses and VIC-II access.
// -----------------------------------------------------------------------------


`timescale 1ns/1ps
module bus (
    
    input wire clk32,

    output wire io_en,          // External I/O enable signal for $DE00-$DFFF
    
    // CPU interface
    input wire [23:0] cpu_addr_out, // CPU address bus
    input wire cpu_r_wn,
    input wire [7:0] cpu_data_out,  // CPU data output
    output wire [7:0] cpu_data_in,  // CPU data input

    output wire bus_r_wn,
    output wire [15:0] bus_addr,

    // VIC interface
    input wire vic_aec,
    input wire [15:0] vic_addr,
    output wire [7:0] vic_d_in,
    input wire [7:0] vic_d_out,
    output reg vic_cs,
    
    // PSRAM interface
    output wire psram_en,
    output wire [21:0] psram_addr,  // PSRAM address
    output wire [15:0] psram_d_in,   // PSRAM data input
    input wire [15:0] psram_d_out,    // PSRAM data output
    output wire psram_r_strobe,  // PSRAM read strobe
    output wire psram_w_strobe,  // PSRAM write strobe
    
    // Core PSRAM access signals
    input wire core_psram_r_strobe,
    input wire core_psram_w_strobe,

    // Color RAM interface
    output reg color_ram_enabled,
    output wire [9:0] color_ram_addr,
    input wire [3:0] color_ram_d_out,

    // UART interface
    output wire uart_select,
    input wire [7:0] uart_dout,
    
    
    // Flash interface
    output wire flash_select,
    input wire [7:0] flash_dout,
    
    // Flash controller interface signals
    output wire [23:0] flash_addr,
    output wire flash_req_r_addr,
    output wire flash_req_r_next,
    
    // IO Flash controller signals
    input wire [23:0] flash_addr_fio,
    input wire flash_req_r_addr_fio,
    input wire flash_req_r_next_fio,
    
    // DMA Flash controller signals
    input wire [23:0] flash_addr_fdma,
    input wire flash_req_r_addr_fdma,
    input wire flash_req_r_next_fdma,
    
    // Flash DMA interface
    input wire flash_dma_enabled,
    input wire [21:0] psram_addr_fdma,
    input wire [15:0] psram_d_in_fdma,
    input wire psram_w_strobe_fdma,
    
    input wire bus_access_strobe_pre,
    input wire bus_access_pre,
    output reg bus_access_strobe
);

    wire color_ram_select;
    wire vic_select;

initial begin
    color_ram_enabled = 1'b0;
    vic_cs = 1'b0;
end

    assign bus_addr = cpu_addr_out[15:0];


    // NOTE: I/O ranges assigned to devices should always be of size 2^n (1,2,4,8,16 bytes)
    // This ensures proper address decoding and maintains compatibility with standard bus protocols
    
    assign io_en = (bus_addr >= 16'hDE00 && bus_addr <= 16'hDFFF);

    assign uart_select = (bus_addr >= 16'hDE00 && bus_addr <= 16'hDE03);
    assign flash_select = (bus_addr >= 16'hDE08 && bus_addr <= 16'hDE0F);

    assign psram_en = !io_en || vic_aec;

    // PSRAM address selection
    // First, determine CPU/VIC address based on vic_aec
    wire [21:0] normal_psram_addr = vic_aec ? {6'b0, vic_addr} : {6'b0, bus_addr};
    
    // Then select between normal address and flash_dma address
    assign psram_addr = flash_dma_enabled ? psram_addr_fdma : normal_psram_addr;
    assign psram_d_in = flash_dma_enabled ? psram_d_in_fdma : {cpu_data_out, cpu_data_out};
    assign psram_r_strobe = flash_dma_enabled ? 0 : core_psram_r_strobe;
    assign psram_w_strobe = flash_dma_enabled ? psram_w_strobe_fdma : core_psram_w_strobe;

    // Color RAM
    assign color_ram_select = (bus_addr >= 16'hD800 && bus_addr <= 16'hDBFF);
    assign color_ram_addr = vic_aec ? vic_addr[9:0] : bus_addr[9:0];



    // VIC interface
    assign vic_select = (bus_addr >= 16'hD000 && bus_addr <= 16'hD3FF);

    // doing this with assign would cause instability
    always @(posedge clk32) begin
        color_ram_enabled <= (vic_aec || color_ram_select) && bus_access_strobe_pre;
        // VIC needs to be enabled when it is selected and the bus can be accessed, it has its own timing
        vic_cs <= !vic_aec && vic_select && bus_access_pre;
        bus_access_strobe <= bus_access_strobe_pre && !vic_aec;
    end


    // Flash controller signals muxing based on DMA enable
    assign flash_addr = flash_dma_enabled ? flash_addr_fdma : flash_addr_fio;
    assign flash_req_r_addr = flash_dma_enabled ? flash_req_r_addr_fdma : flash_req_r_addr_fio;
    assign flash_req_r_next = flash_dma_enabled ? flash_req_r_next_fdma : flash_req_r_next_fio;
    
    // decode cpu_data_in
    wire [7:0] psram_byte = psram_addr[0] ? psram_d_out[15:8] : psram_d_out[7:0];
    assign cpu_data_in = uart_select ? uart_dout :
                         flash_select ? flash_dout :
                         io_en ? 8'h00 :
                         color_ram_select ? {4'b0, color_ram_d_out} :
                         vic_select ? vic_d_out :
                         psram_byte;
                         
    // Data for VIC-II comes from the same PSRAM location
    assign vic_d_in = psram_byte;

    // Bus read/write control - CPU can only write when VIC is not accessing bus
    assign bus_r_wn = cpu_r_wn || vic_aec;

endmodule