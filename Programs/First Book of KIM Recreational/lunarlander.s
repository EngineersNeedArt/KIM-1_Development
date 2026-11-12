; lunarlander.s -- Lunar Lander, from "The First Book of KIM"
;
; Starts at $0200.  You begin at 4500 feet, falling, thrust set low.
;
;   F        show fuel (first four digits, flagged with a leading F)
;   A        show altitude again
;   1..9     set thrust; 5 exactly cancels gravity, 9 is maximum
;   0        motor off -- and it will not reignite
;   GO       start a new flight
;
; The last two digits of the display always show the rate of descent
; or ascent.  A landing at a rate of 5 or less is safe ($5AFE on the
; display); anything faster shows $DEAD.  After landing (or running out
; of fuel) the thrust keys are dead, but F still shows the fuel.
;
; All of altitude, velocity, acceleration and fuel are BCD, updated
; once per pass through the display loop.  Velocity and acceleration
; are signed ten's-complement (99 81 = -19, 99 97 = -3).
;
; Acknowledgements (original book): Ted Beach suggested the F flag when
; displaying fuel.  Chuck Eaton spotted the cause of an erratic bug in
; the original keyboard input subroutine.

        .include "kim.inc"

; ---- zero page variables ----------------------------------------------
; Note: these initial values are copied from init_table as one 14-byte
; block, so the order and spacing here must match that table.
alt         = $d5               ; altitude, 3 bytes BCD (hi, mid, lo)
vel         = $d8               ; rate of ascent/descent, 3 bytes, signed BCD
accel       = $db               ; net acceleration (thrust - 5), 2 bytes
thrust      = $dd               ; thrust setting, 0 = motor dead
fuel        = $de               ; fuel, 3 bytes BCD
dispmode    = $e1               ; 0 = show fuel, nonzero = show altitude/message
flying      = $e2               ; nonzero while in flight, 0 once landed
passes      = $e3               ; display loop pass counter

        .org PROGRAM_ORG

; ---- initialization ----------------------------------------------------
start:  ldx #13                 ; fourteen bytes
@copy:  lda init_table,x
        sta alt,x
        dex
        bpl @copy

; ---- update height and velocity ---------------------------------------
; Each pass adds, two bytes at a time, (accel -> vel) and (vel -> alt),
; sign-extending the high byte of each addend.
calc:   ldx #5
recal:  ldy #1
        sed
        clc
digit:  lda alt,x
        adc alt+2,x             ; add each digit
        sta alt,x
        dex
        dey
        bpl digit               ; next digit
        lda alt+3,x             ; hi-order addend byte: zero ...
        bpl incr                ;   ... or ...
        lda #$99                ;   ... $99 if negative
incr:   adc alt,x
        sta alt,x
        dex
        bpl recal               ; do next addition
        lda alt
        bpl fuel_burn           ; still flying?
        lda #0                  ; nope, turn off
        sta flying
        ldx #2
@land:  sta alt,x               ; zero altitude,
        sta accel,x             ; acceleration and thrust
        dex
        bpl @land

; ---- update fuel ------------------------------------------------------
fuel_burn:
        sec
        lda fuel+2
        sbc thrust
        sta fuel+2
        ldx #1                  ; two more digits to go
@borrow:
        lda fuel,x
        sbc #0
        sta fuel,x
        dex
        bpl @borrow
        bcs tank                ; still got fuel?
        lda #0                  ; nope, kill motor
        ldx #3
@kill:  sta thrust,x            ; zeroes thrust and all of fuel
        dex
        bpl @kill
        jsr thrset

; ---- show altitude, fuel, or messages ---------------------------------
tank:   lda fuel                ; fuel into registers
        ldx fuel+1
        ora #$f0                ; plus F flag
        ldy dispmode
        beq show                ; mode 0: show fuel

; branch trampolines (Z is known set when these are reached from below)
golink: beq start
clink:  beq calc

        ldx #$fe                ; assume $5AFE (safe) ...
        ldy #$5a
        clc
        lda vel+1
        adc #5
        lda vel
        adc #0
        bcs good                ; descent of 5 or less carries out
        ldx #$ad                ; ... else $DEAD
        ldy #$de
good:   tya
        ldy flying
        beq show                ; landed: show the message
        lda alt                 ; in flight: show altitude
        ldx alt+1
show:   sta POINTH
        stx POINTL

; ---- show rate of ascent/descent as an absolute value -----------------
        lda vel+1
        ldx vel                 ; up or down?
        bpl fly                 ; up, we're OK
        sec
        lda #0
        sbc vel+1
fly:    sta INH
        lda #2                  ; loop twice through display
        sta passes
flite:  cld                     ; display & key test
scan:   jsr SCANDS              ; light 'em up!
        jsr GETKEY              ; check keys
        cmp #KEY_GO
        beq golink              ; GO: new flight
        bcs nokey               ; no key
        jsr dokey
nokey:  dec passes
        bne scan                ; (enters just past the cld, as in the book)
        beq clink               ; to calc

; ---- subroutine to test keys ------------------------------------------
dokey:  cmp #$0a                ; test numeric
        bcc number
        eor #$0f                ; fuel F gives 0 flag
        sta dispmode
retrn:  rts
number: tax
        lda thrust              ; test: is motor off?
        beq retrn               ; yes, ignore key
        stx thrust              ; no, store thrust

; calculate accel as thrust minus 5
thrset: lda thrust
        sec
        sed
        sbc #5
        sta accel+1
        lda #0
        sbc #0
        sta accel
        rts

; ---- initial values ---------------------------------------------------
init_table:
        .byte $45,$01,$00       ; altitude
        .byte $99,$81,$00       ; rate of ascent
        .byte $99,$97           ; acceleration
        .byte $02               ; thrust
        .byte $08,$00,$00       ; fuel
        .byte $01               ; display mode
        .byte $01               ; in flight / landed
