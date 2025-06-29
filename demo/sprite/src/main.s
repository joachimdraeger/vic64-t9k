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



.export _main

SPRITE_0 = $3000

.segment "BSS"

x_counter:  .byte 0 
y_counter:  .byte 0
delay_counter:  .byte 0

.segment "CODE"


; main movement routine - call this each frame
move_sprite:
        ; get x position from sine table
        ldx x_counter
        lda sine_tab,x
        sta $d000           ; sprite 0 x position
        
        ; get y position from sine table
        ldx y_counter
        lda sine_tab,x
        sta $d001           ; sprite 0 y position
        
        ; update x counter (frequency = 2)
        lda x_counter
        clc
        adc #2
        and #127            ; wrap at 128
        sta x_counter
        
        ; update y counter (frequency = 3)
        lda y_counter
        clc
        adc #3
        and #127            ; wrap at 128
        sta y_counter
        
        rts

delay:
        ldx delay_counter
        lda sine_tab,x          ; use sine table for delay variation
        lsr                     ; divide by 2 to keep reasonable range
        tay
        
        ldx #$ff
delay_loop:
        dex
        bne delay_loop
        dey
        bne delay_loop
        
        ; update delay counter
        inc delay_counter
        lda delay_counter
        and #127
        sta delay_counter
        
        rts




_main:
        jmp start
start:
        lda #$a1
        sta $0400

; copy sprite to $3000
        ldx #0
copy_sprite:
        lda ufo_sprite,x
        sta SPRITE_0,x
        inx
        cpx #126
        bne copy_sprite

; Sprite settings
        lda #%00000001
        sta $d015          ; Enable sprite 0

        lda #%00000001
        sta $d01c          ; Enable multicolor for sprite 0

        lda #$00
        sta $d025          
        lda #$0e
        sta $d026        
        lda #$07
        sta $d027          

        lda #(SPRITE_0 / 64)  ; = 192
        sta $07f8          ; Sprite 0 pointer

; Set sprite 0 position
        lda #100
        sta $d000          ; X position
        lda #100
        sta $d001          ; Y position

; start sprite animation
        lda #0
        sta x_counter
        sta y_counter

loop:
        jsr move_sprite
        jsr delay
        jmp loop


.segment "RODATA"

ufo_sprite:
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$30,$00,$00
    .byte $fc,$00,$0f,$ff,$c0,$0d,$dd,$c0
    .byte $3f,$ff,$f0,$3f,$57,$f0,$75,$55
    .byte $74,$57,$ff,$54,$5d,$55,$d4,$05
    .byte $55,$40,$05,$65,$40,$01,$a9,$00
    .byte $00,$20,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$87

sine_tab:   
    .byte 128,132,136,139,143,147,151,154
    .byte 158,161,165,168,171,174,177,180
    .byte 183,186,188,191,193,195,197,199
    .byte 200,201,203,204,205,205,206,206
    .byte 206,206,206,205,205,204,203,201
    .byte 200,199,197,195,193,191,188,186
    .byte 183,180,177,174,171,168,165,161
    .byte 158,154,151,147,143,139,136,132
    .byte 128,124,120,117,113,109,105,102
    .byte 98,95,91,88,85,82,79,76
    .byte 73,70,68,65,63,61,59,57
    .byte 56,55,53,52,51,51,50,50
    .byte 50,50,50,51,51,52,53,55
    .byte 56,57,59,61,63,65,68,70
    .byte 73,76,79,82,85,88,91,95
    .byte 98,102,105,109,113,117,120,124