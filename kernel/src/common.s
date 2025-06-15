; VIC64-T9K - C64 VIC-II video chip on the Tang Nano 9K
; https://github.com/joachimdraeger/vic64-t9k
; Copyright (C) 2025  Joachim Draege;

; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version;

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details;

; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>

; -----------------------------------------------------------------------------
; Constants and global variables
; -----------------------------------------------------------------------------

VICII_BASE = $D000
VICII_CONTROL_REGISTER1 = $D011
VICII_CONTROL_REGISTER2 = $D016
VICII_MEMORY_CONTROL = $D018
VICII_BORDER_COLOR = $D020
VICII_BACKGROUND_COLOR = $D021

.zeropage
    zp_address: .res 2
    zp_tmp1: .res 1

.segment "BSS"  
    screen_out: .res 1


