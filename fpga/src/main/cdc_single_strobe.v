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
// Implements clock domain crossing for a strobe signal from a slower to 
// a faster clock. Provides a single cycle 1 on the dst_signal when a positive
// edge is detected on the src_signal.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
module cdc_single_strobe (
    input  wire src_signal,  // Input signal in source clock domain
    input  wire dst_clk,     // Destination clock
    output reg dst_signal   // Synchronized output in destination clock domain
);

initial begin
    dst_signal <= 1'b0;
end

    // Two-stage synchronizer flip-flop chain
    (* ASYNC_REG = "TRUE" *) reg sync_ff1;
    (* ASYNC_REG = "TRUE" *) reg sync_ff2;
    (* ASYNC_REG = "TRUE" *) reg sync_ff3;
    
    always @(posedge dst_clk) begin
        sync_ff1 <= src_signal;  // First stage
        sync_ff2 <= sync_ff1;    // Second stage
        sync_ff3 <= sync_ff2;    // Third stage

        if (sync_ff3 == 1'b0 && sync_ff2 == 1'b1) begin
            dst_signal <= 1'b1;
        end else begin
            dst_signal <= 1'b0;
        end 
    end
    


endmodule