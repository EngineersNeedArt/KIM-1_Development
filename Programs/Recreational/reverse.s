; reverse.s -- REVERSE for the KIM-1
; Game by Bob Albrecht, People's Computer Co.
; From "The First Book of KIM".  Starts at $0200.
;
; Six letters A-F are scrambled on the display.  Keys 2-6 reverse the
; first N letters (key 2 swaps the first two, key 6 reverses all six).
; Put them in order ABCDEF to win; the display then shows six dashes.
; The same flip twice in a row is ignored, so you can't back up a move.
; GO restarts with a new scramble.

.include "kim.inc"

; ---- zero page ----
pointr  = $10           ; number of letters flipped last time (-1 = none)
modulus = $11           ; divisor while dividing by 6, then display delay
rnd     = $12           ; six-byte random string, rnd..rnd+5
window  = $18           ; six display digits, left to right

.org PROGRAM_ORG

restart:
        inc rnd+4               ; randomize while waiting for a key
        jsr KEYIN
        bne restart
        cld
        ldx #5
        lda #0
        stx pointr
zloop:  sta window,x            ; set window to zeros
        dex
        bpl zloop

; Deal the letters F..A into random empty windows.
rand:   sec
        lda rnd+1               ; hash in new random number
        adc rnd+4
        adc rnd+5
        sta rnd
        ldx #4
rlp:    lda rnd,x               ; move random string down one
        sta rnd+1,x
        dex
        bpl rlp
        ldy #$c0                ; divide random byte by 6
        sty modulus
        ldy #6
divloop:
        cmp modulus
        bcc pass
        sbc modulus
pass:   lsr modulus
        dey
        bne divloop
        tax                     ; X = remainder 0..5 = empty slots to skip
        ldy pointr
        lda TABLE+10,y          ; digits A to F
top:    dex
        bpl try
        ldx #5
try:    ldy window,x            ; find an empty window
        bne top
        sta window,x            ; and put the digit in
        dec pointr
        bpl rand
slink:  beq restart             ; link to restart (reached from GO)

wtest:  ldx #5                  ; test win condition
test2:  lda window,x
        cmp winner,x
        bne play
        dex
        bpl test2
        ldx #5
        lda #$40                ; set window to dashes
dash:   sta window,x
        dex
        bpl dash

play:   lda #$7f                ; directional registers
        sta SADD
        ldy #$09
        ldx #$fa                ; negative 6 (window+6+$fa wraps to window)
show:   lda window+6,x          ; light display
        sta SAD
        sty SBD
delay:  dec modulus
        bne delay
        iny
        iny
        inx
        bmi show
        jsr KEYIN
        jsr GETKEY
        cmp #KEY_GO             ; GO key?
        beq slink               ; ..yes, restart
        cmp #7                  ; keys 0 to 6?
        bcs wtest               ; ..no, test win
        tax                     ; keys 1 to 6?
        beq play                ; ..no, exit
        dex                     ; keys 2 to 6 (= 1 to 5)?
        beq play                ; ..no, exit
        cpx pointr              ; same key as before?
        beq play                ; ..yes, ignore
        stx pointr              ; ..no, we've got a live one
roll1:  lda window,x            ; roll 'em out...
        pha
        dex
        bpl roll1
        ldx pointr
roll2:  pla                     ; roll 'em back in
        sta window,x
        dex
        bpl roll2
        bmi play

winner: .byte $f7,$fc,$b9       ; A b C
        .byte $de,$f9,$f1       ; d E F
