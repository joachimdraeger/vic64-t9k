// video.v
// Original code from https://github.com/hdl-util/hdmi
// Modified by https://github.com/vossstef/tang_nano_20k_c64
// Modified by Joachim Draeger, 2025-06-10 

module video (
        input	 clk,
        input    clk_pixel_x5,

        input	 vs_in,
        input	 hs_in,

        input [3:0]  r_in,
        input [3:0]  g_in,
        input [3:0]  b_in,

        output wire [2:0]  hdmi_tx_p,    // Three HDMI channels differential positive
        output wire [2:0]  hdmi_tx_n,    // Three HDMI channels differential negative
        output wire        hdmi_tx_clk_p, // HDMI clock differential positive
        output wire        hdmi_tx_clk_n  // HDMI clock differential negative
);
   
localparam [1:0] system_scanlines = 2'b00; // 00-none 01-25% 10-50% 11-75%
localparam system_wide_screen = 1'b0;
localparam ntscmode = 1'b0;

// audio_div  <= to_unsigned(342,9) when ntscMode = '1' else to_unsigned(327,9);
localparam audio_div = 9'd327;

/* -------------------- HDMI video and audio -------------------- */

// generate 48khz audio clock
reg clk_audio = 1'b0;
reg [8:0] aclk_cnt = 9'd0;

always @(posedge clk) begin
    // divisor = pixel clock / 48000 / 2 - 1
    if(aclk_cnt < audio_div)
        aclk_cnt <= aclk_cnt + 9'd1;
    else begin
        aclk_cnt <= 9'd0;
        clk_audio <= ~clk_audio;
    end
end

wire vreset;
wire [1:0] vmode;

video_analyzer video_analyzer (
   .clk(clk),
   .vs(vs_in),
   .hs(hs_in),
   .de(1'b1),
   .ntscmode(ntscmode),
   .mode(vmode),
   .vreset(vreset)
);  

// wire sd_hs_n, sd_vs_n; 
wire [5:0] sd_r;
wire [5:0] sd_g;
wire [5:0] sd_b;
  
scandoubler #(11) scandoubler (
        // system interface
        .clk_sys(clk),
        .bypass(1'b0),
        .ce_divider(1'b1),
        .pixel_ena(),

        // scanlines (00-none 01-25% 10-50% 11-75%)
        .scanlines(system_scanlines),

        // shifter video interface
        .hs_in(hs_in),
        .vs_in(vs_in),
        .r_in( r_in ),
        .g_in( g_in ),
        .b_in( b_in ),

        // output interface
        .hs_out(), // .hs_out(sd_hs_n),
        .vs_out(), // .vs_out(sd_vs_n),
        .r_out(sd_r),
        .g_out(sd_g),
        .b_out(sd_b)
);



wire [2:0] tmds;
wire tmds_clock;

hdmi #(
   .AUDIO_RATE(48000), 
   .AUDIO_BIT_WIDTH(16),
   .VENDOR_NAME( { "MiSTle", 16'd0} ),
   .PRODUCT_DESCRIPTION( {"C64", 64'd0} )
) hdmi(
  .clk_pixel_x5(clk_pixel_x5),
  .clk_pixel(clk),
  .clk_audio(clk_audio),
  .audio_sample_word( { 16'b0, 16'b0 } ),
  .tmds(tmds),
  .tmds_clock(tmds_clock),

  // video input
  .stmode(vmode),    // current video mode PAL/NTSC/MONO
  .wide(system_wide_screen),       // adopt to wide screen video
  .reset(vreset),    // signal to synchronize HDMI
  // Atari STE outputs 4 bits per color. Scandoubler outputs 6 bits (to be
  // able to implement dark scanlines) and HDMI expects 8 bits per color
  .rgb( { sd_r, 2'b00, sd_g, 2'b00, sd_b, 2'b00 } )
);

// Instantiate the differential output driver
tmds_differential diff_output (
    .tmds(tmds),
    .tmds_clock(tmds_clock),
    .hdmi_tx_p(hdmi_tx_p),
    .hdmi_tx_n(hdmi_tx_n),
    .hdmi_tx_clk_p(hdmi_tx_clk_p),
    .hdmi_tx_clk_n(hdmi_tx_clk_n)
);

endmodule
