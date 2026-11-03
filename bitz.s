; bitz.s -- binary-to-hexadecimal drill for the KIM-1 / PAL-II
; From "The First Book of KIM", converted to ca65 source.
;
; Eight bits are shown on the left four digits, two bits per digit
; (a segment in the top row = 1, in the bottom row = 0).  Key in the
; value as two hex digits.  A correct first digit is echoed on the
; fifth display digit, a correct second digit on the sixth; once the
; key is released a new problem is generated.
;
; Start at $0200.

        .include "kim.inc"

; ---- zero page -------------------------------------------------------
delay   = $11           ; free-running delay counter (never initialised)
prev    = $14           ; key seen on previous pass
seed    = $15           ; the 8-bit problem (rotated out as segments)
seed1   = $16           ; answer, high digit
seed2   = $17           ; answer, low digit
window  = $18           ; six display digits, $18-$1D
flag1   = $1c           ; window+4: 0 = high digit not yet entered
flag2   = $1d           ; window+5: 0 = low digit not yet entered

; ---- I/O not (yet) in kim.inc ----------------------------------------
; Interval timer read-back.  $1706 (TIMER_READ) would also work; $1704
; is what the original used, so the bytes stay identical to the book.
timer   = T1_NOIRQ

        .org PROGRAM_ORG

start:  cld
        lda #1                  ; flag2 <> 0 means "solved",
        sta flag2               ; so a new problem is set up
main:   jsr KEYIN               ; set directional registers
        jsr GETKEY              ; get key input
        cmp prev                ; same as last time?
        beq light               ; yes, just refresh display
        sta prev                ; record new input
        cmp #KEY_NONE           ; no key down?
        beq nokey               ; yes, branch
        ldx flag1               ; first digit already found?
        bne dig1                ; yes, check second
        cmp seed1               ; first digit match?
        bne light               ; no, ignore input
        tax
        lda TABLE,x             ; change to segment pattern
        sta flag1               ; and show it
        bne light               ; (always: patterns are non-zero)

dig1:   cmp seed2               ; second digit match?
        bne light               ; no, ignore input
        tax
        lda TABLE,x             ; change to segment pattern
        sta flag2
        bne light

nokey:  ldx flag2               ; problem solved?
        beq light               ; not yet, skip
        lda #0                  ; clear both flags
        sta flag1               ; for a new problem
        sta flag2
        lda timer               ; random value from the timer
        tax
        and #$0f                ; low digit...
        sta seed2               ; ...is the second answer digit
        txa
        lsr a                   ; high digit...
        lsr a
        lsr a
        lsr a
        sta seed1               ; ...is the first answer digit
        stx seed                ; whole number, to be rotated out
        ldx #$fc                ; -4: four display digits
patt:   lda #0
        rol seed                ; roll two bits, MSB first,
        rol a                   ; into A (0-3)
        rol seed
        rol a
        tay
        lda bitpair,y           ; convert to a segment pattern
        sta window+4,x          ; X=$FC-$FF wraps in zero page
        inx                     ; to window+0..window+3
        bne patt

light:  lda #$7f                ; segment lines = outputs
        sta SADD
        ldy #9                  ; first digit select
        ldx #$fa                ; -6: six digits
show:   lda window+6,x          ; X=$FA-$FF wraps in zero page to window+0..5
        sta SAD
        sty SBD
wait:   dec delay
        bne wait
        iny                     ; next digit select
        iny
        inx
        bmi show
        bpl main                ; X = 0 here, so N is clear: always taken

; Two bits -> two segments: left digit-half / right digit-half.
; 00 = both low, 01 = left low, right high,
; 10 = left high, right low, 11 = both high.
bitpair:
        .byte $14, $12, $24, $22
