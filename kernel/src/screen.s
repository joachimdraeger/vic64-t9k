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
; Screen functions
;   - Initialises the VIC-II registers and clears the screen
;   - Prints greeting
;   - Prints characters to the screen
;   - Scrolls the screen up
;   - Flashes the cursor
;   - supports color
; -----------------------------------------------------------------------------

FLASH_COUNTER_LOOPS = 28

.segment "RODATA"
greeting:
    .byte 13,"    **** vic64-t9k monitor v0.1 ****", 13
    .byte 13, "  64k ram system 43008 code bytes free", 13
    .byte 13,"ready.", 13, 0

.segment "BSS"
    cursor_flash_counter_secondary: .res 1
.code


; TODO support overflowing the line
.proc screen_print_char
        cmp #$0A
        beq @return
        cmp #$0D
        bne @skip_nl

        ; new line, first clear cursor
        ldy CURSOR_COLUMN
        lda #$20        
        sta (CURRENT_SCREEN_LINE),y
        ldy #0
        sty CURSOR_COLUMN
        
        ; update cursor row and check if we need to scroll
        lda CURSOR_ROW
        cmp #24
        bcs @scroll_up

        ; advance to next line
        tay
        iny
        sty CURSOR_ROW
        add16_av CURRENT_SCREEN_LINE, 40
        add16_av CURRENT_COLOR_LINE, 40

    @return:    
        rts

    @scroll_up:
        jsr screen_scroll_up
        lda #24
        sta CURSOR_ROW
        rts

    @skip_nl:
        cmp #$40
        bcc @skip_shift
        and #$1F
    @skip_shift:
        ldy CURSOR_COLUMN        
        sta (CURRENT_SCREEN_LINE),y
        lda CURRENT_COLOR
        sta (CURRENT_COLOR_LINE),y
        iny
        sty CURSOR_COLUMN
        rts
.endproc

.proc screen_flash_cursor
        inc     CURSOR_FLASH_COUNTER
        beq     @secondary
        rts
    @secondary:
        dec     cursor_flash_counter_secondary
        beq     @toggle
        rts
    @toggle:
        lda     CURSOR_FLASH_PHASE
        beq     @clear
        lda     #$00
        sta     CURSOR_FLASH_PHASE
        lda     #$A0
        jmp     @write_cursor
    @clear:
        lda     #$01
        sta     CURSOR_FLASH_PHASE
        lda     #$20
    @write_cursor:
        ldy     CURSOR_COLUMN
        sta     (CURRENT_SCREEN_LINE),y
        ldy     #1
        lda     #FLASH_COUNTER_LOOPS
        sta     cursor_flash_counter_secondary
        rts
.endproc

.proc screen_print_greeting
        ldy #0
        ldx #0
    @loop:
        lda greeting,x
        beq @done
        cmp #$0D
        bne @skip_nl
        add16_av CURRENT_SCREEN_LINE, 40
        add16_av CURRENT_COLOR_LINE, 40
        ldy #0
        inx
        jmp @loop
    @skip_nl:
        cmp #$40
        bcc @skip_shift
        and #$1F
    @skip_shift:
        sta (CURRENT_SCREEN_LINE),y
        lda CURRENT_COLOR
        sta (CURRENT_COLOR_LINE),y
        iny
        inx
        bne @loop ; maximum 256 characters
    @done:
        lda #6
        sta CURSOR_ROW
        rts
.endproc

.proc screen_scroll_up
        txa ; do not assume x is free
        pha 

        lda #<SCREEN_START
        sta CURRENT_SCREEN_SCROLL_LINE
        lda #>SCREEN_START
        sta CURRENT_SCREEN_SCROLL_LINE+1

        lda #<COLOR_RAM_START
        sta CURRENT_COLOR_SCROLL_LINE
        lda #>COLOR_RAM_START
        sta CURRENT_COLOR_SCROLL_LINE+1

        ldx #24

    @loop:
        ldy #40
        clc
    @line_loop:
        dey
        sty SCROLL_TEMP
        
        tya
        adc #40
        tay
        
        lda (CURRENT_SCREEN_SCROLL_LINE),y
        ldy SCROLL_TEMP
        sta (CURRENT_SCREEN_SCROLL_LINE),y

        tya
        adc #40
        tay
        
        lda (CURRENT_COLOR_SCROLL_LINE),y
        ldy SCROLL_TEMP
        sta (CURRENT_COLOR_SCROLL_LINE),y

        tya ; just to set z flag
        bne @line_loop
        add16_av CURRENT_SCREEN_SCROLL_LINE, 40
        add16_av CURRENT_COLOR_SCROLL_LINE, 40
        dex
        bne @loop

        ; clear last line
        ldy #40
        lda #$20
    @clear_loop1:
        dey
        sta (CURRENT_SCREEN_SCROLL_LINE),y
        bne @clear_loop1

        ; clear last color line
        ldy #40
        lda CURRENT_COLOR
    @clear_loop2:
        dey
        sta (CURRENT_COLOR_SCROLL_LINE),y
        bne @clear_loop2

        pla
        tax
        rts
.endproc

.proc screen_clear

        ; clear screen
        lda #<SCREEN_START
        sta CURRENT_SCREEN_LINE
        lda #(>SCREEN_START + >SCREEN_SIZE)
        sta CURRENT_SCREEN_LINE+1
        ldx #(>SCREEN_SIZE + 1)
        ldy #<SCREEN_SIZE
        lda #$20
    @loop1:
        dey
        sta (CURRENT_SCREEN_LINE),y
        bne @loop1
        DEC CURRENT_SCREEN_LINE+1
        dex
        bne @loop1

        ; clear color ram
        lda #<COLOR_RAM_START
        sta CURRENT_COLOR_LINE
        lda #(>COLOR_RAM_START + >COLOR_RAM_SIZE)
        sta CURRENT_COLOR_LINE+1
        ldx #(>COLOR_RAM_SIZE + 1)
        ldy #<COLOR_RAM_SIZE
        lda CURRENT_COLOR
    @loop2:
        dey
        sta (CURRENT_COLOR_LINE),y
        bne @loop2
        DEC CURRENT_COLOR_LINE+1
        dex
        bne @loop2

        ; reset cursor

        lda #<SCREEN_START
        sta CURRENT_SCREEN_LINE
        lda #>SCREEN_START
        sta CURRENT_SCREEN_LINE+1

        lda #<COLOR_RAM_START
        sta CURRENT_COLOR_LINE
        lda #>COLOR_RAM_START
        sta CURRENT_COLOR_LINE+1

        lda #0

        sta CURSOR_FLASH_COUNTER
        sta CURSOR_FLASH_PHASE
        sta CURSOR_COLUMN
        sta CURSOR_ROW
        lda #FLASH_COUNTER_LOOPS
        sta cursor_flash_counter_secondary
        rts
.endproc

.proc screen_init
        ldx #40
        lda #0
    @loop:
        dex
        sta VICII_BASE,x
        bne @loop

        lda #$1B
        sta VICII_CONTROL_REGISTER1
        lda #$C8
        sta VICII_CONTROL_REGISTER2
        lda #$15
        sta VICII_MEMORY_CONTROL
        lda #$0E
        sta VICII_BORDER_COLOR
        lda #$06
        sta VICII_BACKGROUND_COLOR

        lda #$0E
        sta CURRENT_COLOR

        rts
.endproc

