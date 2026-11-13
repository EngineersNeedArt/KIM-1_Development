; pllset.s -- PLL SET tape-input PLL adjustment aid (The First Book of KIM,
; Utilities)
;
; For when tapes won't load (HYPERTAPE especially) and the PLL adjustment
; may be off, with no meter or scope handy.  Hold the tip of the plug you
; would put in the recorder's earphone jack to application connector pin 14
; (PA0), run this program, and adjust the PLL control for all 0s, or for
; combinations of 7s and Ls, on the display.
;
; "L" means the PLL TEST line (PB7) is low, "7" means it is high.  The
; program puts a tone on PA0 that alternates slightly below and slightly
; above the one KIM itself generates at $1A6B (128 half-cycles each).  The
; regular tape input is decoded to control the display.
;
; Fully relocatable: no absolute addresses except the I/O registers.
; The book puts it at $1780.

        .include "kim.inc"

CLKRDI      = CLKKT     ; reading $1747 gives the timer flag in bit 7

TOGGLE      = $E1       ; image of the PA0 output (alternates 0 and 1)
CYCLES      = $E2       ; half-cycle counter; bit 7 picks the tone

        .segment "CODE"

begin:  lda #$07                ; set input & output ports
        sta SBD
        lda #$01
        sta PADD                ; PA0 = output
        sta TOGGLE              ; initialize the toggle
        lda #$7F
        sta SADD                ; open display channels
more:   ldx #$09                ; start with the first
next:   ldy #$07                ; digit; light top & right
        bit SBD                 ; if PLL output
        bmi segs                ; is high
        ldy #$38                ; otherwise left & bottom
segs:   sty SAD                 ; turn on the segments
        stx SBD                 ; and the digit
dela:   bit CLKRDI              ; half cycle done?
        bpl dela                ; ..no, wait for time up
        inc CYCLES              ; count the cycles
        bmi loto                ; 128 half-cycles, send low tone
hito:   lda #$91                ; 128 half-cycles, send high tone
        bne clk1
loto:   lda #$95
        nop                     ; equalize the branches
clk1:   sta CLK1T               ; set the clock
        lda #$01
        eor TOGGLE              ; flip the toggle register
        sta TOGGLE
        sta PAD                 ; toggle the output port
        inx
        inx                     ; next display digit
        cpx #$15                ; last one?
        bne next                ; ..no, do next
        beq more                ; ..yes, do more
