; music_box.s -- Music Box for the KIM-1 (from The First Book of KIM)
;
; Plays tunes through the cassette audio-out (PB7 of the keyboard/display
; RIOT) or, with SPEAKER defined, through a speaker on PA0 of the
; application connector.  The player is at $0200; the tunes live in zero
; page ($0000-$00DF) and are emitted into the same tape (segment ZPDATA).
; Start at $0200 (AD 0 2 0 0 GO).  BRK needs IRQV ($17FE/$17FF) = $1C00.
;
; ---- Build options ----
; SPEAKER      speaker on PA0 of the application connector
;              (User Manual Fig. 5.1).  Comment out for cassette audio-out.
; ENTERTAINER  assemble the book's "Extra Datafile" tune instead of the
;              three sample tunes.
; (Either can also be set on the ca65 command line, e.g. -D SPEAKER, if
; the line below is commented out.)

SPEAKER = 1
; ENTERTAINER = 1

; ---- Tune codes (each followed by one parameter byte) ----
;   $FB  speed of tune            init $30  ($18 = quick, $60 = slow)
;   $FC  long-note factor         init 2
;   $FD  octave                   init 1    (2 = bass, 4 = deep bass)
;   $FE  instrument               init $FF  ($FF = piano, $00 = clarinet)
;   $FF  set tune address         init 0    ($00 = back to first tune)
; $FA ends a tune and halts (BRK) until GO is pressed.  Follow the last
; tune with $FF $00.  Notes: bit 7 = long note, bits 0-6 = pitch period,
; $00 / $80 = pause.  Replace the BRK with RTS to use the player as a
; subroutine.

        .include "kim.inc"

; ---- Output selection ----
; The book's speaker patch ($020D, $024C, $0255, $0270) is this block.
.ifdef SPEAKER
out_ddr   = PADD                ; $1701 (book: $020D  43 -> 01)
out_port  = PAD                 ; $1700 (book: $0270  42 -> 00)
level_hi  = $FF                 ;        book: $024C  A7 -> FF
level_lo  = $00                 ;        book: $0255  27 -> 00
.else
out_ddr   = SBDD                ; $1743
out_port  = SBD                 ; $1742
level_hi  = $A7
level_lo  = $27
.endif

; ---- Work area (zero page) ----
work    = $E0           ; $E0 speed, $E1 long factor, $E2 octave,
                        ; $E3 instrument, $E4/$E5 tune pointer
limit   = $E6           ; $E6 length factor, $E7 / $E8 timing counters
val2    = $E9
val1    = $EA
timer   = $EB
xsav    = $EC

; ---- Tune data: loaded at $0000 (segment ZPDATA) ----
        .segment "ZPDATA"

.ifndef ENTERTAINER

; Three sample tunes.  Tunes 1 and 2 set speed and instrument; tune 3
; continues at the previous speed and changes instrument during the tune.

; Tune 1 ($0000) -- speed $18, piano
        .byte $FB,$18, $FE,$FF
        .byte $44,$51,$E6,$E6,$66,$5A,$51,$4C,$C4,$C4,$C4,$D1
        .byte $BD,$BD,$BD,$00,$44,$BD,$00,$44
        .byte $3D,$36,$33,$2D,$A8,$80,$80,$33
        .byte $44,$B3,$80,$80,$44,$51,$C4,$80,$80,$5A,$51,$E6,$80,$80
        .byte $FA

; Tune 2 ($002F) -- speed $28, clarinet
        .byte $FE,$00, $FB,$28
        .byte $5A,$5A,$51,$48,$5A,$48,$D1
        .byte $5A,$5A,$51,$48,$DA,$E0
        .byte $5A,$5A,$51,$48,$44,$48,$51,$5A,$60,$79,$6C,$60,$DA,$DA
        .byte $FA

; Tune 3 ($004F) -- piano, then clarinet
        .byte $FE,$FF
        .byte $5A,$5A,$5A,$5A,$5A,$5A,$66,$72,$79,$E6,$E6,$80,$00
        .byte $56,$56,$56,$56,$56,$56,$5A,$66,$F2,$80,$80
        .byte $4C,$4B,$4C,$4C,$4C,$4C,$56,$5A,$56,$4C,$00
        .byte $C4,$44,$4C,$56,$5A,$5A,$56,$5A,$66,$56,$5A,$66,$F2,$80
        .byte $FE,$00
        .byte $00,$72,$5A,$CC,$72,$5A,$CC,$72,$5A,$CC,$80,$B8,$80
        .byte $4C,$56,$5A,$56,$5A,$E6,$F2,$80
        .byte $FA

        .byte $FF,$00           ; after the last tune: back to the first

.else

; The book's "Extra Datafile": one long tune, clarinet intro / piano
; phrases, using $FC 06 to hold a long note six times the short length.
        .byte $FE,$00
        .byte $56,$52,$4D,$AF,$4D,$AF,$4D
        .byte $FC,$06,$AF,$FC,$02
        .byte $FE,$FF
        .byte $2F,$29,$26,$24,$2F,$29,$A4,$32,$A9
        .byte $FC,$06,$AF,$FC,$02
        .byte $FE,$00
        .byte $56,$52,$4D,$AF,$4D,$AF,$4D
        .byte $FC,$06,$AF,$FC,$02
        .byte $FE,$FF
        .byte $39,$40,$44,$39,$2F,$A4,$29,$2F,$39,$A9,$80,$80
        .byte $FE,$00
        .byte $56,$52,$4D,$AF,$4D,$AF,$4D
        .byte $FC,$06,$AF,$FC,$02
        .byte $FE,$FF
        .byte $2F,$29,$26,$24,$2F,$29,$A4,$32,$A9,$AF,$80,$80
        .byte $2F,$29,$24,$2F,$29,$A4,$2F,$29,$2F,$24
        .byte $2F,$29,$A4,$2F,$29,$2F,$24,$2F,$29,$A4,$32,$A9,$AF,$80,$80
        .byte $FA
        .byte $FF,$00

.endif

; ---- Player: loaded at $0200 (segment CODE) ----
        .segment "CODE"

; Initialize - reset work parameters
start:  ldx #5
lp1:    lda init,x
        sta work,x
        dex
        bpl lp1

; Main routine - work not reset
go:     lda #$BF
        sta out_ddr             ; open output channel
        ldy #0
        lda (work+4),y          ; get next note
        inc work+4
        cmp #$FA                ; test for halt
        bne next
        brk                     ; (or RTS if used as subroutine)
        nop
        beq go                  ; resume when GO pressed
next:   bcc note                ; is it a note?
        sbc #$FB                ; if not, decode instrument
        tax                     ; and put it into X
        lda (work+4),y          ; get parameter
        inc work+4
        sta work,x              ; store in work table
        bcs go                  ; unconditional branch

; Set up for timing note
note:   ldx work                ; timing
        stx limit+1
        ldx work+1              ; long note factor
        tay                     ; test accum.
        bmi over                ; long note?
        ldx #1                  ; ..nope, set short note
over:   stx limit               ; store length factor
        and #$7F                ; remove short/long flag
        sta val2
        beq hush                ; is it a pause
        sta val1                ; ..no, set pitch
hush:   lda val2                ; get timing and
        and work+3              ; bypass if muted
        beq on
        inc val1                ; else fade the
        dec val2                ; note
on:     ldx val2
        lda #level_hi
        jsr sound
        bmi go
        ldx val1
        lda #level_lo
        jsr sound
        bmi go
        bpl hush

; Subroutine to send a bit
sound:  ldy work+2              ; octave flag
        sty timer
        stx xsav
sloop:  cpx #0
        bne cont
        ldx xsav
        dec timer
        bne sloop
        beq sex
cont:   sta out_port
        dex
        dec limit+2
        bne sloop
        dec limit+1
        bne sloop
        ldy work
        sty limit+1
        dec limit
        bne sloop
        lda #$FF
sex:    rts

; Initial constants (copied to work at start)
init:   .byte $30,2,1
        .byte $FF,0,0
