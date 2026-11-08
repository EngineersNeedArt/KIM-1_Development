; craps.s -- CRAPS, from The First Book of KIM
;
; Set address $0200 and hold GO: two dice roll on the left of the display,
; the $10 bankroll shows on the right.  Release GO and the dice stop.
;   7 or 11 on the first roll  win  (+$01)
;   2, 3 or 12                 lose (-$01)
;   anything else              a "point": the total lights in the center
;                              segments; roll it again before rolling a 7
; Press GO only for the first roll; use any other key for later rolls.

        .include "kim.inc"

; ---- zero page ----
last    = $40           ; last key seen (debounce)
flag    = $41           ; 0 = no key down, else rolling
die     = $42           ; first die value
windx   = $43           ; first die segment pattern
bux     = $44           ; bankroll, BCD
point   = $45           ; point to make, 0 = none
window  = $46           ; six display segment bytes, $46-$4b
divr    = $4e           ; divisor for the divide-by-6 loop
pause   = $4f           ; delay counter for display multiplex

        .org PROGRAM_ORG

start:  cld
        jsr KEYIN
        jsr GETKEY
        cmp last
        beq light               ; same key as before?
        sta last
        eor #KEY_NONE           ; no-key test
        sta flag
        cmp #(KEY_GO ^ KEY_NONE) ; GO key?
        bne nogo
        lda #$10                ; new game: $10 bankroll
        jsr dobux

nogo:   lda T1_NOIRQ            ; free-running timer as random value
        ldx #$c0                ; divide by 6
        stx divr
        ldx #5
rndlp:  cmp divr
        bcc rndov
        sbc divr                ; remainder is the die, 0-5
rndov:  lsr divr
        dex
        bpl rndlp
        tax
        inx                     ; die 1-6
        lda TABLE,x             ; its segment pattern
        ldy flag                ; which die?
        beq play                ; flag clear: second die
        stx die                 ; first die: save value
        sta windx               ; ...and segments
        bne light               ; always

play:   sta window+1            ; show second die
        lda windx
        sta window              ; and the first one
        lda bux                 ; out of money?
        beq light
        txa
        clc
        adc die                 ; total of both dice
        cmp point               ; made the point?
        beq win
        ldx point               ; zero point means first roll
        beq first
        cmp #7                  ; seven loses
        bne light

lose:   lda bux
        beq losx                ; nothing left to take
        clc
        sed                     ; decimal subtract:
        sbc #0                  ; carry clear makes this minus one
        cld
losx:   jsr dobux
        bne light               ; always (dobux ends on a nonzero LDA)

first:  ldx window              ; copy dice to the point display
        stx window+2
        ldx window+1
        stx window+3
        sta point
        tax
        lda tab-2,x             ; win/lose/point table for this total
        beq light               ; 0: it's a point
        bmi lose                ; $ff: craps
win:    lda bux                 ; 1: win
        cmp #$99                ; maximum bankroll?
        beq winx
        sed
        adc #1                  ; carry is clear here
        cld
winx:   jsr dobux

light:  lda flag                ; still rolling?
        beq noinc
        inc window              ; yes: spin both dice
        inc window+1
noinc:  lda #$7f
        sta SADD
        ldy #$13
        ldx #5
lite:   lda window,x
        sta SAD
        sty SBD
paws:   inc pause
        bne paws
        dey
        dey
        dex
        bpl lite
        jmp start

; store A as the bankroll, clear the point, and build its two display digits
dobux:  sta bux
        ldy #0
        sty point
        sty window+2
        sty window+3
        tay
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        lda TABLE,x
        sta window+4
        tya
        and #$0f
        tax
        lda TABLE,x
        sta window+5
        rts

; first-roll outcome by total, 2 through 12: $ff lose, $01 win, $00 point
tab:    .byte $ff,$ff,$00,$00,$00,$01,$00,$00,$00,$01,$ff
