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
module flash_dma_tb;


reg reset_n = 0;
reg clk32 = 0;
reg clk64 = 0;


reg flash_dma_start = 0;
wire flash_dma_busy;

wire [23:0] flash_addr;
wire flash_req_r_addr;
wire flash_req_r_next;
wire flash_d_ready;
wire [7:0] flash_d_out;

wire psram_w_strobe;
wire [21:0] psram_addr;
wire [15:0] psram_d_in;
wire psram_busy;

psram_wrapper_sim psram_wrapper_inst (
    .clk32(clk32),
    .clk64(clk64),
    .resetn(reset_n),
    .write(psram_w_strobe),
    .read(1'b0),
    .byte_write(1'b1),
    .addr(psram_addr),
    .din(psram_d_in),
    .busy(psram_busy)
);

flash_controller_sim flash_controller_sim_inst (
    .clk(clk32),
    .reset(1'b0),
    .flash_addr(flash_addr),
    .request_read_addr(flash_req_r_addr),
    .request_read_next(flash_req_r_next),
    .d_ready(flash_d_ready),
    .d_out(flash_d_out)
);

flash_dma flash_dma_inst (
        .clk(clk32),

        .flash_src_addr(24'hA1B200),
        .psram_dst_addr(22'h03D400),
        .data_length(16'd8),
        .start(flash_dma_start),
        .busy(flash_dma_busy),

        // Flash controller interface
        .flash_addr(flash_addr),
        .flash_req_r_addr(flash_req_r_addr),
        .flash_req_r_next(flash_req_r_next),
        .flash_d_ready(flash_d_ready),
        .flash_d_out(flash_d_out),
        
        // PSRAM controller interface for DMA operations
        .psram_w_strobe(psram_w_strobe),
        .psram_addr(psram_addr),
        .psram_d_in(psram_d_in),
        .psram_busy(psram_busy)

);

always #15 clk32 = ~clk32;
always #8 clk64 = ~clk64;

// Timeout watchdog
initial begin
    // Wait for 5ms before timing out
    #3200000000;  
    $display("\n*** Simulation timeout ***");
    $display("Simulation stopped - check waveforms for debugging");
    $finish;
end

initial begin
    $monitor("Time=%0t: reset_n=%b", 
                $time, reset_n);
end

// Test sequence
initial begin
    $display("Simulation started");
    // Apply reset for a short time
    reset_n = 0;
    #100;
    reset_n = 1;
    
    $display("Reset applied");

    #30
    
    // Set flash_dma_start high
    flash_dma_start = 1;
    #30;  // Wait for one clk32 cycle
    flash_dma_start = 0;
    $display("DMA start triggered");

    #12000;

    $display("Simulation completed after 32000 clk32 cycles");
    $finish;
end

initial begin
    $dumpfile("build/flash_dma_tb.vcd");
    $dumpvars(0, flash_dma_tb);
end


endmodule   