; clock.s -- real-time clock driven by the KIM-1 interval timer and NMI
; From The First Book of KIM.  The book assembles it at $0300; here it is
; relocatable and builds at the normal $0200 origin, so the addresses
; below come from the listing (build/clock.lst), not from the book.
;
; The interval timer (/1024) is loaded with $F4 each time the NMI fires.
; That is 244 * 1024 = 249,856 us, just under 1/4 second.  The /1 timer
; inside the interrupt routine pads that out to exactly 1/4 second;
; adjust fine_adjust (below) to trim the clock rate.
;
; Subroutines: escape-to-KIM and an hourly two-tone chime.  More can be
; added by replacing the NOPs in the hook area with JSRs to your own code.
;
; To start the clock:
;   1) Route the timer interrupt to the CPU's /NMI input.
;      - KIM-1 (6530 RIOT): connect PB7 (A-15) to NMI (E-6), as in the book.
;      - PAL-2 (6532 RIOT): PB7 does not signal the timer and as such, this program 
;        will not work! (Pin 25 on U3 is what is needed and is not connected.)
;   2) Set the time and AM/PM counters in page zero (secs, mins, hours, day).
;   3) Run from clock_start (the first address of the program's display
;      section; see the listing) and press GO.  clock_start points the NMI
;      vector (NMIV, $17FA/$17FB) at nmi_clock itself.
; To get back to the display with the clock running, start at dsp.

        .include "kim.inc"

; ---- Page zero ----
note    = $70           ; half-period of the note (pitch)
qsec    = $80           ; quarter-second counter
secs    = $81           ; seconds, BCD   (not "sec": that is a mnemonic)
mins    = $82           ; minutes, BCD
hours   = $83           ; hours, BCD, 1-12
day     = $84           ; incremented every 12 hours (AM/PM)

; ---- Constants ----
key_one      = $01      ; GETKEY value for the "1" key
fine_adjust  = $83      ; T1_NOIRQ pad value: tunes the clock rate
timer_start  = $F4      ; T1024_IRQ count, 244 * 1024 us
note_high    = $1E
note_low     = $28

; Set to 1 to fake the NMI in software: the display loop polls the timer
; flag and runs nmi_clock itself.  Use it to tell a hardware problem (the
; PB7-to-NMI path) from a software one.  Leave at 0 for normal use.
poll_test = 0

; Monitor entry just past the register save at SAVE ($1C00); not in kim.inc.
save1   = $1C05

; ---------------------------------------------------------------------
; Escape to KIM if "1" is pressed.  Returns to the monitor without
; stopping the clock.  Key must read "1" on two reads, with a display
; scan between them as a debounce.
; ---------------------------------------------------------------------
kim:    jsr GETKEY
        cmp #key_one
        bne kim_rts
        jsr SCANDS
        jsr GETKEY
        cmp #key_one
        bne kim_rts
        jmp save1
kim_rts:
        rts

; ---------------------------------------------------------------------
; Hourly chime.  On the hour, for secs < hours (so one second per hour
; of the clock), play a high note in the first quarter second and a low
; note in the second.  Speaker on PB0.
; ---------------------------------------------------------------------
beep:   lda mins                ; on the hour?
        bne beep_rts            ; if not, return
        lda secs                ; run until secs >= hours
        sec
        sbc hours
        bpl beep_rts
again:  lda qsec                ; first 1/4 second?
        bne second
        lda #note_high
        sta note
        bne sound               ; always taken
second: lda #$01                ; second 1/4 second?
        cmp qsec
        bne beep_rts
        lda #note_low
        sta note
sound:  lda #$01                ; PB0 as output
        sta PBDD
        inc PBD                 ; toggle speaker
        lda note
        tax                     ; delay sets the pitch
delay:  dex
        bpl delay
        bmi again               ; always taken; keep sounding
beep_rts:
        rts

; ---------------------------------------------------------------------
; NMI handler: advance the clock in page zero.  NMIV must point here.
; ---------------------------------------------------------------------
nmi_clock:
        pha
        txa
        pha
        tya
        pha
        lda #fine_adjust        ; fine-adjust timing
        sta T1_NOIRQ
wait:   bit TIMER_FLAG          ; wait for time-out
        bpl wait
        inc qsec                ; count 1/4 seconds
        lda #$04                ; do four times before updating seconds
        cmp qsec
        bne nmi_exit
        lda #$00
        sta qsec
        clc
        sed                     ; advance the clock in decimal
        lda secs
        adc #$01
        sta secs
        cmp #$60                ; until 60 seconds,
        bne nmi_exit
        lda #$00                ; then start again
        sta secs
        lda mins
        clc
        adc #$01                ; and advance minutes
        sta mins
        cmp #$60                ; until 60 minutes,
        bne nmi_exit
        lda #$00                ; then start again
        sta mins
        lda hours               ; and advance hours
        clc
        adc #$01
        sta hours
        cmp #$12                ; until 12 hours
        bne chk13
        inc day                 ; advance 1/2 day
chk13:  cmp #$13                ; if 13 hours,
        bne nmi_exit
        lda #$01                ; start again with 1
        sta hours
nmi_exit:
        cld                     ; back to binary mode
        lda #timer_start        ; restart timer with interrupt
        sta T1024_IRQ
        pla
        tay
        pla
        tax
        pla
        rti

; ---------------------------------------------------------------------
; Display the clock on the KIM-1 readout: seconds on the two right
; digits (INH), minutes in POINTL, hours in POINTH.
; ---------------------------------------------------------------------
clock_start:
        lda #<nmi_clock         ; point the NMI vector at our handler
        sta NMIV                ; (the book has you poke this in by hand)
        lda #>nmi_clock
        sta NMIV+1
        lda #$00                ; reset 1/4 second counter
        sta qsec
        lda #timer_start        ; start timer with interrupt
        sta T1024_IRQ
dsp:    lda secs                ; start here if the clock is running
        sta INH
        lda mins
        sta POINTL
        lda hours
        sta POINTH
        jsr SCANDS
        jsr kim                 ; escape to KIM
        jsr beep                ; sound on the hour

.if poll_test
        bit TIMER_FLAG          ; timer expired?
        bpl no_tick
        lda #>no_tick           ; build an interrupt frame: return address,
        pha
        lda #<no_tick
        pha
        php                     ; then status
        jmp nmi_clock           ; its RTI comes back to no_tick
no_tick:
.endif

        ; Hook area: replace these NOPs with JSRs to your own routines
        ; (home control, etc.).  Ten JSR slots of three bytes each.
        .repeat 30
        nop
        .endrepeat

        jmp dsp
