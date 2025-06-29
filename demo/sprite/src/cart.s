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


.include "main.s"

; C64 Cartridge vectors and signature
; This creates the cartridge structure for autostart

.segment "VECTORS"

; Cartridge vectors at $8000
.addr coldstart         ; $8000: Cold start vector (low byte, high byte)
.addr warmstart         ; $8002: Warm start vector (low byte, high byte)

; CBM80 signature at $8004 - required for cartridge detection
.byte $C3, $C2, $CD, $38, $30   ; "CBM80" in reverse PETSCII

.segment "STARTUP"

; Cold start routine - called after reset or power-on
coldstart:
    sei                 ; Disable interrupts
    jsr $fda3          ; Initialize CIA chips
    jsr $fd50          ; Initialize memory
    jsr $fd15          ; Initialize I/O vectors
    jsr $ff5b          ; Initialize VIC and screen editor
    cli                 ; Re-enable interrupts
    jmp _main           ; Jump to main program

; Warm start routine - called after reset
warmstart:
    jmp _main           ; Jump to main program

