; chess_clock.s -- Chess Clock for the KIM-1
; From The First Book of KIM; converted to ca65 source.
;
; Two independent clocks are operated by the two players, who press
; key 1 or key 2 respectively.  The right two digits of the display show
; the move number; the left four digits show minutes and seconds.
; Maximum time is 99 minutes 59 seconds.
;
; Start at $0200, then press key "2" to start clock #1 running.
;
; Fine tuning: the byte at $027F (the operand of the LDA #$BF in `time`,
; labelled `tune` below) sets the length of the last little bit of each
; second.  Increasing it by 1 slows the clock by approximately 6 seconds
; per 24 hours; decreasing it by 1 speeds it up by the same amount.

        .include "kim.inc"

; ---- Zero page ----
; The display shows POINTH POINTL INH (left to right) -- minutes, seconds,
; move number -- so the running clock is kept in POINTH/POINTL, and the
; idle clock is parked in the stored pairs below.

clk1_min = $D0          ; clock #1 minutes while it is not displayed
clk1_sec = $D1          ; clock #1 seconds
clk2_min = $D2          ; clock #2 minutes while it is not displayed
clk2_sec = $D3          ; clock #2 seconds
running  = $D4          ; which clock is running: 1 or 2 (= its key number)
mult     = $D5          ; timer-load counter (4 loads of ~0.25 s each)
move     = INH          ; move number, BCD (right two digits)
minutes  = POINTH       ; minutes, BCD (left two digits)
seconds  = POINTL       ; seconds, BCD (centre two digits)

        .org PROGRAM_ORG

; ---- Zero all of page zero ----
start:  lda #$00
        tax
zero:   sta a:$0000,x   ; absolute,X form (3 bytes) -- keep it, the layout
        inx             ; depends on it
        bne zero

; ---- Display zeroes until key 2 is pressed ----
disp:   jsr SCANDS
        jsr GETKEY      ; key pressed?
        cmp #$02        ; key #2?
        bne disp        ; no, wait until 2 is down

; ---- Main loop: clock #1 runs, then clock #2 runs ----
loop:   lda #$01        ; flag to 1
        sta running     ; (clock #1 to run)
        jsr time        ; get clock running
        jsr savetime    ; save time on display
        lda #$02        ; flag to 2
        sta running     ; (clock #2 to run)
        jsr time        ; get other clock running
        clc             ; increment move number
        lda move
        adc #$01        ; BCD: SED is still in effect from `time`
        sta move
        jsr savetime    ; save clock #2 time
        jmp loop        ; back to clock #1

; ---- Save time indicated subroutine ----
; Stores the displayed time for the clock that just stopped and loads
; the display with the other clock's stored time.
savetime:
        lda #$02        ; clock #2?
        cmp running
        bne clk1        ; no, store for clock #1
        lda minutes     ; store values for clock #2
        sta clk2_min
        lda seconds
        sta clk2_sec
        lda clk1_min    ; load display with values for clock #1
        sta minutes
        lda clk1_sec
        sta seconds
        rts
clk1:   lda minutes     ; store values for clock #1
        sta clk1_min
        lda seconds
        sta clk1_sec
        lda clk2_min    ; load display with values for clock #2
        sta minutes
        lda clk2_sec
        sta seconds
        rts

; ---- Clock advance subroutine ----
; The original program places this at $0260; pad so that the addresses
; (and the tuning byte at $027F) match the book.
        .res $0260 - *

time:   sed             ; set decimal mode
        lda #$04        ; time multiplier to 4
        sta mult
load:   lda #$F0        ; set timer
        sta T1024_NOIRQ ; ($F0 x 1024 cycles, about 0.25 s)
lite:   jsr SCANDS      ; display clock
        jsr GETKEY      ; get keyboard entry
        cmp running     ; equal to flag?
        bne wait        ; no, time out then update
        rts             ; yes, return from subroutine
wait:   bit TIMER_FLAG  ; time done?
        bpl lite        ; not yet
        dec mult        ; decrement time multiplier
        bne load        ; not zero, reset timer
        lda #$BF        ; last little bit of time
tune = * - 1            ; <- the tuning byte, $027F
        sta T64_NOIRQ   ; into timer
tiny:   bit TIMER_FLAG  ; done?
        bpl tiny        ; no
        clc             ; one second added
        lda seconds     ; to clock
        adc #$01
        sta seconds     ; (centre two digits)
        cmp #$60        ; a minute up?
        bne nomn        ; not yet
        sec             ; yes, seconds to zero
        lda #$00
        sta seconds
nomn:   lda minutes     ; minutes incremented
        adc #$00        ; if carry set
        sta minutes
        jmp time        ; loop
