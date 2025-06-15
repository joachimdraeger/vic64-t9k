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
; Macros and utility functions
; -----------------------------------------------------------------------------

; sets the accumulator to arg1 if accumulator is zero, otherwise to arg2
.macro SET_ACC_EQ arg1, arg2
        .local @done
        .local @not_zero
        ; Check if accumulator is zero
        cmp #0
        bne @not_zero
        
        ; If accumulator is zero, set it to arg1
        lda arg1
        jmp @done
    @not_zero:
        ; If accumulator is not zero, set it to arg2
        lda arg2
    @done:
.endmacro

.macro copy16 src, dst
        lda src         ; Load low byte
        sta dst         ; Store low byte
        lda src+1       ; Load high byte  
        sta dst+1       ; Store high byte
.endmacro

.macro add16_av addr, value
        clc             ; clear carry before addition
        lda addr        ; load low byte
        adc #<value     ; add low byte of value
        sta addr        ; store low byte result
        lda addr+1      ; load high byte
        adc #>value     ; add high byte of value
        sta addr+1      ; store high byte result
.endmacro

.macro ADD16_ADDR_ACC addr
        clc      
        adc addr     ; add low byte of value
        sta addr        ; store low byte result
        lda addr+1      ; load high byte
        adc #$00
        sta addr+1      ; store high byte result
.endmacro

.macro cmp16_aa addr1, addr2
    .local @done
        lda addr1       ; load low byte
        cmp addr2       ; compare low byte
        bne @done       ; if not equal, return
        lda addr1+1     ; load high byte
        cmp addr2+1     ; compare high byte
    @done:
.endmacro 

.macro inc16 addr
    .local @done
        inc addr        ; Increment low byte
        bne @done      ; If no zf, we're done
        inc addr+1     ; Otherwise increment high byte
    @done:
.endmacro

.macro PUSH16 addr
        lda addr
        pha
        lda addr+1
        pha
.endmacro

.macro POP16 addr
        pla
        sta addr+1
        pla
        sta addr
.endmacro

.code

.proc upper_case
        cmp #'a'
        bcc @done
        cmp #'z'+1
        bcs @done
        sbc #31
    @done:
        rts
.endproc

.proc parse_hex_nibble
        jsr upper_case
        cmp #'0'
        bcc @error       ; < '0' is error
        cmp #'F'+1
        bcs @error       ; > 'F' is error
        cmp #'9'+1
        bcc @decimal     ; 0-9
        cmp #'A'
        bcc @error       ; Between '9' and 'A' is error
        
        sec             ; Convert A-F
        sbc #'A'-10
        bcc @error
        clc             ; Success
        rts

@decimal:
        sec
        sbc #'0'        ; Convert 0-9
        clc             ; Success
        rts

@error:
        sec             ; Error
        rts
.endproc