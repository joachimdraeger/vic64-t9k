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
// Implements the startup sequence.
// - Initialise PSRAM
// - Copy ROMs into PSRAM from flash
// - Blinks the LEDs to indicate startup status
// - Controls reset signal for the CPU
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
module startup #(
    // Parameters for timing - values in milliseconds
    parameter STARTUP_BLINK_CYCLES = 15,
    parameter SLOW_FLASH_MS = 300,    // Normal operation: 300ms
    parameter FAST_FLASH_MS = 150,    // Normal operation: 150ms
    parameter RAM_INIT_DELAY = 2,  // Normal operation: ~5ms
    parameter RAM_INIT_TIMEOUT = 10,  // Normal operation: ~5ms
    // Clock divider - set to 32000 for real hardware (32MHz to 1ms)
    // Can be set much lower for simulation
    parameter CLOCK_DIV = 32000
) (
    input wire clk32,            // 32MHz input clock
    input wire resn,             // System reset (active low)
    input wire ram_busy,         // RAM busy signal
    output reg startup_resetn,   // CPU reset control (active low)
    output wire [5:0] leds_out,  // LED output
    input wire [4:0] io_leds,          // LED input

    input wire ram_error,        // RAM error signal


    output reg [23:0] dma_flash_src_addr,
    output reg [21:0] dma_psram_dst_addr,
    output reg [15:0] dma_data_length,
    output reg dma_start,
    input wire dma_busy
);

    // State definitions
    localparam STATE_INIT = 0;      // Initial RAM initialization wait
    localparam STATE_FLASH_CHAR = 1; 
    localparam STATE_FLASH_KERNEL = 2; 
    localparam STATE_RUN_INFO = 3;  // Fast blink sequence
    localparam STATE_RUN = 4;       // Normal operation
    localparam STATE_ERROR = 5;     // Error state (slow blink)


    localparam STATUS_A              = 5'b10000;
    localparam STATUS_RESET          = 5'b11110;
    localparam STATUS_FLASH_CHAR     = 5'b11101;
    localparam STATUS_FLASH_KERNEL   = 5'b11110;
    localparam STATUS_RUN_INFO       = 5'b11100;
    localparam STATUS_RUN            = 5'b11111;
    localparam STATUS_RAM_INIT_ERROR = 5'b01110;
    localparam STATUS_RAM_RW_ERROR   = 5'b01101;
  
    // Internal clock division
    reg [15:0] clk_counter = 0;
    reg tick_ms;  // 1ms tick signal

    reg status_en = 1;
    reg status_led = 0;
    reg [4:0] status_code = STATUS_RESET;

    assign leds_out = status_en ? {status_led, status_code} : {1'b1, io_leds};

    reg [2:0] state = STATE_INIT;
    reg [7:0] state_cycle = 0;
    reg [15:0] ms_counter = 0;

    initial begin
        // Initialize output registers
        startup_resetn = 0;
        
        // gets set undriven if we don't set it in the state machine at least once
        dma_flash_src_addr = 24'h000000;
        dma_psram_dst_addr = 22'h001000;
        dma_data_length = 16'h1000;
        dma_start = 0;
    end    

    always @(posedge clk32 or negedge resn) begin
        if (!resn) begin
            state <= STATE_INIT;
            status_code <= STATUS_RESET;
            state_cycle <= 0;
            ms_counter <= 0;
            status_led <= 0;
            status_en <= 1;
            startup_resetn <= 0;
            clk_counter <= 0;
            dma_start <= 0;
        end else begin
            dma_start <= 0;
            if (tick_ms) begin
                case (state)
            
                    STATE_INIT: begin
                        if (!ram_busy && ms_counter >= RAM_INIT_DELAY) begin
                            // RAM initialization complete

                            ms_counter <= 0;
                            state_cycle <= 0;

                            dma_flash_src_addr <= 24'h000000;
                            dma_psram_dst_addr <= 22'h001000;
                            dma_data_length <= 16'h1000;
                            dma_start <= 1;
                            state <= STATE_FLASH_CHAR;
                            status_code <= STATUS_FLASH_CHAR;
                        end else begin
                            if (ms_counter == RAM_INIT_TIMEOUT) begin
                                state <= STATE_ERROR;
                                status_code <= STATUS_RAM_INIT_ERROR;
                                ms_counter <= 0;
                            end else begin
                                ms_counter <= ms_counter + 16'd1;
                            end
                        end
                    end

                    STATE_FLASH_CHAR: begin
                        if (!dma_busy) begin
                            state <= STATE_FLASH_KERNEL;
                            status_code <= STATUS_FLASH_KERNEL;
                            dma_flash_src_addr <= 24'h001000;
                            dma_psram_dst_addr <= 22'h00F800;
                            dma_data_length <= 16'h0800; // 2048 bytes
                            dma_start <= 1;

                            ms_counter <= 0;
                        end
                    end

                    STATE_FLASH_KERNEL: begin
                        if (!dma_busy) begin
                            state <= STATE_RUN_INFO;
                            status_code <= STATUS_RUN_INFO;

                            ms_counter <= 0;
                            state_cycle <= 0;
                        end
                    end

                    STATE_RUN_INFO: begin
                        // Fast blink sequence
                        if (ms_counter == FAST_FLASH_MS) begin
                            status_led <= ~status_led;
                            ms_counter <= 0;
                            if (state_cycle == STARTUP_BLINK_CYCLES) begin  // 8 complete blinks
                                state <= STATE_RUN;
                                status_code <= 5'b11111;
                                startup_resetn <= 1;
                                state_cycle <= 0;
                                status_en <= 0;
                                status_led <= 1;
                            end else begin
                                state_cycle <= state_cycle + 8'd1;
                            end
                        end else begin
                            ms_counter <= ms_counter + 16'd1;
                        end
                    end

                    STATE_RUN: begin
                        if (ram_error) begin
                            state <= STATE_ERROR;
                            status_code <= STATUS_RAM_RW_ERROR;
                            status_en <= 1;
                            status_led <= 1;
                            ms_counter <= 0;
                        end
                    end

                    STATE_ERROR: begin
                        // Slow blink pattern for error state
                        if (ms_counter == SLOW_FLASH_MS) begin
                            status_led <= ~status_led;
                            ms_counter <= 0;
                        end else begin
                            ms_counter <= ms_counter + 16'd1;
                        end
                    end
                endcase
            end
            if (clk_counter == CLOCK_DIV - 1) begin
                clk_counter <= 0;
            end else begin
                clk_counter <= clk_counter + 16'd1;
            end
            tick_ms <= (clk_counter == CLOCK_DIV - 1);
        end
    end

endmodule