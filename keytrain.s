; keytrain.s -- KEY TRAIN from "The First Book of KIM"
; KIM-1 keypad touch-typing drill
; Shows a random hex digit (0-F) on all six display digits.  Press the
; matching key and the display blanks, then a new digit appears.  A wrong
; key is ignored.  The digit comes from the high nibble of the RIOT timer.
;
; Fully relocatable: only relative branches, no internal absolute addresses.
; Clear decimal mode first (set $00F1 to $00), or GETKEY misreads A-F.

        .include "kim.inc"

; The book keeps the digit at $FF, which kim.inc calls MODE.  Do not use
; kim.inc's TEMP ($FC) here: SCANDS/OUTPUT use it as scratch.

digit   = MODE

        .org PROGRAM_ORG

again:  jsr KEYIN               ; key still down?
        bne again               ; yes - stay blanked until it is released
        lda TIMER_READ          ; random value
        lsr a                   ; wipe low-order bits, keep the high nibble
        lsr a
        lsr a
        lsr a
        sta digit               ; save the digit
        asl a                   ; move it back to the high nibble
        asl a
        asl a
        asl a
        ora digit               ; repeat the digit in both nibbles
        sta INH                 ; put it into all three display bytes
        sta POINTL
        sta POINTH
light:  jsr SCANDS              ; light the display
        jsr GETKEY              ; test keys
        cmp digit               ; right key?
        beq again               ; yes - blank and pick a new digit
        bne light               ; no - keep showing it
