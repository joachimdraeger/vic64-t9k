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
; Constants address and zero page locations. Defines the reset vector.
; -----------------------------------------------------------------------------

SCREEN_START = $0400
SCREEN_SIZE = $03E8

COLOR_RAM_START = $D800
COLOR_RAM_SIZE = $03E8

CURRENT_SCREEN_SCROLL_LINE = $AC
CURRENT_COLOR_SCROLL_LINE = $AE

CURSOR_FLASH_COUNTER = $CD
CURSOR_FLASH_PHASE = $CF
CURRENT_SCREEN_LINE = $D1
CURSOR_COLUMN = $D3
CURSOR_ROW = $D6

SCROLL_TEMP = $F2
CURRENT_COLOR_LINE = $F3
CURRENT_COLOR = $0286


; $00CE Screen code of character under cursor.

; $0287 Color of character under cursor.

.segment "VECTORS"
    
    ; Define the Reset vector at $FFFC and $FFFD
    .word $F800 ; reset vector

    ; Define the IRQ vector at $FFFE and $FFFF
    .word $0000 ; unused
