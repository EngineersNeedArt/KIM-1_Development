; wave.asm -- travelling segment wave on the PAL-II six-digit display
;
; The display is multiplexed: one digit is selected through SBD, its
; segments are written to SAD, held ~1 ms, then the next digit.  Every
; SCANS_PER_STEP full scans the pattern table is rotated left by one
; entry, so the wave appears to move.  Runs until reset or ST.

        .include "kim.inc"

; Segment bits in SAD (PA0-PA6); a segment is lit when its bit is 1
SEG_A   = $01
SEG_B   = $02
SEG_C   = $04
SEG_D   = $08
SEG_E   = $10
SEG_F   = $20
SEG_G   = $40

PATTERN_LEN    = 7      ; table entries (the display has six digits)
DIGIT_FIRST    = $09    ; SBD value that selects the leftmost digit
DIGIT_STEP     = 2      ; SBD advances by 2 per digit ($09,$0B,...,$13)
SCANS_PER_STEP = 10     ; full scans before the wave moves one step
ON_TIME        = $C8    ; delay count, about 1 ms at 1 MHz

        .zeropage
frames: .res 1          ; scans left before the next rotation

        .data
table:  .byte SEG_D, SEG_G, SEG_A, SEG_G, SEG_D, SEG_D, SEG_D

        .code
start:  lda #$7F        ; PA0-PA6 outputs (segments); PA7 stays input
        sta SADD
        lda #$3F        ; PB0-PB5 outputs (digit select)
        sta SBDD

step:   lda #SCANS_PER_STEP
        sta frames

scan:   ldx #0          ; X = pattern index
        ldy #DIGIT_FIRST ; Y = digit-select value
digit:  sty SBD         ; select digit
        lda table,x
        sta SAD         ; light its segments
        jsr on_time
        inx
        iny
        iny             ; next digit (+DIGIT_STEP)
        cpx #PATTERN_LEN
        bne digit
        dec frames
        bne scan

; rotate the table left by one entry
        ldy table       ; Y = old first entry
        ldx #0
@shift: lda table+1,x
        sta table,x
        inx
        cpx #PATTERN_LEN-1
        bne @shift
        sty table+PATTERN_LEN-1 ; old first entry goes to the end
        jmp step

; hold the current digit lit for about 1 ms; preserves Y, clobbers A
on_time:
        tya
        ldy #ON_TIME
@wait:  dey
        bne @wait
        tay
        rts
