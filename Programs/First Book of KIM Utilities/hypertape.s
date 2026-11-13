; hypertape.s -- HYPERTAPE! fast cassette dump (The First Book of KIM, Utilities)
;
; Writes ordinary KIM-format tapes about six times faster than the monitor
; (1K in roughly 21 seconds).  Tapes read back with the normal KIM load
; (LOADT, $1873), and DIRECTORY and VUTAPE work on them.
;
; Set up like the monitor's dump: SAL/SAH = start, EAL/EAH = end + 1,
; ID = program ID, then run it from the start.
;
; The book stages it at $0100 (page 1, so the program being dumped keeps
; the rest of memory).  The segment below puts it there with kim.cfg.
; Everything that needs relocating is a label, so moving it is a matter of
; changing the segment.
;
; "this program also included in Super-dupe" (book note)

        .include "kim.inc"

; Monitor entry points used here that kim.inc does not define
INTVEB      = $1932     ; set up VEB as "LDA (SAL),..."/RTS reader
INCVEB      = $19EA     ; increment the address inside VEB
CHKT        = $194C     ; add A to the tape checksum
DISPZ       = $185C     ; monitor exit after a tape dump
CLKRDI      = CLKKT     ; reading $1747 gives the timer flag in bit 7

; The four zero-page cells (any convenient location will do).  As in the
; book they sit in the monitor's saved-register area, so a program being
; dumped from the user area is not disturbed.
TIC         = PREG      ; $F1  count for HIC
COUNT       = SPUSER    ; $F2  bit counter for OUTCHT
TRIB        = ACC       ; $F3  burst counter for OUTCHT
GANG        = XREG      ; $F5  image of SBD with the output bit

        .segment "PAGE1"

dump:   lda #$AD
        sta VEB
        jsr INTVEB              ; set up sub
        lda #$27
        sta GANG                ; flag for SBD
        lda #$BF
        sta SBDD                ; port B direction ($1743; book calls it PBDD)
        ldx #$64
        lda #$16
        jsr hic                 ; 100 SYNC characters
        lda #$2A
        jsr outcht              ; asterisk
        lda ID
        jsr outbt
        lda SAL
        jsr outbtc
        lda SAH
        jsr outbtc
dumpt4: jsr VEB                 ; next data byte
        jsr outbtc
        jsr INCVEB
        lda VEB+1
        cmp EAL
        lda VEB+2
        sbc EAH
        bcc dumpt4
        lda #$2F
        jsr outcht              ; slash
        lda CHKL
        jsr outbt
        lda CHKH
exit:   jsr outbt
        ldx #$02
        lda #$04
        jsr hic                 ; two EOT characters
        jmp DISPZ

; ---- Subroutines ----

hic:    stx TIC                 ; send A, X times
hic1:   pha
        jsr outcht
        pla
        dec TIC
        bne hic1
        rts

outbtc: jsr CHKT                ; send A as two hex characters, with checksum
outbt:  pha                     ; ..without checksum
        lsr a
        lsr a
        lsr a
        lsr a
        jsr hexout
        pla
        jsr hexout
        rts

hexout: and #$0F                ; one hex digit as an ASCII character
        cmp #$0A
        clc
        bmi hex1                ; digit < 10 (CMP result negative)
        adc #$07
hex1:   adc #$30
                                ; falls into outcht
; Send the character in A: 8 bits, least significant first.  Each bit is
; three bursts of square wave on PB7.  Burst type Y=2 is NPUL[2] toggles at
; TIMG[2]; type Y=0 is NPUL[0] toggles at TIMG[0].  A 0 bit sends 2,2,0 and
; a 1 bit sends 2,0,0.
outcht: ldy #$07
        sty COUNT
try:    ldy #$02
        sty TRIB
zon:    ldx npul,y
        pha
zon1:   bit CLKRDI              ; wait for timer
        bpl zon1
        lda timg,y
        sta CLK1T               ; restart timer
        lda GANG
        eor #$80                ; toggle the output bit
        sta SBD
        sta GANG
        dex
        bne zon1
        pla
        dec TRIB
        beq setz                ; third burst: type 0
        bmi rout                ; all three done
        lsr a                   ; next bit..
        bcc zon                 ; ..0: second burst same as first
setz:   ldy #0                  ; ..1: second burst is type 0
        beq zon
rout:   dec COUNT
        bpl try
        rts

; Frequency/density controls.  The tables overlap on purpose: with Y = 0
; or 2, NPUL,Y reads $02 and $03 (the second byte of TIMG).
npul:   .byte $02
timg:   .byte $C3, $03, $7E
