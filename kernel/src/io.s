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
; IO functions
;   - LED control
;   - UART control
;   - Delay loop
; -----------------------------------------------------------------------------

LEDS_OUTPUT = $DEFF
UART_DATA = $DE00
UART_STATUS = $DE01

.code

.proc leds
        sta LEDS_OUTPUT
        rts
.endproc

.proc sleep
Start:
        lda     #$03            ; Outer loop (3 iterations)
        sta     zp_tmp1
; Outer loop takes 330ms https://stackoverflow.com/questions/78396432/how-do-i-make-a-timer-in-assembly-6502
OuterLoop:
        ldx     #$00            ; Middle loop (256 iterations)
MiddleLoop:
        ldy     #$00            ; Inner loop (256 iterations)
InnerLoop:
        dey          
        bne     InnerLoop
        dex        
        bne     MiddleLoop
        dec     zp_tmp1
        bne     OuterLoop
        rts
.endproc

.proc uart_tx
        pha                     ; Save A since we'll be checking status
@wait:
        lda     UART_STATUS     ; Load status register
        pha
        lsr
        eor     #$FF
        jsr     leds
        pla


        and     #%00010000      ; Mask bit 4 => ZF when not empty, need to loop more
        beq     @wait           ; If the zero flag is set => 
        pla                     ; Restore the byte to send
        sta     UART_DATA       ; Transmit the byte
        ldy screen_out
        beq @skip
        jsr screen_print_char
    @skip:
        rts
.endproc

.proc uart_rx
    @wait:
        lda     UART_STATUS     ; Load status register
        pha
        lsr
        ora     #%00010000     
        eor     #$FF
        jsr     leds
        pla

        and     #%00001000      ; Mask bit 3. ZF when no data received
        bne     @continue           ; ZF clear, keep waiting
        cpy     #0
        beq     @wait
        jsr     screen_flash_cursor
        jmp     @wait
    @continue:
        lda     UART_DATA       ; Read the received byte
        rts
.endproc

.proc read_line
        ldy echo
        ldx #0
   @loop:
        jsr uart_rx      ; Get character
        ; Check if it's a carriage return
        cmp #$0D
        beq @end
        cmp #$0A
        beq @end
        
        cpx #80          ; Check if buffer is full
        beq @loop    ; If full, ignore character
        
        sta buffer,x     ; Store in buffer
        inx
        cpy #0
        beq @loop

        jsr uart_tx      ; Echo character
        ldy #1 ; keep echo on
        jmp @loop

    @end:
        ; Add null terminator
        lda #0
        sta buffer,x
        rts
.endproc