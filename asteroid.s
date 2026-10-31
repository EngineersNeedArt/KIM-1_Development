; ---------------------------------------------------------------------
; ASTEROID  -  from "The First Book of KIM"
; Steer a craft (left/right) through a scrolling asteroid field on the
; six-digit LED display.  Key 0 = left, key 3 = right.  On a collision
; the elapsed-time counter is shown (BCD).
;
; Reformatted for ca65.  Must be linked so that CODE starts at $0200,
; because the field scan relies on the pointer's low byte wrapping
; ($FF -> $00) and stopping at $0230 (see check routine).
; ---------------------------------------------------------------------

        .setcpu "6502"
        .include "kim.inc"

; ---- Zero page --------------------------------------------------------
bitpos          = $e0           ; current column bit ($20 down to $01)
column          = $e1           ; segment pattern being built for a digit
astptr          = $e2           ; 2 bytes: pointer into the asteroid belt
segmask         = $e4           ; 3 bytes: bottom, middle, top segment masks
craft           = $e7           ; craft position (one bit set)
shipflag        = $e8           ; $FF = ship lit, $00 = ship off (flasher)
passcnt         = $e9           ; display passes until the belt advances
score           = INH           ; 3 bytes BCD time counter ($F9-$FB, the
                                ; monitor display area shown by SCANDS)

SCAN_END        = $30           ; belt pointer low byte that ends a pass
PASSES          = $30           ; display passes (48) per belt step

        .segment "CODE"

; ---------------------------------------------------------------------
asteroid_start:
        lda #$00                ; clear the time counter
        sta score
        sta score+1
        sta score+2

        ldx #$06                ; copy init block to $E2-$E8
init_loop:
        lda init_data,x
        sta astptr,x
        dex
        bpl init_loop

main_loop:
        lda shipflag            ; toggle flasher flag
        eor #$ff
        sta shipflag

        ldx #$05                ; delay between flashes
flash_loop:
        jsr display             ; display and...
        jsr check               ; ...check for collision
        dex
        bne flash_loop

        jsr KEYIN               ; set directional regs
        jsr GETKEY              ; get keyboard entry
        cmp #KEY_NONE           ; valid key?
        bpl main_loop           ; no
        cmp #$00                ; key 0?
        beq go_left
        cmp #$03                ; key 3?
        beq go_right
        bne main_loop           ; not a steering key

go_left:
        asl craft               ; shift craft left
        lda #$40                ; off the left-hand edge?
        cmp craft
        bne main_loop           ; no
go_right:                       ; (falls through from go_left to undo the
        lsr craft               ;  shift when the craft left the edge)
        bne main_loop           ; still on the display
        sec                     ; off the right edge, wrap back to
        rol craft               ; the rightmost position
        bne main_loop           ; (always)

; ---------------------------------------------------------------------
; display - multiplex the six digits for one pass
; ---------------------------------------------------------------------
display:
        lda #$7f                ; port A: bit 7 input, rest output
        sta SADD                ; U2 port A direction
        lda #$09                ; first digit select
        sta SBD
        lda #$20                ; start at 6th bit
        sta bitpos
next_col:
        ldy #$02                ; three bytes per column
        lda #$00
        sta column
next_byte:
        lda (astptr),y          ; get belt byte
        and bitpos              ; is this column's bit set?
        beq no_bit
        lda column              ; yes: add that segment to the digit
        ora a:segmask,y         ; (absolute,Y - there is no zp,Y for ORA)
        sta column
no_bit:
        dey
        bpl next_byte

        lda column
        cpy shipflag            ; Y is $FF here: is the ship lit?
        bne show_digit          ; no
        ldy bitpos              ; is the craft in this column?
        cpy craft
        bne show_digit          ; no
        ora #$08                ; add in the ship (bottom segment)
show_digit:
        sta SAD                 ; light the digit

        lda #$30                ; digit-on delay
        sta T64_NOIRQ           ; U3 timer: /64, no IRQ
wait:
        lda TIMER_FLAG          ; timed out yet?
        beq wait                ; no

        lda #$00                ; blank the segments
        sta SAD
        inc SBD                 ; next digit (select steps by 2)
        inc SBD
        lsr bitpos              ; next column bit
        bne next_col            ; more columns
        rts

; ---------------------------------------------------------------------
; check - advance the belt every PASSES calls, test for collision
; ---------------------------------------------------------------------
check:
        dec passcnt             ; count passes
        bne more                ; not time to advance yet

        lda #PASSES             ; reset pass counter
        sta passcnt

        txa                     ; save X
        pha
        ldx #$fd                ; X = -3, indexes score through zp wrap
        sed                     ; BCD increment of the time counter
        sec                     ; (carry in = add one)
next_byte_bcd:
        lda score+3,x
        adc #$00
        sta score+3,x
        inx
        bne next_byte_bcd
        cld
        pla                     ; restore X
        tax

        inc astptr              ; step to next group of belt bytes
        lda astptr
more:
        cmp #SCAN_END           ; whole belt scanned?
        beq recycle             ; yes: start the belt over
match:
        ldy #$00                ; craft / asteroid collision?
        lda craft
        and (astptr),y
        bne game_over           ; hit - you've had it
        rts

recycle:
        lda #$00                ; go through the belt again
        sta astptr
        beq match               ; (always)

game_over:
        jsr SCANDS              ; display the count
        jmp game_over           ; continuously

; ---------------------------------------------------------------------
; Initial values, copied to $E2-$E8 at startup
; ---------------------------------------------------------------------
init_data:
        .word asteroid_belt     ; astptr: belt pointer (low, high)
        .byte $08, $40, $01     ; segmask: bottom, middle, top
        .byte $04               ; craft position
        .byte $ff               ; shipflag: ship on

; ---------------------------------------------------------------------
; Asteroid belt - starts at $02D5.  Each byte is one display column
; pattern (a set bit = an asteroid in that column).  The scan then
; continues through $0200-$022F (the code itself).
; ---------------------------------------------------------------------
asteroid_belt:                                  ; address
        .byte $00,$00,$00,$04,$00,$08,$00,$06  ; $02d5
        .byte $12,$00,$11,$00,$05,$00,$2c,$00
        .byte $16,$00,$29,$00,$16,$00,$2b,$00  ; $02e5
        .byte $26,$00,$19,$00,$17,$00,$38,$00
        .byte $2e,$00,$09,$00,$1b,$00,$24,$00  ; $02f5
        .byte $15,$00,$39,$00,$0d,$00,$21,$00
        .byte $10,$00,$00                      ; $0305

        .assert asteroid_start = $0200, error, "code must be linked at $0200"
        .assert asteroid_belt = $02d5, error, "belt must sit at $02D5"
