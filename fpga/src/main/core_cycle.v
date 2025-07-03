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


// Inspired by https://github.com/MiSTer-devel/C64_MiSTer/blob/8b75fdb9fbd62ae719ba494bc4edc60dd18e156d/rtl/fpga64_sid_iec.vhd
// Original author: Peter Wendrich (pwsoft@syntiac.com) http://www.syntiac.com/fpga64.html
// Mister changes by: Dar 08/03/2014, Alexey Melnikov 2021
// - reimplemented in Verilog
// - simplified to only handle essential timing for the VIC-II and CPU
// - adopted original variable/constant names

// -----------------------------------------------------------------------------
// Generates the timing signals for the VIC-II, CPU, PSRAM
// Breaks down the 32mhz clock into 32 cycles to provide:
// - PHI0 clock for the CPU
// - Pixel clock for the VIC-II (8MHz)
// - VIC enable timing
// - PSRAM interface strobes, including error detection
// - BUS access timing
// - CPU vs VIC ram access coordination
// -----------------------------------------------------------------------------


`timescale 1ns/1ps
module core_cycle (
    // Clock and Reset
    input wire clk32,
    input wire reset_n_in,

    output reg resetn,

    // Timing signals
    output reg phi,
    output reg enableVic,
    output reg enablePixel,
    output reg bus_access_strobe_pre,
    output reg bus_access_pre,

    // PSRAM interface
    input wire psram_en,
    input wire r_wn,
    input wire psram_busy,
    output reg psram_r_strobe,
    output reg psram_w_strobe,
    output reg psram_ram_error,
    
    // CPU data latching
    input wire vic_aec,
    input wire [7:0] cpu_data_in_bus,
    output reg [7:0] cpu_data_in_latched
);

    // =========================================================================
    // Cycle Constants Documentation
    // =========================================================================
    // This module implements a 32-cycle system (0-31) for VIC-II timing
    // 
    // Important cycle constants and their purposes:
    // 
    // Cycle 1  - Memory access cycle 1 (PSRAM read/write strobe)
    // Cycle 2  - CYCLE_EXT2 - Pixel enable
    // Cycle 6  - CYCLE_DMA2 - Pixel enable
    // Cycle 10 - CYCLE_EXT6 - Pixel enable
    // Cycle 13 - RAM error check cycle 1
    // Cycle 14 - CYCLE_VIC2 - VIC-II cycle 2, VIC enable, Pixel enable
    // Cycle 15 - CYCLE_VIC3 - VIC-II cycle 3, PHI clock rising edge
    // Cycle 17 - Memory access cycle 2 (PSRAM read/write strobe)
    //            Bus access cycle 2 (after phi rising edge)
    // Cycle 18 - CYCLE_CPU2 - Pixel enable
    // Cycle 22 - CYCLE_CPU6 - Pixel enable
    // Cycle 26 - CYCLE_CPUA - Pixel enable
    // Cycle 29 - RAM error check cycle 2
    // Cycle 30 - CYCLE_CPUE - VIC enable, Pixel enable
    // Cycle 31 - CYCLE_CPUF - PHI clock falling edge, Reset handling
    // =========================================================================

    // System cycle counter
    reg [4:0] sys_cycle;

    // Initialize registers
    initial begin
        resetn = 1'b0;
        phi = 1'b0;
        psram_ram_error = 1'b0;
        sys_cycle = 5'd0;
        psram_r_strobe = 1'b0;
        psram_w_strobe = 1'b0;
    end

    // Increment sys_cycle on each clock
    always @(posedge clk32) begin
        sys_cycle <= sys_cycle + 5'd1;
    end

    // Reset handling
    always @(posedge clk32) begin
        if (sys_cycle == 5'd31) begin  // CYCLE_CPUF
            resetn <= reset_n_in;
        end
    end

    // PHI0/2-clock emulation
    always @(posedge clk32) begin
        if (sys_cycle == 5'd15) begin  // CYCLE_VIC3
            phi <= 1'b1;
            // CPU has bus logic would go here if needed
        end
        if (sys_cycle == 5'd31) begin  // CYCLE_CPUF
            if (!vic_aec) begin
                cpu_data_in_latched <= cpu_data_in_bus;
            end
            phi <= 1'b0;
            // CPU has bus logic would go here if needed
        end
    end

    // Bus access timing - active right after phi edges
    always @(posedge clk32) begin
        // having this 2 cycles after the phi edge seems to improve timing (example: status read for uart)
        // moving it to 16 because there will be another cycle added in bus.v
        bus_access_strobe_pre <= (sys_cycle == 5'd16) ? 1'b1 : 1'b0;
        bus_access_pre <= (sys_cycle >= 5'd16 && sys_cycle <= 5'd30) ? 1'b1 : 1'b0;
    end

    // VIC enable timing
    always @(posedge clk32) begin
        enableVic <= 1'b0;
        case (sys_cycle)
            5'd14: enableVic <= 1'b1;  // CYCLE_VIC2
            5'd30: enableVic <= 1'b1;  // CYCLE_CPUE
            default: enableVic <= 1'b0;
        endcase
    end

    // Pixel timing
    always @(posedge clk32) begin
        enablePixel <= 1'b0;
        if (sys_cycle == 5'd2  || // CYCLE_EXT2
            sys_cycle == 5'd6  || // CYCLE_DMA2
            sys_cycle == 5'd10 || // CYCLE_EXT6
            sys_cycle == 5'd14 || // CYCLE_VIC2
            sys_cycle == 5'd18 || // CYCLE_CPU2
            sys_cycle == 5'd22 || // CYCLE_CPU6
            sys_cycle == 5'd26 || // CYCLE_CPUA
            sys_cycle == 5'd30)   // CYCLE_CPUE
        begin
            enablePixel <= 1'b1;
        end
    end

    // PSRAM interface logic
    always @(posedge clk32) begin
        // Default values
        psram_r_strobe <= 1'b0;
        psram_w_strobe <= 1'b0;
        
        // Check for memory access at appropriate cycles
        // The CPU would work fine at cycle 0 but the VIC-II needs an extra cycle to set the address
        if (psram_en && (sys_cycle == 5'd1 || sys_cycle == 5'd17)) begin
            if (r_wn) begin
                psram_r_strobe <= 1'b1;
            end else begin
                psram_w_strobe <= 1'b1;
            end
        end
        
        // Check for RAM errors
        if ((sys_cycle == 5'd13 || sys_cycle == 5'd29) && psram_busy) begin
            psram_ram_error <= 1'b1;
        end else if (reset_n_in == 1'b0) begin
            psram_ram_error <= 1'b0;
        end
    end
    

endmodule 