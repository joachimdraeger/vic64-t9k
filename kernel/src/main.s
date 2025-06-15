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
; Main file for the VIC64-T9K memory monitor. Includes the main loop.
; -----------------------------------------------------------------------------

.include "common.s"
.include "util.s"
.include "screen.s"

.macro LED_PATTERN led_pattern
        lda #led_pattern
        jsr leds
        jsr sleep
.endmac

.macro TX_BYTE byte
        lda #byte
        jsr uart_tx
.endmac

.macro output_hex_byte_at addr
        ldy #0
        lda (addr),y
        jsr output_hex_byte
.endmacro

.macro output_hex_address addr
        lda addr+1
        jsr output_hex_byte
        lda addr
        jsr output_hex_byte
.endmacro

.macpack longbranch
.macpack generic  


.segment "BSS"
    buffer: .res 81           ; 80 chars + null terminator
    index: .res 1           ; Current position in buffer
    address_to: .res 2
    echo: .res 1 

.segment "STARTUP"
.export _main
_main:
        jsr screen_init
        jsr screen_clear
        jsr screen_print_greeting       
        lda #0
        sta zp_address
        sta zp_address+1
        lda #1
        sta echo
        sta screen_out

; ----- Main loop -----

main_loop:
        TX_BYTE $0D
        TX_BYTE $0A
        TX_BYTE '>'      ; Show prompt

        jsr read_line

; parse command
        ldx #0
        jsr skip_whitespaces
        jsr upper_case

        cmp #'R'
        jeq read_memory_cmd
        cmp #'.'
        jeq read_memory_cmd_continue
        cmp #'W'
        jeq write_memory_cmd
        cmp #':'
        jeq write_continue_cmd
        cmp #'J'
        jeq jump_cmd
        cmp #'E'
        jeq echo_cmd
        cmp #'S'
        jeq screen_cmd
        
error_prompt:
        TX_BYTE '?'
        jmp main_loop

screen_cmd:
        inx
        jsr skip_whitespaces
        lda buffer,x
        cmp #0
        beq @display

        cmp #'0'
        bcc error_prompt
        cmp #'2'
        bcs error_prompt

        sub #'0'
        sta screen_out
    @display:
        TX_BYTE $0D
        TX_BYTE $0A
        TX_BYTE 'S'
        TX_BYTE ':'
        lda screen_out
        jsr output_hex_byte
        jmp main_loop

echo_cmd:
        inx
        jsr skip_whitespaces
        lda buffer,x
        cmp #0
        beq @display

        cmp #'0'
        bcc error_prompt
        cmp #'2'
        bcs error_prompt

        sub #'0'
        sta echo
    @display:
        TX_BYTE $0D
        TX_BYTE $0A
        TX_BYTE 'E'
        TX_BYTE ':'
        lda echo
        jsr output_hex_byte
        jmp main_loop

jump_cmd:
        inx
        jsr skip_whitespaces
        jsr parse_address
        bcs error_prompt
        jmp (zp_address)

jmp_error_prompt:
        jmp error_prompt

write_continue_cmd:
        inx
        jmp write_loop

write_memory_cmd:
        inx
        jsr skip_whitespaces
        jsr parse_address
        bcs jmp_error_prompt

write_loop:
        jsr skip_whitespaces
        cmp #0
        beq @to_main_loop
        jsr parse_hex_byte
        bcs jmp_error_prompt

        ldy #0
        sta (zp_address),y
        inc zp_address
        bne write_loop
        inc zp_address+1
        jmp write_loop
    @to_main_loop:
        jmp main_loop

read_memory_cmd:
        inx
        jsr skip_whitespaces
        jsr parse_address
        bcs jmp_error_prompt

read_memory_cmd_continue:
        copy16 zp_address, address_to
        add16_av address_to, 1

        jsr skip_whitespaces
        cmp #'.'
        bne read_memory_output

        lda screen_out
        SET_ACC_EQ #15, #7
        ADD16_ADDR_ACC address_to

        inx
        jsr skip_whitespaces
        cmp #'.'
        bne read_memory_output

        lda screen_out
        SET_ACC_EQ #240, #120
        ADD16_ADDR_ACC address_to

read_memory_output:
        TX_BYTE $0D
        TX_BYTE $0A
        output_hex_address zp_address
        TX_BYTE ':'
        lda screen_out
        SET_ACC_EQ #17, #9
        sta index

    @loop:
        dec index
        bne @loop_continue
        jmp read_memory_output

    @loop_continue:
        TX_BYTE ' '
        output_hex_byte_at zp_address

        inc16 zp_address
        cmp16_aa zp_address, address_to
        bne @loop

        jmp main_loop
; ----- End of main loop -----

; ----- Subroutines -----

.proc skip_whitespaces
        lda buffer,x
        cmp #' '
        bne @done
        inx
        jmp skip_whitespaces
    @done:
        rts
.endproc

; Parse 4 hex digits into 16-bit address
.proc parse_address
        jsr parse_hex_address
        bcs @error
        sta zp_address
        sty zp_address+1    
        clc
        rts                 
    @error:
        sec                 
        rts
.endproc

; Output byte in A as two hex digits
.proc output_hex_byte
        pha             ; Save byte
        lsr
        lsr
        lsr
        lsr             ; High nibble
        jsr output_hex_digit
        pla             ; Restore byte
        and #$0F        ; Low nibble
        jsr output_hex_digit
        rts
.endproc

; Output nibble in A as hex digit
.proc output_hex_digit
        cmp #10
        bcc @decimal
        adc #6          ; Add offset for A-F
    @decimal:
        adc #'0'        ; Convert to ASCII
        jsr uart_tx
        rts
.endproc

; Parse 4 hex digits into 16-bit address: Y:high, A:low
parse_hex_address:
        jsr parse_hex_byte     ; Get high byte
        bcs @error              ; Return if error
        tay                    ; Store high byte in Y
        jsr parse_hex_byte     ; Get low byte in A
        bcs @error              ; Return if error
        clc
        rts                    ; Return with Y=high, A=low
    @error:
        sec                    ; Set carry to indicate error
        rts

; Starts at buffer,x and parses 2 hex digits, returning the byte in A
.proc parse_hex_byte
        ; Parse high nibble
        lda buffer,x
        jsr parse_hex_nibble
        bcs @error          ; Exit if error
        inx
        asl                 ; Shift to high nibble position
        asl
        asl
        asl
        sta zp_tmp1
        ; Get next character and parse low nibble

        lda buffer,x
        jsr parse_hex_nibble
        bcs @error     ; Exit if error
        inx
        ; Combine nibbles
        ora zp_tmp1
        clc                ; Signal success
        rts
    @error:
        sec                ; Signal error
        rts
.endproc