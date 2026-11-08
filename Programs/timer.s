; timer.s -- TIMER, a digital stopwatch for the KIM-1
; From "The First Book of KIM".  Starts at $0200.
;
; Shows minutes, seconds and hundredths of a second (up to 99:59.99) on
; the six display digits.  Keys:
;   0 = stop    1 = go    2 = reset (while stopped)    4 = return to KIM
;
; Timing: the interval timer counts 156 * 64 = 9984 cycles.  The 16 cycles
; between the timeout being seen and the timer being reloaded make up the
; rest of each 10,000-cycle (0.01 s) tick.  Everything after the reload
; (BCD arithmetic, keyboard scan, display scan) happens inside the next
; interval, so it does not affect accuracy.

        .include "kim.inc"

KEY_STOP    = $00
KEY_RUN     = $01
KEY_RESET   = $02
KEY_KIM     = $04

TICK        = 156               ; 156 * 64 = 9984 cycles

; Display registers, shown by SCANDS as POINTH POINTL INH
CENTISEC    = INH               ; hundredths of a second (BCD)
SECONDS     = POINTL            ; seconds (BCD)
MINUTES     = POINTH            ; minutes (BCD)

        .org PROGRAM_ORG

begin:  lda #$00
        sta CENTISEC            ; zero the display
        sta SECONDS
        sta MINUTES

hold:   jsr SCANDS              ; light the display
        jsr GETKEY
        cmp #KEY_KIM
        bne cont
        jmp START               ; return to KIM

cont:   cmp #KEY_RESET
        beq begin               ; back to zero
        cmp #KEY_RUN
        bne hold

        lda #TICK
        sta T64_NOIRQ           ; start the timer

disp:   jsr SCANDS              ; show current value
wait:   lda TIMER_FLAG          ; timed out yet?
        beq wait
        sta SAVE                ; dummy write to ROM: 4 cycles of delay
        lda #TICK
        sta T64_NOIRQ           ; restart the timer (16 cycles after timeout)

        clc
        sed
        lda CENTISEC
        adc #$01                ; increment hundredths
        sta CENTISEC
        lda SECONDS
        adc #$00                ; carry from hundredths -> seconds
        sta SECONDS
        cmp #$60                ; 60 seconds?
        bne ckey
        lda #$00
        sta SECONDS             ; zero the seconds
        lda MINUTES
        clc
        adc #$01                ; increment minutes
        sta MINUTES

ckey:   cld
        jsr GETKEY              ; read keyboard
        cmp #KEY_STOP
        bne disp
        beq hold                ; stop
