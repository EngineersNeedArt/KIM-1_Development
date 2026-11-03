; blackmatch.s -- BLACK MATCH for the KIM-1
; Original by Ron Kushnier (modified by the editors),
; from "The First Book of KIM", pp. 46-47.
;
; 21 matches; each player takes 1, 2 or 3 per turn; whoever is left
; holding the last match loses.  You go first.  Start at $0200, press GO.
;
; Display (six digits):
;   left two   -- your move (key 1, 2 or 3)
;   center two -- the computer's move, shown after some "think time"
;   right two  -- matches remaining
;
; The computer has an IQ.  It plays the winning move whenever a random
; number (the low-order timer count) is <= IQ, otherwise it takes 1.
; Each time you win, IQ is shifted right (smarter);
; each time you lose, a 1 is shifted in (dumber).
; At the end of a game the display shows 5AFE (SAFE: you won) or
; DEAD (the computer won); press any key for a new game.
;
; Everything is BCD: the match count is manipulated in decimal mode.
;
; Corrections to the printed listing (hex dump was right):
;   $0218  F0 is BEQ, not BPL
;   $0262  A2 is LDX, not LDA
;   $024E  AE 46 17 is LDX $1746 (absolute), printed without the "$"

        .include "kim.inc"

; ---- zero page variables (user area is $00-$EE) ----
IQ      = $ED           ; computer's IQ (random compare value)
SLOW    = $EE           ; think-time delay counter

START_MATCHES = $21     ; 21 matches (BCD)
START_IQ      = $21     ; initial IQ
THINK_LOOPS   = 8       ; passes of the slowest timer = think time

        .org PROGRAM_ORG

begin:  lda #START_IQ
        sta IQ

new:    lda #START_MATCHES      ; 21 matches to start game
        sta INH

play:   lda #0                  ; clear player's move
        sta POINTH
        jsr SCANDS              ; light display
        jsr GETKEY              ;   and test keys
        cmp #4                  ; key 4 or over?
        bpl play                ;   go back
        cmp #0                  ; key 0?
        beq play                ;   go back
        sta POINTH              ; record move
        lda #0
        sta POINTL              ; wipe last KIM move

        sed                     ; decimal mode
        sec
        lda INH                 ; get total matches
        sbc POINTH              ; subtract move
        bmi play                ; not enough matches?
        sta INH                 ; OK, new total

        lda #THINK_LOOPS
        sta SLOW                ; set slow counter
time:   lda #$ff                ; slowest count into..
        sta T1024_NOIRQ         ;   ..slowest KIM timer
disp:   jsr SCANDS
        bit TIMER_FLAG          ; timer expired?
        bpl disp
        dec SLOW
        bne time

        clc
        lda INH                 ; get total
        beq dead                ; player loses?
        adc #4                  ; divide m-1 by 4
sub:    sbc #4
        beq dump
        cmp #4                  ; keep dividing
        bcs sub
        ldx CLK64T              ; random, timer #2
        cpx IQ                  ; KIM smart enough?
        bcs comp                ;   yes
dump:   lda #1                  ;   no: just take 1

comp:   sta POINTL              ; record the move
        sec
        lda INH
        sbc POINTL              ; subtract KIM move
        sta INH                 ;   from total
        bne play

        ldx #$5a                ; player wins:
        ldy #$fe                ;   SAFE
        lsr IQ                  ; get smart
        bpl show                ; (always taken: LSR clears N)

dead:   ldx #$de                ; KIM wins:
        ldy #$ad                ;   DEAD
        sec
        rol IQ                  ; get dumb

show:   stx POINTH
        sty POINTL
lok:    jsr SCANDS
        bne new                 ; new game if key
        beq lok
