; blinken.s -- random-segment "blinkenlights" on the PAL-II six-digit display
;
; Derived from wave.s.  Same multiplexing: one digit is selected through
; SBD, its segments are written to SAD, held ~1 ms, then the next digit.
; Instead of rotating a fixed pattern, every SCANS_PER_STEP full scans each
; of the six digits is given one randomly chosen segment (A-G, equal odds).
; Runs until reset or ST.
;
; Random numbers come from a 16-bit Galois LFSR (taps $B400, period 65535),
; clocked eight times per call so successive bytes are not just shifted
; copies of each other.

        .include "kim.inc"

; Segment bits in SAD (PA0-PA6); a segment is lit when its bit is 1
SEG_A   = $01
SEG_B   = $02
SEG_C   = $04
SEG_D   = $08
SEG_E   = $10
SEG_F   = $20
SEG_G   = $40

DIGIT_COUNT    = 6      ; the display has six digits
DIGIT_FIRST    = $09    ; SBD value that selects the leftmost digit
DIGIT_STEP     = 2      ; SBD advances by 2 per digit ($09,$0B,...,$13)
SCANS_PER_STEP = 30     ; full scans (~6 ms each) between re-rolls, ~0.2 s
ON_TIME        = $C8    ; delay count, about 1 ms at 1 MHz
SEED           = $ACE1  ; any nonzero value; the LFSR must never be all zero

        .zeropage
frames: .res 1          ; scans left before the next re-roll
rng:    .res 2          ; LFSR state (lo, hi)

        .data
table:  .res DIGIT_COUNT        ; current segment for each digit
seg_tab:.byte SEG_A, SEG_B, SEG_C, SEG_D, SEG_E, SEG_F, SEG_G

        .code
start:  lda #$7F        ; PA0-PA6 outputs (segments); PA7 stays input
        sta SADD
        lda #$3F        ; PB0-PB5 outputs (digit select)
        sta SBDD

        lda #<SEED
        sta rng
        lda #>SEED
        sta rng+1

step:   jsr randomize
        lda #SCANS_PER_STEP
        sta frames

scan:   ldx #0          ; X = digit index
        ldy #DIGIT_FIRST ; Y = digit-select value
digit:  sty SBD         ; select digit
        lda table,x
        sta SAD         ; light its segment
        jsr on_time
        inx
        iny
        iny             ; next digit (+DIGIT_STEP)
        cpx #DIGIT_COUNT
        bne digit
        dec frames
        bne scan
        jmp step

; give every digit a new random segment; clobbers A, X, Y
randomize:
        ldx #DIGIT_COUNT-1
@next:  jsr rand
        and #$07        ; 0-7
        cmp #7
        bcs @next       ; reject 7 (no modulo bias), re-roll this digit
        tay
        lda seg_tab,y   ; index -> segment bit
        sta table,x
        dex
        bpl @next
        rts

; return a pseudo-random byte in A; preserves X, clobbers Y
rand:   ldy #8
@bit:   lsr rng+1       ; 16-bit shift right, bit 0 falls into carry
        ror rng
        bcc @skip
        lda rng+1
        eor #$B4        ; feedback taps $B400
        sta rng+1
@skip:  dey
        bne @bit
        lda rng
        rts

; hold the current digit lit for about 1 ms; preserves Y, clobbers A
on_time:
        tya
        ldy #ON_TIME
@wait:  dey
        bne @wait
        tay
        rts
