// VIC64-T9K
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

module tmds_differential (
    input  wire [2:0] tmds,         // Single-ended TMDS data channels
    input  wire       tmds_clock,    // Single-ended TMDS clock
    output wire [2:0] hdmi_tx_p,    // Three HDMI channels differential positive
    output wire [2:0] hdmi_tx_n,    // Three HDMI channels differential negative
    output wire       hdmi_tx_clk_p, // HDMI clock differential positive
    output wire       hdmi_tx_clk_n  // HDMI clock differential negative
);

    // inspired by https://github.com/vossstef/tang_nano_9k_6502/blob/9554eedcb23578a59fe550fc90855f47f3b96027/src/dvi.v#L128

    // TMDS Buffered Differential Output for data channels
    ELVDS_OBUF OBUFDS_red   (.I(tmds[2]),     .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    ELVDS_OBUF OBUFDS_green (.I(tmds[1]),     .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    ELVDS_OBUF OBUFDS_blue  (.I(tmds[0]),     .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    
    // TMDS Buffered Differential Output for clock
    ELVDS_OBUF OBUFDS_clock (.I(tmds_clock), .O(hdmi_tx_clk_p), .OB(hdmi_tx_clk_n));

endmodule