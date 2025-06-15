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
// Instantiates and wires all modules
// - should not contain any logic
// - input/output ports to the fpga are defined here (see vic64-t9k.cst)
// - bus logic is in main/bus.v
// -----------------------------------------------------------------------------

module top(
    input clk27,
    input ext_resetn,
    output [5:0] leds_out,
    output tx_p,
    input rx_p,

    output [1:0] O_psram_ck,       // Magic ports for PSRAM to be inferred
    output [1:0] O_psram_ck_n,
    inout [1:0] IO_psram_rwds,
    inout [15:0] IO_psram_dq,
    output [1:0] O_psram_reset_n,
    output [1:0] O_psram_cs_n,

    // HDMI outputs
    output [2:0] hdmi_tx_p,
    output [2:0] hdmi_tx_n,
    output hdmi_tx_clk_p,
    output hdmi_tx_clk_n,
    
    // Flash interface
    output flash_clk,
    input flash_miso,
    output flash_mosi,
    output flash_cs
);



    wire clk64;     // 64MHz clock
    wire clk64p;    // 64MHz clock 90 deg shifted
    wire clk32;     // 32MHz clock
    wire clk157;    // 157.5MHz clock

    clocks clocks_inst (
        .clkin(clk27),
        .clk32(clk32), // 31.5 MHz
        .clk64(clk64), // 63 MHz
        .clk64p(clk64p), // 63 MHz 90 deg shifted
        .clk157(clk157) // 157.5 MHz
    );

    wire [4:0] io_leds;
    wire startup_resetn;
    wire sys_resetn;
    wire phi;
    wire bus_access_strobe_pre;
    wire bus_access_pre;
    wire bus_access_strobe;

    wire enableVic;
    wire enablePixel;

    wire [23:0] cpu_addr_out;
    wire [7:0] cpu_data_out;
    wire [7:0] cpu_data_in_latched;  // Latched data for CPU input
    wire [7:0] cpu_data_in_bus;      // Raw data from bus before latching
    wire cpu_r_wn;
    wire bus_r_wn;
    wire [15:0] bus_addr;
    wire io_en;
    
    wire psram_en;
    wire psram_busy;
    wire psram_error;
    
    // Core PSRAM access signals
    wire core_psram_r_strobe;
    wire core_psram_w_strobe;

    // Combined PSRAM signals (handled by bus.v)
    wire psram_r_strobe;
    wire psram_w_strobe;
    wire [21:0] psram_addr;
    wire [15:0] psram_d_in;
    wire [15:0] psram_d_out;

    wire color_ram_enabled;
    wire [9:0] color_ram_addr;
    wire [3:0] color_ram_d_out;

    wire uart_select;
    wire [7:0] uart_dout;
    
    // Flash io signals
    wire flash_io_select;
    wire [7:0] flash_io_d_out;
    wire [23:0] flash_addr_fio;
    wire flash_req_r_addr_fio;
    wire flash_req_r_next_fio;
    
    // flash controller signals
    wire [23:0] flash_addr;
    wire flash_req_r_addr;
    wire flash_req_r_next;
    wire flash_d_ready;
    wire [7:0] flash_d_out;

    // Flash DMA signals
    wire flash_dma_enabled;
    wire [23:0] flash_dma_flash_src_addr;
    wire [21:0] flash_dma_psram_dst_addr;
    wire [15:0] flash_dma_data_length;
    wire flash_dma_start;
    wire flash_dma_busy;


    wire psram_w_strobe_fdma;
    wire [21:0] psram_addr_fdma;
    wire [15:0] psram_d_in_fdma;
    wire [23:0] flash_addr_fdma;
    wire flash_req_r_addr_fdma;
    wire flash_req_r_next_fdma;

    // Video output signals
    wire vic_hsync;
    wire vic_vsync;
    wire [7:0] vic_r;
    wire [7:0] vic_g;
    wire [7:0] vic_b;
    wire vic_ba;  // Add VIC BA (Bus Available to CPU) signal
    wire vic_aec;  // Add VIC AEC (Address Enable Control) signal, 0 when VIC is accessing the address
    wire [7:0] vic_d_in;
    wire [15:0] vic_addr;
    wire vic_cs;
    wire [7:0] vic_d_out;

    // Instantiate the video output module
    video video_inst (
        .clk(clk32),
        .clk_pixel_x5(clk157),
        .vs_in(vic_vsync),
        .hs_in(vic_hsync),
        .r_in(vic_r[7:4]),    // Take the 4 MSBs for display
        .g_in(vic_g[7:4]),
        .b_in(vic_b[7:4]),
        .hdmi_tx_p(hdmi_tx_p),
        .hdmi_tx_n(hdmi_tx_n),
        .hdmi_tx_clk_p(hdmi_tx_clk_p),
        .hdmi_tx_clk_n(hdmi_tx_clk_n)
    );

    startup startup_inst (
        .clk32(clk32),
        .resn(ext_resetn),
        .ram_busy(psram_busy),
        .startup_resetn(startup_resetn),
        .leds_out(leds_out),
        .io_leds(io_leds),
        .ram_error(psram_error),

        .dma_flash_src_addr(flash_dma_flash_src_addr),
        .dma_psram_dst_addr(flash_dma_psram_dst_addr),
        .dma_data_length(flash_dma_data_length),
        .dma_start(flash_dma_start),
        .dma_busy(flash_dma_busy) 
    );

    bus bus_inst (
        .clk32(clk32),
        // CPU interface
        .cpu_addr_out(cpu_addr_out),
        .cpu_data_out(cpu_data_out),
        .cpu_data_in(cpu_data_in_bus),
        .cpu_r_wn(cpu_r_wn),

        // Bus interface
        .bus_r_wn(bus_r_wn),
        .bus_addr(bus_addr),
        .bus_access_strobe_pre(bus_access_strobe_pre),
        .bus_access_pre(bus_access_pre),
        .bus_access_strobe(bus_access_strobe),
        .io_en(io_en),

        // Video interface
        .vic_addr(vic_addr),
        .vic_d_in(vic_d_in),
        .vic_aec(vic_aec),
        .vic_cs(vic_cs),
        .vic_d_out(vic_d_out),

        // PSRAM interface
        .psram_en(psram_en),
        .psram_addr(psram_addr),
        .psram_d_in(psram_d_in),
        .psram_d_out(psram_d_out),
        .psram_w_strobe(psram_w_strobe),
        .psram_r_strobe(psram_r_strobe),

        .core_psram_r_strobe(core_psram_r_strobe),
        .core_psram_w_strobe(core_psram_w_strobe),

        // Color RAM interface
        .color_ram_enabled(color_ram_enabled),
        .color_ram_addr(color_ram_addr),
        .color_ram_d_out(color_ram_d_out),

        .uart_select(uart_select),
        .uart_dout(uart_dout),
        
        // Flash controller signals
        .flash_addr(flash_addr),
        .flash_req_r_addr(flash_req_r_addr),
        .flash_req_r_next(flash_req_r_next),
        
        // IO Flash signals
        .flash_addr_fio(flash_addr_fio),
        .flash_req_r_addr_fio(flash_req_r_addr_fio),
        .flash_req_r_next_fio(flash_req_r_next_fio),
        .flash_select(flash_io_select),
        .flash_dout(flash_io_d_out),
        
        // DMA Flash signals
        .flash_dma_enabled(flash_dma_enabled),

        .flash_addr_fdma(flash_addr_fdma),
        .flash_req_r_addr_fdma(flash_req_r_addr_fdma),
        .flash_req_r_next_fdma(flash_req_r_next_fdma),
        
        .psram_addr_fdma(psram_addr_fdma),
        .psram_d_in_fdma(psram_d_in_fdma),
        .psram_w_strobe_fdma(psram_w_strobe_fdma)
    );

    // Instantiate the core cycle logic
    core_cycle core (
        .clk32(clk32),
        .reset_n_in(startup_resetn),
        .resetn(sys_resetn),
        .phi(phi),
        .enableVic(enableVic),
        .enablePixel(enablePixel),
        .bus_access_strobe_pre(bus_access_strobe_pre),
        .bus_access_pre(bus_access_pre),
        .psram_en(psram_en),
        .r_wn(bus_r_wn),
        .psram_busy(psram_busy),
        .psram_r_strobe(core_psram_r_strobe),
        .psram_w_strobe(core_psram_w_strobe),
        .psram_ram_error(psram_error),
        .vic_aec(vic_aec),
        .cpu_data_in_bus(cpu_data_in_bus),
        .cpu_data_in_latched(cpu_data_in_latched)
    );

    // Instantiate the VIC-II video controller
    vic_top vic_top_inst (
        .clk32(clk32),
        .phi(phi),
        .reset(~sys_resetn),  // Converting active-low to active-high reset
        .enablePixel(enablePixel),
        .enableVic(enableVic),
        .hSync(vic_hsync),
        .vSync(vic_vsync),
        .r(vic_r),
        .g(vic_g),
        .b(vic_b),
        .vic_ba(vic_ba),  
        .vic_aec(vic_aec),
        .vic_di(vic_d_in),
        .vic_color_di(color_ram_d_out),
        .vic_addr(vic_addr),
        .vic_cs(vic_cs),
        .bus_addr(bus_addr),
        .cpu_data_out(cpu_data_out),
        .r_wn(bus_r_wn),
        .vic_do(vic_d_out)
    ); 

    t65 t65_inst (
        .mode(2'b00),
        .res_n(sys_resetn),
        .enable(1'b1),
        .clk(phi),
        .rdy(vic_ba),  // Connect VIC's BA signal to CPU's Rdy input
        .r_w_n(cpu_r_wn),
        .di(cpu_data_in_latched),  // Connect to the latched data
        .\do (cpu_data_out),
        .a(cpu_addr_out)
    );

    psram_wrapper psram_wrapper_inst (
        .clk32(clk32),
        .clk64(clk64),
        .clk64p(clk64p),
        // PSRAM can only be reset by external reset because it needs to be initialized by startup controller
        .resetn(ext_resetn),
        .read(psram_r_strobe),
        .write(psram_w_strobe),
        .byte_write(1'b1),
        .addr(psram_addr),
        .din(psram_d_in),
        .dout(psram_d_out),
        .busy(psram_busy),

        .O_psram_ck(O_psram_ck),
        .IO_psram_rwds(IO_psram_rwds),
        .IO_psram_dq(IO_psram_dq),
        .O_psram_cs_n(O_psram_cs_n)
    );

    color_ram color_ram_inst (
        .clk(clk32),
        .ad(color_ram_addr),
        .ce(color_ram_enabled),
        .wre(!bus_r_wn),
        .oce(1'b1),
        .din(cpu_data_out[3:0]),
        .dout(color_ram_d_out),
        .reset(~sys_resetn)
    );

    io_leds leds_inst (
        .clk(clk32),
        .bus_access_strobe(bus_access_strobe),
        .a(bus_addr),
        .ext_io_en(io_en),
        .r_w_n(bus_r_wn),
        .d_in(cpu_data_out),
        .leds(io_leds)
    );

    uart uart_inst (
        .clk(clk32),
        .bus_access_strobe(bus_access_strobe),
        .a(bus_addr),
        .select(uart_select),
        .r_w_n(bus_r_wn),
        .d_in(cpu_data_out),
        .d_out(uart_dout),
        .tx_p(tx_p),
        .rx_p(rx_p)
    );
    
    // Instantiate the flash controller
    flash_controller flash_ctrl (
        .clk(clk32),
        .reset(!ext_resetn),               
        .flash_addr(flash_addr),                // Address from flash_io
        .request_read_addr(flash_req_r_addr),
        .request_read_next(flash_req_r_next),
        .d_ready(flash_d_ready),
        .d_out(flash_d_out),
        .flash_clk(flash_clk),
        .flash_miso(flash_miso),
        .flash_mosi(flash_mosi),
        .flash_cs(flash_cs)
    );

    flash_io fio_inst (
        .clk(clk32),
        .bus_access_strobe(bus_access_strobe),
        .a(bus_addr),
        .select(flash_io_select),
        .r_w_n(bus_r_wn),
        .d_in(cpu_data_out),
        .d_out(flash_io_d_out),
        .flash_d_ready(flash_d_ready),
        .flash_d_out(flash_d_out),
        .flash_addr(flash_addr_fio),
        .flash_req_r_addr(flash_req_r_addr_fio),
        .flash_req_r_next(flash_req_r_next_fio)
    );

    flash_dma flash_dma_inst (
        .clk(clk32),

        .flash_dma_enabled(flash_dma_enabled),

        .flash_src_addr(flash_dma_flash_src_addr),
        .psram_dst_addr(flash_dma_psram_dst_addr),
        .data_length(flash_dma_data_length),
        .start(flash_dma_start),
        .busy(flash_dma_busy),

        // Flash controller interface
        .flash_addr(flash_addr_fdma),
        .flash_req_r_addr(flash_req_r_addr_fdma),
        .flash_req_r_next(flash_req_r_next_fdma),
        .flash_d_ready(flash_d_ready),
        .flash_d_out(flash_d_out),
        
        // PSRAM controller interface for DMA operations
        .psram_w_strobe(psram_w_strobe_fdma),
        .psram_addr(psram_addr_fdma),
        .psram_d_in(psram_d_in_fdma),
        .psram_busy(psram_busy)
    );

endmodule
