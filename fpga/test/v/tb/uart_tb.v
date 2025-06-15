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
module uart_tb;

// Testbench signals
reg clk;
reg [15:0] a;
reg select;
reg r_w_n;
reg [7:0] d_in;
wire [7:0] d_out;
wire tx_p;
wire bus_access_strobe = 1'b1;  // Permanently set to 1

// Additional reg for wait_for_idle task
reg busy;

// Debug counters
integer tx_bits;
time last_edge;
time bit_time;

// Initialize signals
initial begin
    clk = 0;
    busy = 0;
    tx_bits = 0;
    last_edge = 0;
    bit_time = 0;
end

always #250 clk = ~clk;  // Toggle every 250ns for 2MHz

// Instantiate UART module
uart uart_inst (
    .clk(clk),
    .a(a),
    .select(select),
    .bus_access_strobe(bus_access_strobe),  // Connect bus_access_strobe
    .r_w_n(r_w_n),
    .d_in(d_in),
    .d_out(d_out),
    .tx_p(tx_p),
    .rx_p(tx_p)
);

// Timeout watchdog
initial begin
    // Wait for 5ms before timing out
    #500000000;  // 5ms at 1MHz clock
    $display("\n*** Simulation timeout ***");
    $display("Simulation stopped - check waveforms for debugging");
    $finish;
end

// Test procedure
initial begin
    $dumpfile("build/uart_tb.vcd");
    $dumpvars(0, uart_tb);

    // Initialize signals
    a = 16'h0000;
    select = 0;
    r_w_n = 1;
    d_in = 8'h00;
    
    // Wait for 100 clock cycles before starting
    repeat(100) @(posedge clk);
    
    // Send first byte: 0xAA
    $display("Sending 0xAA");
    send_byte(8'hAA);
    wait_for_idle;
    wait_for_data;
    receive_byte;
    repeat(10) @(posedge clk);
    
    // Send second byte: 0x55
    $display("Sending 0x55");
    send_byte(8'h55);
    wait_for_data;
    receive_byte;
    wait_for_idle;
    repeat(10) @(posedge clk);
    
    // Send third byte: 0xFF
    $display("Sending 0xFF");
    send_byte(8'hFF);
    wait_for_idle;
    wait_for_data;
    receive_byte;
    repeat(100) @(posedge clk);
    
    // End simulation
    $display("Testbench completed");
    $finish;
end

// Task to send a byte
task send_byte;
    input [7:0] byte_to_send;
    begin
        // Wait for one clock cycle
        @(posedge clk);
        
        // Set up write to TX_DATA_REG (0xDF00)
        a = 16'hDF00;
        select = 1;
        r_w_n = 0;
        d_in = byte_to_send;
        
        // Hold for one clock cycle
        @(posedge clk);
        
        // Clear signals
        select = 0;
        r_w_n = 1;
        d_in = 8'h00;
    end
endtask

// Task to wait for transmission to complete
task wait_for_idle;
    begin
        busy = 1;
        
        while (busy) begin
            @(posedge clk);
            // Read status register
            a = 16'hDF01;
            select = 1;
            r_w_n = 1;
            @(posedge clk);
            busy = ~d_out[4];  // Bit 4 is ~tx_busy
        end
        $display("Time=%0t Idle!", $time);
        // Clear signals
        select = 0;
        r_w_n = 1;
    end
endtask

// Monitor the TX pin
always @(tx_p) begin
    if (last_edge != 0) begin
        bit_time = $time - last_edge;
        $display("Time=%0t tx_p=%b bit_time=%0t ns", $time, tx_p, bit_time);
    end else begin
        $display("Time=%0t tx_p=%b First edge", $time, tx_p);
    end
    last_edge = $time;
end

// Task to wait for received data
task wait_for_data;
    reg data_available;
    begin
        data_available = 0;
        
        while (!data_available) begin
            @(posedge clk);
            // Read status register
            a = 16'hDF01;
            select = 1;
            r_w_n = 1;
            @(posedge clk);
            data_available = d_out[3];  // Bit 3 is receiver_full
        end
        
        // Clear signals
        select = 0;
        r_w_n = 1;
    end
endtask

// Task to receive a byte
task receive_byte;
    begin
        // Read from RX_DATA_REG (0xDF00)
        @(posedge clk);
        a = 16'hDF00;
        select = 1;
        r_w_n = 1;
        
        @(posedge clk);
        @(posedge clk);
        $display("Time=%0t received=%H", $time, d_out);
        // Clear signals
        select = 0;
        r_w_n = 1;
    end
endtask

endmodule