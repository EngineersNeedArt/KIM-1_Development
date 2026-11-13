; hi-lo.s -- Hi-Lo, from "The First Book of KIM"
;
; KIM picks a secret number from 01 to 98.  The display starts at
; 99 (high bound) and 00 (low bound).  Enter a two-digit guess and press
; A; the bounds narrow, and the right-hand pair shows the number of
; attempts so far.
;
;   One player:   find the number in six attempts.
;   Multi-player: each player tries NOT to guess it -- the player who
;                 does is out.
;
; Display layout while running:  POINTH POINTL INH  =  high  low  guess/count
; The attempt counter starts at $A0 and resets when it reaches $AA.

.include "kim.inc"

; ---- zero-page variables (user area) ----
rnd         = $E0       ; secret number (BCD), free-runs while waiting for a key
nguess      = $E1       ; attempts so far
last        = $E2       ; last key seen (debounce)

            .org PROGRAM_ORG

; ---- pick the secret number ----
; (named "restart", not "start": kim.inc already defines START as a
;  monitor entry at $1C4F)
restart:    sed
top:        lda rnd                 ; generate random #
            sec                     ; 01 to 98
            adc #0
            ldx #1                  ; overflow at 99
            cmp #$99
            bne ovr0
            txa
ovr0:       sta rnd
            jsr KEYIN               ; wait for a key; spin the number
            bne top

; ---- initialize ----
            cld
            lda #$99                ; ..HI
            sta POINTH
            lda #0
            sta POINTL              ; and LO
rset:       ldx #$A0                ; guess counter
nset:       stx INH
            stx nguess

; ---- read keys ----
guess:      jsr SCANDS              ; light display
            jsr GETKEY              ; test key
            cmp #KEY_GO             ; "GO" key?
            beq restart
            cmp last
            beq guess               ; same key?
            sta last
            cmp #$0A                ; "A" key?
            beq eval                ; ..yes, evaluate guess
            bcs guess               ; no key?
            asl a                   ; roll character
            asl a                   ; into
            asl a                   ; position..
            asl a
            ldx #3
loop:       asl a                   ; then
            rol INH                 ; into
            dex                     ; display
            bpl loop
            bmi guess

; ---- evaluate guess ----
eval:       lda INH                 ; guess lower
            cmp rnd                 ; than number?
            bcc ovr1                ; ..yes, skip
            cmp POINTH              ; ..no, check HI
            bcs guess               ; out of range?
            sta POINTH
ovr1:       ldx rnd                 ; number lower
            cpx INH                 ; than guess?
            bcc ovr2                ; ..yes, skip
            ldx POINTL              ; ..no, check LO
            cpx INH
            bcs guess               ; out of range?
            sta POINTL
ovr2:       ldx nguess              ; guess number
            inx                     ; plus 1
            cpx #$AA                ; past limit?
            beq rset                ; ..yes, reset
            bne nset
