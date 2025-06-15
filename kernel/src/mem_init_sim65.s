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
; Alternative screen addresses for simulation. 
; Definition of zero page variables in the .zeropage segment, 
; avoids fixed zero page addresses which could interfere with the cc65 library.
; -----------------------------------------------------------------------------

SCREEN_START = $C400
SCREEN_SIZE = $03E8

COLOR_RAM_START = $C800
COLOR_RAM_SIZE = $03E8

.zeropage
   
    CURRENT_SCREEN_LINE: .res 2
    CURRENT_COLOR_LINE: .res 2

    CURRENT_SCREEN_SCROLL_LINE: .res 2
    CURRENT_COLOR_SCROLL_LINE: .res 2

    CURSOR_FLASH_PHASE: .res 1
    CURSOR_FLASH_COUNTER: .res 1
    CURSOR_COLUMN: .res 1
    CURSOR_ROW: .res 1

    SCROLL_TEMP: .res 1

.segment "BSS"  
    CURRENT_COLOR: .res 1

