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

// Inspired by https://github.com/lushaylabs/tangnano9k-series-examples/tree/62687c5adf966ad17a3b0388e937c9a31f0b17b1/uart


// -----------------------------------------------------------------------------
// Implements a UART interface, loosely based on the 6551 UART.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
module uart(
    input wire clk,
    input wire [15:0] a,
    input wire select,
    input wire bus_access_strobe,
    input wire r_w_n,
    input wire [7:0] d_in,
    output reg [7:0] d_out,
    input wire rx_p,
    output wire tx_p
);

parameter clk_freq = 31500000;
parameter uart_freq = 9600;
localparam CLKS_PER_BIT = clk_freq / uart_freq;

// Register addresses
localparam DATA_REG  = 2'b00;
localparam STATUS_REG   = 2'b01;

// Internal signals
wire tx_busy;
wire rx_ready;
reg receiver_full = 0;
reg receiver_overrun = 0;

reg tx_start = 1'b0;
wire [7:0] rx_data;   // Data register that connects to uart_tx
reg [7:0] rx_data_reg = 8'h00; 
reg [7:0] tx_data;  

// Address decoding
wire is_data_reg = (select && a[1:0] == DATA_REG);
wire is_status_reg = (select && a[1:0] == STATUS_REG);

initial begin
    d_out = 8'h00;
end

// Instantiate the UART transmitter
uart_tx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
) uart_tx_inst (
    .clk(clk),
    .start(tx_start),
    .data(tx_data),    // Connect to our local data register
    .busy(tx_busy),
    .tx_p(tx_p)
);

uart_rx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
) uart_rx_inst (
    .clk(clk),
    .rx_p(rx_p),
    .data(rx_data),
    .data_ready(rx_ready)
);

// Write handling and data register management
always @(posedge clk) begin
    if (bus_access_strobe) begin
        tx_start <= 1'b0;  // Default state
        
        if (is_data_reg && !r_w_n && !tx_busy) begin
            tx_data <= d_in;       // Copy data to register
            tx_start <= 1'b1; // Start transmission
        end
    end
end

// Status register bits (similar to 6551)
wire [7:0] status = {
    3'b000,           // Unused
    ~tx_busy,         // 00010000 Transmitter Data Register empty
    receiver_full,    // 00001000 Receiver Data Register full
    receiver_overrun, // 
    2'b00             // Unused
};

always @(posedge clk) begin
    if (rx_ready) begin
        rx_data_reg <= rx_data;
        receiver_overrun <= receiver_full;
        receiver_full <= 1;
    end
    if (bus_access_strobe) begin
        if (select && r_w_n) begin
            if (is_data_reg) begin
                d_out <= rx_data;     // Read received data
                receiver_full <= 0;
                receiver_overrun <= 0;
            end else if (is_status_reg)
                d_out <= status;      // Read status register
            else
                d_out <= 8'h00;
        end
    end
end

endmodule