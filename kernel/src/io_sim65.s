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
; IO functions for simulation using sim65 (cc65 toolchain)
; Uses the cc65 library for io instead of the UART/Screen functions.
; -----------------------------------------------------------------------------


.import _printf, _puts, _putchar, _getchar
.import pushax, pusha0


.segment "RODATA"
format_leds: .byte "Leds: $%02X", $0A, $00
format_tx: .byte "TX: $%02X", $0A, $00
sleep_msg: .byte "<sleep>", $00

.code

; Input: A register contains value to print
.proc leds
        pha                     ; Save value
        
        lda     #<format_leds
        ldx     #>format_leds
        jsr     pushax

        pla                     ; Restore value
        jsr     pusha0

        ldy     #4
        jsr     _printf
        rts
.endproc

.proc sleep
        lda     #<sleep_msg
        ldx     #>sleep_msg
        jsr     pushax
        jsr     _puts
        rts
.endproc

.import _putchar      ; Import C library putchar() function 
.import pushax        ; Helper function to pass parameters

.proc uart_tx
        jsr pusha0   ; Push byte in A as int parameter

        ; Call putchar
        ldy #2       ; Stack space needed (2 bytes for int parameter)
        jsr _putchar

        rts
.endproc

.proc uart_rx
        jsr _getchar
        rts
.endproc


.proc read_line
        ; Initialize buffer pointer
        lda #0
        sta index
   @loop:
        jsr uart_rx      ; Get character
        
        ; Check if it's a carriage return
        cmp #$0A
        beq @end
        
        ; Store character in buffer
        ldx index
        cpx #80          ; Check if buffer is full
        beq @loop    ; If full, ignore character
        
        sta buffer,x     ; Store in buffer
        ;jsr uart_tx      ; Echo character
        
        ; Increment buffer pointer
        inc index
        jmp @loop
@end:
        ; Add null terminator
        ldx index
        lda #0
        sta buffer,x
        rts
.endproc