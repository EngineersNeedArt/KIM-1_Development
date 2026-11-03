; ---------------------------------------------------------------------------
; ONE ARMED BANDIT
; by Jim Butterfield, from "The First Book of KIM"
;
; Start at $0200. KIM gives you $25; every key press spins the wheels
; and costs $1. Three bars pays $15, three ups $10, three downs $5,
; a cherry in the left window $2. Maximum bankroll is $99; at $0 the
; game stops (no credit).
; ---------------------------------------------------------------------------

        .include "kim.inc"

; Uses these kim.inc symbols: SAD ($1740), SADD ($1741), SBD ($1742),
; KEYIN ($1F40), TABLE ($1FE7). Note that the book calls $1741 "PADD", but
; in kim.inc PADD is $1701 (the user port), so this source uses SADD.

; ---- zero page ------------------------------------------------------------
; ':=' forces zero-page addressing so the object code matches the original.

window  := $00          ; 5 display cells, right to left:
                        ;   +0 amount ones, +1 amount tens,
                        ;   +2 right wheel, +3 middle wheel, +4 left wheel
amt     := $05          ; cash, BCD
arrow   := $06          ; number of wheels still spinning
rwd     := $07          ; payoff countdown
stalla  := $08          ; delay counter
tumble  := $09          ; pseudo-random wheel state

; ---- main program ---------------------------------------------------------

        .org $0200

go:     lda #$25        ; give him $25
        sta amt         ; to start with
        jsr cvamt       ; and show it to him
        lda #$00        ; reset arrow
        sta arrow

; main display loop

lpa:    jsr disply      ; display until [GO] is released
        bne lpa
roll:   inc tumble      ; randomize tumble
        jsr disply      ; display until a key is hit
        beq roll

        lda #$03
        sta arrow
        sed
        sec
        lda amt
        sbc #$01        ; charge one buck
        sta amt
        jsr cvamt       ; convert for LED
        rol tumble

lpb:    jsr disply
        dec stalla      ; display a while
        bne lpb
        ldx arrow
        lda tumble      ; make a
        and #$06        ; result
        ora #$40
        sta window+1,x
        lsr tumble
        lsr tumble      ; do all
        dec arrow       ; 3 windows
        bne lpb

; all wheels stopped: compute payoff
; (rwd is decremented before it is tested, so X = payoff + 1)

        lda window+4
        cmp window+3    ; check for
        bne nomat       ; a match
        cmp window+2
        bne nomat
        ldx #$10
        cmp #$40        ; pay $15 for 3 bars
        beq pay
        ldx #$0b
        cmp #$42        ; pay $10 for 3 ups
        beq pay
        ldx #$06
        cmp #$44        ; pay $5 for 3 downs
        beq pay
        dex             ; 3 cherries: pays $4

; a win! pay amount in X

pay:    stx rwd         ; hide reward
pax:    lda #$80
        sta stalla
lpc:    jsr disply      ; display
        dec stalla      ; for a half
        bne lpc         ; a while
        dec rwd
        beq lpa
        clc             ; slowly add
        sed             ; the payoff
        lda amt         ; to the amount
        adc #$01
        bcs lpa         ; bankroll overflowed past $99
        sta amt
        jsr cvamt
        bne pax         ; always taken (cvamt leaves Z clear)

; wheels not all the same: check for small payoff

nomat:  ldx #$03
        cmp #$46        ; a cherry? (pays $2)
        beq pay
lok:    jsr disply
        lda amt         ; can't play
        bne lpa         ; with no dough!
        beq lok         ; broke: stay here until reset

; ---- display subroutine ---------------------------------------------------
; Rolls the drums that are still spinning, then multiplexes all five cells.
; Returns with KEYIN's result in A/Z.

disply: ldx arrow
        bpl indis       ; roll
over:   inc window+2,x  ; the drum
indis:  dex
        bpl over
        lda #$7f
        sta SADD        ; segment port: bits 0-6 outputs, bit 7 input
        ldy #$0b        ; first digit select (digit 2 on the display)
        ldx #$04
lite:   lda window,x    ; light
        sty SBD         ; all the
        sta SAD         ; windows
        cld
        lda #$7f
zip:    sbc #$01        ; brief on-time delay
        bne zip
        sta SBD         ; digit off
        iny
        iny
        dex
        bpl lite
        jsr KEYIN
        rts

; ---- amount conversion ----------------------------------------------------
; Translate the BCD amount to LED codes in window+0 (ones), window+1 (tens).

cvamt:  lda amt
        and #$0f        ; translate
        tax             ; amount
        lda TABLE,x     ; to LED
        sta window      ; code
        lda amt
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        lda TABLE,x
        sta window+1
        rts
