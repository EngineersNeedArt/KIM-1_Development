; yahtzee.s -- KIM-1 Yahtzee: dice, keys, animation and scoring
; plain 6502, ca65, lowercase, using kim.inc and kim.cfg
;
; Play:
;   GO        first hand only: all five dice tumble, then are revealed
;             left to right on random values
;   digit 6   round: - first roll, = first re-roll, three bars second re-roll
;   keys 1-5  toggle a die between steady and flashing
;   DA        the flashing dice tumble and are revealed again.  After the
;             third roll of a hand, or with no die flashing, the hand is
;             final: it is scored into the best open trick, the dice stay
;             up for a moment, then the points show in the right two digits.
;             DA then deals a new hand (all five dice).
;
; Choosing the trick: every open trick is tried and the one with the best
; margin -- points minus what that trick is typically worth (see bias) --
; is scored.  A hand worth little in every open trick therefore scratches
; the cheapest one, and a Chance or three-of-a-kind is not wasted on a
; hand that is better spent elsewhere.
;
; Scorecard: 13 bytes, 0 = trick still open, else $80 | points (so a trick
; scratched for 0 points is still marked as used).  Trick numbers:
;   0-5 ones..sixes   6 three of a kind   7 four of a kind   8 full house
;   9 small straight  10 large straight   11 yahtzee           12 chance
;
; Memory (kim.cfg): the engine lives in MAIN ($0200), the scoring routines
; and a few small helpers in PAGE1 ($0100, well below the top of the stack),
; the lookup tables in zero page (ZPDATA).  Load all three binaries and
; start at $0200.
;
; The random number subroutine is Jim Butterfield's, from KIM User Notes #1,
; page 4.  It is also called on every refresh pass, so the sequence depends
; on how long the player takes to press keys.

        .include "kim.inc"

; ---- tunables ---------------------------------------------------------
dwell     = 100         ; per-digit on-time: 5 cycles per count, ~0.5 ms at 1 MHz
flash_bit = $40         ; frame bit that gates flashing: $40 = ~2.5 Hz
lock_n    = 8           ; refresh passes to ignore keys after any key change
pause_rounds = 3        ; pause after the last roll, units of 256 passes (~0.85 s)
; reveal times (tstoptab below) are in ticks of 8 refresh passes (~26 ms)

; ---- segment patterns -------------------------------------------------
seg_top = $63           ; segments a,b,f,g
seg_bot = $5c           ; segments g,c,d,e  (also lowercase "o")

; glyphs for the trick names (a=$01 b=$02 c=$04 d=$08 e=$10 f=$20 g=$40).
; a lowercase letter in a name below is the lowercase glyph.
sg_sp   = $00
sg_dash = $40
sg_1    = $06
sg_2    = $5b
sg_3    = $4f
sg_4    = $66
sg_5    = $6d
sg_6    = $7d
sg_S    = $6d           ; same shape as 5
sg_o    = $5c
sg_F    = $71
sg_U    = $3e
sg_L    = $38
sg_t    = $78
sg_r    = $50
sg_C    = $39
sg_h    = $74
sg_n    = $54
sg_c    = $58
sg_Y    = $6e
sg_A    = $77
sg_H    = $76

; ---- zero page variables ------------------------------------------------
        .zeropage
dbuf:      .res 6       ; segment pattern per digit, leftmost first
dice:      .res 5       ; die values 1-6
tcnt:      .res 5       ; tumble countdown per die
tstop:     .res 5       ; ticks until each tumbling die is revealed
counts:    .res 7       ; counts[1..6] = how many dice show each face
score:     .res 13      ; scorecard, see "Scorecard" above
rnd:       .res 6       ; Butterfield's generator state
jvec:      .res 2       ; indirect jump vector
frame:     .res 1       ; incremented once per refresh pass
flashmask: .res 1       ; bit n set = digit n flashes (bit 0 = leftmost)
blankbits: .res 1
waitcnt:   .res 1
tmask:     .res 1       ; dice still tumbling
lastkey:   .res 1
lockout:   .res 1
rollnum:   .res 1       ; rolls done in this hand (1..3)
dsum:      .res 1       ; sum of the five dice
present:   .res 1       ; bit n set = face n+1 appears (for the straights)
sqsum:     .res 1       ; sum of the squares of counts[1..6]
best:      .res 1       ; best margin so far this evaluation (biased, see bias)
bestslot:  .res 1       ; its trick number
bestpts:   .res 1       ; its points
slot:      .res 1
pts:       .res 1       ; points the trick being tried is worth
tmp:       .res 1
pcount:    .res 1

; ---- lookup tables (zero page: shorter and faster to index) -------------
        .segment "ZPDATA" : zeropage
seg_round:                                  ; index = rollnum
        .byte $00,$40,$09,$49               ; -  =  and three bars
seg_digit:
        .byte $00,$06,$5b,$4f,$66,$6d,$7d   ; blank,1..6
bitval: .byte $01,$02,$04,$08,$10,$20
tperiod:.byte 30,41,35,47,38                ; refresh passes per square flip
tstart: .byte seg_top,seg_bot,seg_bot,seg_top,seg_bot
tstoptab: .byte 32,40,48,56,64              ; ticks before each die is revealed
; 64 - typical points for each trick: ones..sixes use "three of each face"
; (3,6,9,12,15,18) to aim at the 63-point upper bonus; the rest are about
; what each trick is worth over a game (3K 22, 4K 13, full 23, small 29,
; large 33, yahtzee 17, chance 22)
bias:   .byte 61,58,55,52,49,46
        .byte 42,51,41,35,31,47,42
trick_lo: .byte <test_3kind,<test_4kind,<test_full,<test_small
          .byte <test_large,<test_yahtzee,<test_chance      ; tricks 6..12
trick_hi: .byte >test_3kind,>test_4kind,>test_full,>test_small
          .byte >test_large,>test_yahtzee,>test_chance
; what the left four digits say about the trick just scored, 4 bytes each,
; in trick-number order
names:  .byte sg_1,sg_dash,sg_S,sg_sp           ; 1-S
        .byte sg_2,sg_dash,sg_S,sg_sp           ; 2-S
        .byte sg_3,sg_dash,sg_S,sg_sp           ; 3-S
        .byte sg_4,sg_dash,sg_S,sg_sp           ; 4-S
        .byte sg_5,sg_dash,sg_S,sg_sp           ; 5-S
        .byte sg_6,sg_dash,sg_S,sg_sp           ; 6-S
        .byte sg_3,sg_sp,sg_o,sg_F              ; 3 oF
        .byte sg_4,sg_sp,sg_o,sg_F              ; 4 oF
        .byte sg_F,sg_U,sg_L,sg_L               ; FULL
        .byte sg_S,sg_S,sg_t,sg_r               ; SStr
        .byte sg_L,sg_S,sg_t,sg_r               ; LStr
        .byte sg_Y,sg_A,sg_H,sg_t               ; YAHt
        .byte sg_C,sg_h,sg_n,sg_c               ; Chnc

; ===== PAGE1: scoring and a few small helpers ===========================
        .segment "PAGE1"

; ---- wait: a = number of refresh passes --------------------------------
wait:   sta waitcnt
@l:     jsr refresh
        dec waitcnt
        bne @l
        rts

; ---- set_round: show rollnum (1..3) in digit 6 --------------------------
; clobbers a,y.
set_round:
        ldy rollnum
        lda seg_round,y
        sta dbuf+5
        rts

; ---- clear_card: every trick open ------------------------------------------
clear_card:
        ldx #12
        lda #0
@c:     sta score,x
        dex
        bpl @c
        rts

; ---- tally: dice -> counts[1..6], dsum, present, sqsum ----------------------
; sqsum (the sum of the squares of the counts) identifies the shape of the
; hand: five alike 25, four alike 17, full house 13, three alike 11, and
; 9 or less for anything else.
tally:  ldx #6
        lda #0
@z:     sta counts,x
        dex
        bpl @z
        sta dsum
        sta present
        sta sqsum
        ldy #4
@d:     ldx dice,y              ; x = face 1..6
        lda counts,x            ; k dice already show this face
        asl                     ; the sum of squares grows by 2k+1
        adc #1                  ; (carry stays clear: k <= 4)
        adc sqsum
        sta sqsum
        inc counts,x
        txa
        clc
        adc dsum
        sta dsum
        lda bitval-1,x
        ora present
        sta present
        dey
        bpl @d
        rts

; ---- trick routines: a = points this hand is worth in that trick ----------
; they read counts, dsum, present and sqsum (call tally first).
; clobber x,y,tmp.

; test_upper: y = face 1..6 -> a = (dice showing that face) * face
test_upper:
        sty tmp
        lda #0
        ldx counts,y
        beq @done
@add:   clc
        adc tmp
        dex
        bne @add
@done:  rts

test_3kind:
        lda #0
        ldx sqsum
        cpx #11
        bcc @r
        lda dsum
@r:     rts

test_4kind:
        lda #0
        ldx sqsum
        cpx #17
        bcc @r
        lda dsum
@r:     rts

test_full:                      ; three of one face and two of another
        lda #0
        ldx sqsum
        cpx #13
        bne @r
        lda #25
@r:     rts

test_yahtzee:
        lda #0
        ldx sqsum
        cpx #25
        bne @r
        lda #50
@r:     rts

; has_run: a = run pattern (faces 1.. as bits 0..), x = positions to slide it
; through -> carry set if present contains the pattern at some position
has_run:
        sta tmp
@t:     lda present
        and tmp
        cmp tmp
        beq @yes
        asl tmp
        dex
        bne @t
        clc
        rts
@yes:   sec
        rts

test_small:                     ; four in a row: 1234, 2345 or 3456
        lda #$0f
        ldx #3
        jsr has_run
        lda #0
        bcc @r
        lda #30
@r:     rts

test_large:                     ; five in a row: 12345 or 23456
        lda #$1f
        ldx #2
        jsr has_run
        lda #0
        bcc @r
        lda #40
@r:     rts

test_chance:
        lda dsum
        rts

; ---- call_trick: x = trick number -> a = points ---------------------------
call_trick:
        cpx #6
        bcs @table
        txa
        tay
        iny                     ; y = face
        jmp test_upper
@table: lda trick_lo-6,x
        sta jvec
        lda trick_hi-6,x
        sta jvec+1
        jmp (jvec)              ; the routine's rts returns to our caller

; ===== MAIN: engine and game loop =======================================
        .code

        jmp main

; ---- refresh: one multiplex pass over all six digits -------------------
; clobbers a,x,y,blankbits.  increments frame.
refresh:
        lda #$7f
        sta SADD                ; port a = segment outputs
        lda frame
        and #flash_bit
        beq @on                 ; a = 0: nothing blanked this phase
        lda flashmask           ; "off" phase: flashing digits are blanked
@on:    sta blankbits
        ldy #0
        ldx #$09                ; SBD value for digit 1; +2 per digit
@digit: lsr blankbits           ; carry = blank this digit
        lda #0
        bcs @out
        lda dbuf,y
@out:   stx SBD
        sta SAD
        sec
        lda #dwell
@w:     sbc #1
        bne @w
        lda #0
        sta SAD                 ; blank before moving on (no ghosting)
        inx
        inx
        iny
        cpy #6
        bne @digit
        stx SBD                 ; x = $15: selects no digit, so the floating
        lda #0                  ; port a lines can't light digit 6 faintly
        sta SADD                ; port a back to inputs for the keypad scan
        inc frame
        jmp rand                ; stir the generator; its rts returns for us

; ---- rand: Jim Butterfield, KIM User Notes #1, page 4 -------------------
; returns a = new random byte.  clobbers x.
rand:   sec
        lda rnd+1
        adc rnd+4
        adc rnd+5
        sta rnd
        ldx #4
@move:  lda rnd,x
        sta rnd+1,x
        dex
        bpl @move
        rts

; ---- rand_die: a = 1..6 (rejection sampling of 3 bits) -------------------
; clobbers x.
rand_die:
@again: jsr rand
        and #7
        beq @again
        cmp #7
        beq @again
        rts

; ---- poll_key: a = new key code, or KEY_NONE ---------------------------
; reports each press once.  after any change (press or release) keys are
; ignored for lock_n passes, which handles contact bounce.
; call it once per refresh pass.
poll_key:
        lda lockout
        beq @scan
        dec lockout
        lda #KEY_NONE
        rts
@scan:  jsr GETKEY
        cmp #KEY_NONE
        beq @up
        cmp lastkey
        beq @held
        sta lastkey
        ldx #lock_n
        stx lockout
        rts                     ; new press
@held:  lda #KEY_NONE
        rts
@up:    ldx lastkey
        sta lastkey             ; a = KEY_NONE
        cpx #KEY_NONE
        beq @done
        ldx #lock_n             ; just released
        stx lockout
@done:  rts

; ---- show_dice: dice[0..4] -> dbuf[0..4]; dbuf[5] untouched -------------
show_dice:
        ldx #4
@l:     ldy dice,x
        lda seg_digit,y
        sta dbuf,x
        dex
        bpl @l
        rts

; ---- tumble: a = mask of dice to animate (bit 0 = die 1) ----------------
; squares bounce between top and bottom, each die at its own rate.  each die
; also has a stop time (tstoptab, left to right increasing); when it runs
; out, that die is revealed as the value already in dice[] while the others
; keep tumbling.  returns when all dice in the mask have been revealed.
; dice not in the mask keep their dbuf contents.  caller should have
; flashmask clear.
tumble:
        sta tmask
        ldx #4
@init:  lda tperiod,x
        sta tcnt,x
        lda tstoptab,x
        sta tstop,x
        lda tmask
        and bitval,x
        beq @skip
        lda tstart,x
        sta dbuf,x
@skip:  dex
        bpl @init
@pass:  jsr refresh
        ldx #4
@die:   lda tmask
        and bitval,x
        beq @next
        dec tcnt,x              ; flip the square at this die's own rate
        bne @tick
        lda tperiod,x
        sta tcnt,x
        lda dbuf,x
        eor #(seg_top ^ seg_bot)
        sta dbuf,x
@tick:  lda frame
        and #7
        bne @next               ; a tick is every 8th pass
        dec tstop,x
        bne @next
        lda tmask               ; stop time reached: reveal this die
        eor bitval,x            ; (its bit is known to be set)
        sta tmask
        ldy dice,x
        lda seg_digit,y
        sta dbuf,x
@next:  dex
        bpl @die
        lda tmask
        bne @pass
        rts

; ---- roll: a = mask of dice to roll (bit 0 = die 1) ----------------------
; picks the new values now, tumbles, and reveals them left to right.
roll:   sta tmask
        ldy #4
@l:     lda tmask
        and bitval,y
        beq @n
        jsr rand_die            ; clobbers a,x only
        sta dice,y
@n:     dey
        bpl @l
        lda tmask
        jmp tumble

; ---- evaluate: score the current dice into the best open trick -------------
; margin = points + bias[trick], bias = 64 - typical points, so the compare
; stays unsigned.  highest margin wins (ties: lowest trick number).
; a = points scored.  if the card is already full, starts a new game first.
evaluate:
        jsr tally
        lda #0
        sta best                ; every margin is >= 31, so the first open
        lda #$ff                ; trick always becomes the leader
        sta bestslot
        ldx #12                 ; downward, so '>=' leaves ties to the lowest
@slot:  lda score,x
        bne @skip               ; used
        stx slot
        jsr call_trick
        sta pts
        ldx slot
        clc
        adc bias,x
        cmp best
        bcc @low
        sta best
        stx bestslot
        lda pts
        sta bestpts
@low:   ldx slot
@skip:  dex
        bpl @slot
        ldy bestslot
        bpl @store
        jsr clear_card          ; no open trick: new game, score again
        jmp evaluate
@store: lda bestpts
        ora #$80
        sta score,y
        lda bestpts
        rts

; ---- show_score: a = 0..99 points of trick bestslot ------------------------
; left four digits: the trick's name; right two: the points, with no
; leading zero.
show_score:
        ldx #0                  ; x = tens
@t:     cmp #10
        bcc @done
        sbc #10
        inx
        bne @t
@done:  tay                     ; y = ones
        txa
        beq @s                  ; no tens: leave the digit blank (a = 0)
        lda TABLE,x
@s:     sta dbuf+4
        lda TABLE,y
        sta dbuf+5
        lda bestslot            ; the name: 4 bytes at names + 4 * trick
        asl
        asl
        tax
        ldy #0
@n:     lda names,x
        sta dbuf,y
        inx
        iny
        cpy #4
        bne @n
        rts

; ---- game loop ------------------------------------------------------------
main:
        lda #0
        sta frame
        sta flashmask
        sta lockout
        sta dbuf+5
        jsr clear_card          ; new game
        lda #KEY_NONE
        sta lastkey
        ldx #4
        lda #$40
@dash:  sta dbuf,x              ; "-----": waiting for GO
        dex
        bpl @dash

@wait:  jsr refresh             ; the wait for GO also stirs the generator
        jsr poll_key
        cmp #KEY_GO
        bne @wait

@hand:  lda #1
        sta rollnum
        jsr set_round
        lda #$1f
        jsr roll                ; deal: all five dice

@loop:  jsr refresh
        jsr poll_key
        cmp #KEY_NONE
        beq @loop
        cmp #KEY_DA
        beq @da
        cmp #1
        bcc @loop               ; key 0: ignore
        cmp #6
        bcs @loop               ; keys 6..$10 etc: ignore
        tax
        dex                     ; x = 0..4
        lda flashmask
        eor bitval,x
        sta flashmask
        jmp @loop

@da:    lda flashmask
        beq @score              ; nothing selected: this hand is final
        pha
        lda #0
        sta flashmask
        inc rollnum
        jsr set_round
        pla
        jsr roll
        lda rollnum
        cmp #3
        bcc @loop               ; rolls remain: back to hold selection

@score: jsr evaluate            ; a = points for the best open trick
        pha
        lda #pause_rounds
        sta pcount
@pause: lda #0
        jsr wait                ; 256 refresh passes: let the hand sink in
        dec pcount
        bne @pause
        pla
        jsr show_score
@next:  jsr refresh
        jsr poll_key
        cmp #KEY_DA
        bne @next
        jmp @hand
