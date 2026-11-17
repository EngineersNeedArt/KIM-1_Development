; ---------------------------------------------------------------------------
; BASEBALL for the KIM-1  --  disassembly of the three paper tapes
;
; Original program: Robert "Bob" Leedom, KIM-1/6502 User Notes #16 (hex only).
; Claude disassembled/commented from the tapes bb_zero / bb_100 / bb_1780.
; Assembles with ca65 (plain 6502) and the kim.inc. Identical to the 
; tapes except that three stray tape bytes outside the user area are dropped: 
; $00EF (monitor PCL), and $17E6-$17EF (the last is monitor RAM).
;
; How to play
;   Start at $0200.  Display: digit 0 (left) is the batter, digit 5 (right)
;   is the pitcher; the ball crosses the display right to left as one lit
;   segment at low/middle/high height.
;   Swing with DA ($11) while the ball is in the MIDDLE row on digit 0.
;   Timing inside that frame picks the result: dead centre = HOMEr, then
;   triPLE, FLyout, douBLE, POPUP, SinGLE, FOUL at the edges.
;   play_mode ($2C): 0 = one-player batting practice (computer pitches, you bat
;   nine innings), 1..$7F = two players, pitcher presses keys 0-5,
;   $80+ = pitcher uses switches on the application connector.
;   Pitches: 0 slow, 1 fast, 2 up-curve, 3 down-curve, 4 riser, 5 sinker.
;   Scoreboard: [team][inning][outs][bases][balls][strikes]; bases are drawn
;   on one digit: bottom bar = 1st, middle = 2nd, top = 3rd.
;
; Memory
;   $0000-$00EF  variables, tables, 7-segment messages, idle-spinner code
;   $0100-$03FF  main program
;   $1780-$17EF  helper routines (high RAM of the second 6530)
;   $00EF-$00F4  reused as a 6-entry ball-height buffer ("traj"); this is
;                the monitor's PC/P/SP/A/Y/X save area, harmless here.
;
; The program runs in decimal mode (SED) almost everywhere.
; ---------------------------------------------------------------------------

        .include "kim.inc"

; --- zero-page variables ---------------------------------------------------
half        = $00           ; $0A = top ("A", visitors), $0B = bottom ("b")
inning      = $01           ; BCD
outs        = $02
swing       = $03           ; $FF = no swing yet; else bat has been swung
balls       = $04
strikes     = $05
result      = $06           ; $FD foul, $FE popup, $FF flyout, 0..3 = 1B..HR
half_frame  = $07           ; frame length / 2 (clobbered by classify_timing)
delay       = $08
tmp         = $09           ; scratch; also a random 0/1 (caught / dropped)
bat_seg     = $0A           ; bat segments on digit 0: $30 = back, $06 = swung
frame       = $0B           ; ball position, 5 (pitcher) .. 0 (batter)
sbuf        = $0C           ; scoreboard buffer $0C-$11
timing_bits = $12
bitmask     = $13           ; also the phase of the idle spinner
rng         = $14           ; $14-$19 random state
bases       = $1A           ; bit3 batter, bit2 1st, bit1 2nd, bit0 3rd
runs_vis    = $1B           ; BCD
runs_home   = $1C           ; BCD
runs_base   = runs_vis-$0A  ; indexed by "half" ($0A/$0B)
frame_len   = $1D           ; display scans per ball position
game_over   = $1E
disp        = $1F           ; 6-digit display buffer $1F-$24
save_y      = $25
msg_ptr     = $26           ; ($26/$27) pointer into page zero ($27 is always 0)
traj        = PCL           ; $EF-$F4 (PCL..YREG): ball height (0..3) at each digit

; ===========================================================================
; Page zero: tables and messages
; ===========================================================================
        .segment "ZPDATA" : zeropage

        .res    $27, 0                  ; $00-$26 variables (zero on tape)

; ball height -> segment.  Entry 0 (the byte at $27) doubles as the high byte
; of msg_ptr, which is why it must stay 0.
height_seg:
        .byte   $00, $08, $40, $01      ; none, low (d), middle (g), high (a)
ext_swing:
        .byte   $01                     ; bit 7 set: PA7 on the connector also swings
play_mode:
        .byte   $00                     ; see header

outcome_tbl:                            ; indexed by quantised timing 0..8
        .byte   $fd, $00, $00, $00, $fe, $01, $ff, $02, $03
out_msg_tbl:                            ; reached as hit_msg_tbl,x with X=$FD..$FF (zp wrap)
        .byte   <msg_foul, <msg_popup, <msg_flyout
hit_msg_tbl:
        .byte   <msg_single, <msg_double, <msg_triple, <msg_homer
catch_msg_tbl:
        .byte   <msg_missed, <msg_caught
unused_3f:                              ; not referenced by any code
        .byte   <msg_score2, <msg_runs
bases_seg:                              ; indexed by bases AND 7
        .byte   $00, $01, $40, $41, $08, $09, $48, $49

; Pitch / hit descriptors.  Indexed 0..5 (pitch), +6 for the alternate
; variant, and $0C..$12 for the six hit results (foul..HR).
;   speed byte: bits 7-3 = frame_len, bits 1-0 = height at digit 5,
;               bits 3-2 = height at digit 4  (bit 3 is shared)
;   path byte : 2-bit heights for digits 0..3, digit 0 in bits 7-6
pitch_speed:
        .byte   $3a, $1a, $2a, $2a, $25, $2f
        .byte   $3a, $1a, $2a, $2a, $25, $2f
hit_speed:
        .byte   $20, $20, $24, $24, $29, $2e, $2f
pitch_path:
        .byte   $aa, $aa, $af, $a5, $a9, $ab
        .byte   $fa, $5a, $ff, $55, $f9, $5b
hit_path:
        .byte   $29, $2d, $2f, $2a, $2f, $2b, $2b

; 7-segment text.  Each message is 6 bytes copied to the display by show_msg.
        .charmap 32,  $00               ; ' '
        .charmap 65,  $77               ; A
        .charmap 98,  $7c               ; b
        .charmap 66,  $7c               ; B
        .charmap 67,  $39               ; C
        .charmap 100, $5e               ; d
        .charmap 69,  $79               ; E
        .charmap 70,  $71               ; F
        .charmap 71,  $3d               ; G
        .charmap 72,  $76               ; H
        .charmap 73,  $06               ; I
        .charmap 105, $04               ; i
        .charmap 76,  $38               ; L
        .charmap 77,  $37               ; M
        .charmap 110, $54               ; n
        .charmap 79,  $3f               ; O
        .charmap 111, $5c               ; o
        .charmap 80,  $73               ; P
        .charmap 114, $50               ; r
        .charmap 83,  $6d               ; S
        .charmap 116, $78               ; t
        .charmap 85,  $3e               ; U
        .charmap 117, $1c               ; u
        .charmap 89,  $6e               ; Y
        .charmap 121, $6e               ; y
        .charmap 126, $63               ; ~ (small box)

msg_score2:     .byte   "  to  "       ; digits patched in: "vv to hh"
msg_runs:       .byte   "  runS"       ; digits patched in: "nn runS"
msg_ball:       .byte   "bALL  "       ; digit patched into last byte
msg_strike:     .byte   "Str   "       ; digit patched into last byte
msg_caught:     .byte   "CAUGHt"
msg_missed:     .byte   "MISSEd"
msg_yer_out:    .byte   "YErout"
msg_outs:       .byte   $00, $00, $00   ; digit patched into 2nd byte
                .byte   "out"
msg_popup:      .byte   "POPUP"         ; 6th byte is the blank at msg_foul
msg_foul:       .byte   " FOUL"         ; 6th byte is the blank at msg_homer
msg_homer:      .byte   " HOMEr"
msg_flyout:     .byte   "FLyout"
msg_single:     .byte   "SinGLE"
msg_double:     .byte   "douBLE"
msg_triple:     .byte   "triPLE"
msg_dbl_play:   .byte   "dbL PL"
msg_boxes:      .byte   "~~~~~~"        ; game over

; Idle spinner: batter waits on the left while a single segment circles
; on the pitcher's digit.  Called repeatedly while waiting for a pitch.
idle_spin:
        lsr     bitmask
        bne     @ok
        lda     #$20
        sta     bitmask
@ok:    jsr     draw_frame
        lda     bitmask
        sta     disp+5
        lda     #$30
        sta     disp
        ldy     #7
@scan:  jsr     scan_key
        dey
        bne     @scan
        rts

; ===========================================================================
; Main program
; ===========================================================================
        .segment "PAGE1"

; show_msg: Y = page-zero offset of a 6-byte message.  Shows it for about
; 0x181 display scans.  Falls through into scan_key for the last scan.
show_msg:
        sty     msg_ptr
        ldy     #5
@copy:  lda     (msg_ptr),y
        sta     disp,y
        dey
        bpl     @copy
        ldy     #$c0
@hold:  jsr     scan_key
        jsr     scan_key
        dey
        bne     @hold

; scan_key: show disp[0..5] once and read the keypad.  Returns A = key.
scan_key:
        sty     save_y
        ldy     #0
        lda     #$7f
        sta     SADD
        ldx     #9
@dig:   sty     TEMP                    ; OUTPUT restores Y from TEMP
        lda     disp,y
        jsr     OUTPUT
        iny
        cpy     #6
        bcc     @dig
get_key:
        jsr     KEYTS
        jsr     GETKEY
        ldy     save_y
        rts

        nop                             ; $0138: unreferenced

; set_traj: X = pitch/hit index.  Loads frame_len, half_frame and traj[].
; set_traj_start also sets the starting ball position from A.
set_traj_start:
        sta     frame
set_traj:
        lda     pitch_speed,x
        pha
        pha
        and     #$f8
        nop                             ; spare byte (patched-out instruction?)
        sta     frame_len
        lsr     a
        sta     half_frame
        pla
        and     #3
        sta     traj+5
        pla
        lsr     a
        lsr     a
        and     #3
        sta     traj+4
        lda     pitch_path,x
        ldx     #3
@loop:  pha
        and     #3
        sta     traj,x
        pla
        lsr     a
        lsr     a
        dex
        bpl     @loop
        rts

; draw_frame: clear the display, draw the ball at digit "frame".  Returns
; Y = frame_len (scans to hold this position).
draw_frame:
        lda     #0
        ldx     #5
@clr:   sta     disp,x
        dex
        bpl     @clr
        ldx     frame
        ldy     traj,x
        lda     height_seg,y
        sta     disp,x
        ldy     frame_len
        rts

; advance_runners: shift the bases Y+1 times (batter included).  Any runner
; shifted past third scores.  Walks use Y=0 and move EVERY runner up one base,
; forced or not.  Home team taking the lead from the 9th on ends the game.
advance_runners:
        ldx     #0
@shift: lsr     bases
        bcc     @next
        ldx     half
        lda     runs_base,x
        adc     #0
        sta     runs_base,x
        cpx     #$0b
        bne     @next
        lda     inning
        cmp     #9
        bcc     @next
        lda     runs_vis
        cmp     runs_home
        bcs     @next
        stx     game_over               ; walk-off
        bne     show_runs
@next:  dey
        bpl     @shift
        txa
        beq     run_rts                 ; nobody scored: no message

; show_runs: "nn runS" (one player) or "vv to hh" (two players).
show_runs:
        lda     runs_vis
        jsr     hex_to_seg
        ldx     play_mode
        beq     @one
        sty     msg_score2
        sta     msg_score2+1
        lda     runs_home
        jsr     hex_to_seg
        sty     msg_score2+4
        sta     msg_score2+5
        ldy     #msg_score2
        bne     @show
@one:   sty     msg_runs
        sta     msg_runs+1
        ldy     #msg_runs
@show:  jsr     show_msg
run_rts: rts

; classify_timing: Y = scans left in the current frame at the moment of the
; swing.  A = distance from the nearest frame edge, greedily quantised into
; four bits (weights 28/14/7/3 for a 56-scan frame) -> index 0..8 into
; outcome_tbl.  Returns A = result code.
classify_timing:
        sty     tmp
        tya
        cld
        cmp     half_frame
        bcc     @lo
        lda     frame_len
        sbc     tmp
@lo:    ldx     #8
        stx     bitmask
@bit:   cmp     half_frame
        bcc     @skip
        sbc     half_frame
        pha
        lda     timing_bits
        ora     bitmask
        sta     timing_bits
        pla
@skip:  lsr     half_frame
        lsr     bitmask
        bne     @bit
        ldx     timing_bits
        lda     outcome_tbl,x
        rts

        ; $01ED-$01FF: unreferenced debris (a stray RTS and leftover bytes)
        .byte   $60, $17, $a4, $aa, $17, $a4, $aa, $70
        .byte   $1f, $70, $1f, $70, $00, $00, $00, $98
        .byte   $00, $35, $00

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
        .segment "CODE"

entry:                                  ; $0200
        lda     TIMER_READ
        sta     rng+1                   ; seed
new_game:                               ; $0205
        sed
        lda     #$0b
        sta     half
        lda     #0
        sta     game_over
        sta     inning
        sta     runs_vis
        sta     runs_home
next_half:                              ; $0214
        lda     half
        eor     #1
        sta     half
        cmp     #$0a
        bne     new_side
new_inning:                             ; $021E  (also used each inning in 1P)
        clc
        lda     inning
        adc     #1
        sta     inning
new_side:                               ; $0225
        lda     #0
        sta     outs
        sta     bases
next_batter:                            ; $022B
        lda     #0
        sta     balls
        sta     strikes
        lda     bases
        ora     #$08                    ; batter at the plate
        sta     bases
next_pitch:                             ; $0237
        lda     #0
        sta     timing_bits
        sta     bitmask
        lda     #5
        sta     frame
        jsr     show_board
        lda     play_mode
        beq     wait_random
pitcher_poll:                           ; $0248
        lda     play_mode
        bpl     keypad_pitcher
        jsr     read_port               ; switches: PA0 = throw,
        lsr     a                       ; PA1.. = pitch, counted in 1s
        bcc     idle_loop
        and     #$1f
        ldx     #0
@cnt:   lsr     a
        bcc     pitch_selected
        inx
        bpl     @cnt
keypad_pitcher:                         ; $025C
        jsr     get_key
        cmp     #6
        tax
        bcc     pitch_selected          ; keys 0-5 = pitch type
idle_loop:                              ; $0264
        jsr     idle_spin
        jsr     poll_hotkeys
        bcs     pitcher_poll

wait_random:                            ; $026C  computer pitches
        jsr     rand
        and     #$7f
        ora     #$20
        sta     delay
@wait:  jsr     idle_spin
        jsr     poll_hotkeys
        dec     delay
        bne     @wait
        jsr     rand
        and     #7
        cmp     #6
        bcc     @ok
        sbc     #6
@ok:    tax                             ; pitch type 0..5

pitch_selected:                         ; $028B
        jsr     rand
        and     #7
        cmp     #3
        bcs     @variant_a              ; 5/8: normal path
        tay
        txa
        bne     @variant_b
        tya
        bne     @variant_a
@variant_b:
        inx                             ; +6: alternate (often out-of-zone) path
        inx
        inx
        inx
        inx
        inx
@variant_a:
        jsr     set_traj
        lda     #$ff
        sta     swing
        lda     #$30
        sta     bat_seg
next_frame:                             ; $02AC  ball moves one digit
        jsr     draw_frame
@scan:  jsr     scan_key                ; A = key
        ldx     swing
        bpl     @drawbat                ; already swung
        cmp     #KEY_DA
        beq     @swing
        lda     ext_swing
        bpl     @drawbat
        jsr     read_port
        bpl     @drawbat
@swing: lda     #6                      ; bat forward
        sta     bat_seg
        lda     disp
        asl     a
        bmi     contact                 ; ball in middle row on digit 0
        sta     swing                   ; swung and missed
@drawbat:
        lda     disp
        and     #$49
        ora     bat_seg
        sta     disp
        dey
        bne     @scan
        lda     swing
        bpl     strike_tramp
        dec     frame
        bpl     next_frame
        lda     traj                    ; ball reached batter, no swing:
        cmp     #2
        beq     strike_tramp            ; middle row = called strike
        inc     balls
        ldx     balls
        lda     TABLE,x
        sta     msg_ball+5
        ldy     #msg_ball
        jsr     show_msg
        lda     balls
        cmp     #4
        bne     next_pitch_tramp
        ldy     #0                      ; walk
runners:                                ; $02FD  (hits enter with Y = bases-1)
        jsr     advance_runners
        lda     game_over
        beq     @cont
        jmp     end_half
@cont:  jmp     next_batter
strike_tramp:                           ; $030A
        jmp     strike

contact:                                ; $030D
        jsr     classify_timing
        sta     result
        clc
        adc     #$0f
        tax
        sed
        lda     #1                      ; ball flies from digit 1 outward
        jsr     set_traj_start
@fly:   jsr     draw_frame
        lda     #6
        sta     disp
@fscan: jsr     scan_key
        dey
        bne     @fscan
        inc     frame
        lda     frame
        cmp     #6
        bne     @fly
        ldx     result
@show:  ldy     hit_msg_tbl,x           ; $0333  (re-entered with X=0 = single)
        jsr     show_msg
        lda     #0
        sta     tmp
        jsr     rand
        and     #4
        beq     @c1
        inc     tmp                     ; random 0/1: caught or dropped
@c1:    ldy     result
        bpl     runners                 ; real hit
        iny
        bne     @notfly
        jmp     fly_out
@notfly:                                ; $034F  foul or popup
        ldx     tmp
        bne     @catch
        iny
        bmi     @foul_miss
@catch: ldy     catch_msg_tbl,x         ; $0356  CAUGHt / MISSEd
        jsr     show_msg
        ldx     tmp
        stx     result                  ; dropped popup becomes a single
        beq     @show
        bne     out
@foul_miss:                             ; $0363
        lda     strikes
        cmp     #2
        bne     strike
next_pitch_tramp:                       ; $0369
        jmp     next_pitch

strike:                                 ; $036C
        inc     strikes
        ldx     strikes
        lda     TABLE,x
        sta     msg_strike+5
        ldy     #msg_strike
        jsr     show_msg
        lda     strikes
        cmp     #3
        bne     next_pitch_tramp
        ldy     #msg_yer_out
        jsr     show_msg
out:                                    ; $0385
        inc     outs
        ldx     outs
        lda     TABLE,x
        sta     msg_outs+1
        ldy     #msg_outs
        jsr     show_msg
        lda     outs
        cmp     #3
        beq     end_half
        jmp     next_batter

end_half:                               ; $039C
        jsr     show_runs
        lda     game_over
        bne     game_end
        lda     inning
        cmp     #9
        bcs     @late
        lda     play_mode
        bne     @switch
        jmp     new_inning              ; 1P: same side bats again
@late:  lda     play_mode
        beq     game_end
        lda     half
        cmp     #$0b
        beq     @bottom
        lda     runs_vis                ; top of 9th+: home ahead -> over
        cmp     runs_home
        bcc     game_end
@switch:
        jmp     next_half
@bottom:
        lda     runs_vis                ; tied -> extra innings
        cmp     runs_home
        beq     @switch
game_end:                               ; $03C9
        jsr     poll_hotkeys
        ldy     #msg_boxes
        jsr     show_msg
        beq     end_half                ; Z set (Y=0): loops forever

; show_board: [team][inning][outs][bases][balls][strikes]
show_board:                             ; $03D3
        ldx     #5
@cp:    ldy     half,x
        lda     TABLE,y
        sta     sbuf,x
        dex
        bpl     @cp
        lda     inning
        cmp     #$0a
        bcc     @ok
        lda     #$79                    ; 'E' for innings 10+
        sta     sbuf+1
@ok:    lda     bases
        and     #7
        tax
        lda     bases_seg,x
        sta     sbuf+3
        lda     play_mode
        bne     @go
        lda     #0
        sta     sbuf                    ; 1P: no team letter
@go:    ldy     #sbuf
        jmp     show_msg

        .byte   $b3                     ; $03FF: stray byte

; ===========================================================================
; $1780: helper routines
; ===========================================================================
        .segment "HIGH"

; hex_to_seg: A = BCD byte -> Y = segments of high digit, A = low digit
hex_to_seg:
        pha
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        tax
        ldy     TABLE,x
        pla
        and     #$0f
        tax
        lda     TABLE,x
        rts

; poll_hotkeys: one display scan plus key test.  Returns carry set.
; NOTE: GETKEY never returns $20, $18 or $19, so as listed these three
; "hot keys" (scoreboard, score, new game) can never fire.
poll_hotkeys:
        jsr     scan_key
        cmp     #$20
        bne     @1
        jsr     show_board
@1:     cmp     #$18
        bne     @2
        jsr     show_runs
@2:     cmp     #$19
        bne     @3
        pla
        pla
        jmp     new_game
@3:     sec
        rts

; rand: A = next pseudo-random byte (lagged additive generator in $14-$19)
rand:
        sec
        cld
        lda     rng+1
        adc     rng+2
        adc     rng+5
        sta     rng
        ldy     #4
@sh:    lda     rng,y
        sta     rng+1,y
        dey
        bpl     @sh
        sed
        rts

; read_port: A = application-connector port A (all inputs)
read_port:
        lda     #0
        sta     PADD
        lda     PAD
        rts

; fly_out: out in play.  Double play if (bases<<1 | outs) is $18 or $14,
; which with the OR only happens with NO outs.
fly_out:
        lda     bases
        asl     a
        ora     outs
        cmp     #$18
        beq     @dp
        cmp     #$14
        bne     @done
@dp:    ldy     #msg_dbl_play
        jsr     show_msg
        sty     bases                   ; Y = 0: bases cleared
        inc     outs                    ; extra out (the usual one is at out:)
@done:  jmp     out

