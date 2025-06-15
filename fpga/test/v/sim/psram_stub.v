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
module psram_stub (
    input clk,               // Clock input
    input resetn,           // Active low reset
    input read,            // Read command
    input write,           // Write command
    input byte_write,      // 1 for byte write, 0 for word write
    input [21:0] addr,     // Address input
    input [15:0] din,      // Data input for writes
    output reg [15:0] dout, // Data output for reads
    output reg busy        // Indicates memory is busy with operation
);

    // Latency parameters to match real PSRAM
    localparam READ_LATENCY_1X = 12;
    parameter READ_LATENCY_2X = 15;
    localparam WRITE_LATENCY_1X = 7;
    parameter WRITE_LATENCY_2X = 10;

    
    // State machine states
    localparam IDLE = 2'b00;
    localparam READING = 2'b01;
    localparam WRITING = 2'b10;
    
    reg [1:0] state;
    reg [5:0] cycle_count;  // Counter for simulating memory latency
    
    // Random number for latency selection
    reg [7:0] rand_counter = 8'h5A;
    wire use_2x_latency;
    
    // Use bit 7 of counter to determine 2x latency
    // This gives roughly 50% chance of 2x latency
    // Real HyperRAM uses 2x about 0.05% of the time
    assign use_2x_latency = rand_counter[7];

    reg [15:0] last_write_data = 16'h0000;
        
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            busy <= 0;
            dout <= 16'h0000;
            cycle_count <= 0;
            rand_counter <= 8'h5A; // Initial seed
        end else begin
            rand_counter <= rand_counter + 8'd1;
            case (state)
                IDLE: begin
                    cycle_count <= 0;
                    if (read) begin
                        state <= READING;
                        busy <= 1;
                    end else if (write) begin
                        state <= WRITING;
                        busy <= 1;
                    end else begin
                        busy <= 0;
                    end
                end
                
                READING: begin
                    cycle_count <= cycle_count + 6'd1;
                    if (cycle_count == (use_2x_latency ? READ_LATENCY_2X : READ_LATENCY_1X)) begin
                        // Read word from memory
                        dout <= addr[15:0];
                        state <= IDLE;
                        busy <= 0;
                    end
                end
                
                WRITING: begin
                    cycle_count <= cycle_count + 6'd1;
                    if (cycle_count == (use_2x_latency ? WRITE_LATENCY_2X : WRITE_LATENCY_1X)) begin
                        if (byte_write) begin
                            if (addr[0]) begin
                                last_write_data <= {8'h00, din[7:0]};
                            end else begin
                                last_write_data <= {din[15:8], 8'h00};
                            end
                        end else begin
                            last_write_data <= din;
                        end
                        state <= IDLE;
                        busy <= 0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule