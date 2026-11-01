; ----------------------------------------------------------------------
; kim-tac-toe.s -- Tic-tac-toe for the KIM-1 / PAL-II
;
; ca65 version of the "Kim-Tac-Toe" listing from The First Book of KIM.
; Logic, register use and memory layout are identical to the original;
; only names, comments and syntax have been modernised.
;
; How to play
;   Run from $0100. "GO" = KIM moves first, "+" = you move first.
;   Display digits 2-4 show the board as a 3x3 grid, squares numbered
;       7 8 9
;       4 5 6
;       1 2 3
;   Your marks are steady, KIM's flicker.  A winning line blinks; a draw
;   blinks every square.  After a game "GO"/"+" starts another.  PC shows
;   "ODDS" and KIM's "I.Q." (initially $0C = 75%): key in a new value
;   ($00-$10), then DA to carry on.  I.Q. goes up when you win and down
;   when KIM wins.
;
; Memory
;   The program is 614 bytes and RAM is only $0000-$03FF, so it is split:
;   subroutines and tables at $0100 (bottom of the stack page), main
;   program filling $0200-$03FF.
; ----------------------------------------------------------------------

        .include "kim.inc"

; ---- Monitor entry not defined in kim.inc ---------------------------
; Entry in the middle of CONVD ($1F48): A = segment pattern, X = digit
; select ($09,$0B,...); the routine steps X on by 2 and restores Y from
; TEMP ($FC), which is why display saves Y there first.
OUTSEG          = $1F4E         ; CONVD + 6

; ---- Keypad codes returned by GETKEY (KEY_NONE is in kim.inc) --------
KEY_DA          = $11
KEY_PLUS        = $12
KEY_GO          = $13
KEY_PC          = $14

; ---- Zero page: program variables -----------------------------------
; (The monitor owns $EF-$FF, but TEMP at $FC is shared with display.)
play_no         = $b5           ; number of the current play, 1-9
odev            = $b6           ; odd/even modifier for random_play ...
play_order      = $b6           ; ... and base of the play-order table:
                                ;   [1-4] corners  [5] centre  [6-9] sides
side_order      = play_order + 5 ; sides = side_order+1 .. +4 ($bc-$bf)
board           = $c0           ; squares 1-9, one byte each ($c0-$c8)
square          = board - 1     ; same, indexed by square number 1-9
line_sum        = $c8           ; lines 1-8 at $c9-$d0, indexed 1-8:
                                ;   4 per KIM mark + 1 per player mark
delay           = $d1           ; KIM "thinking" delay counter
iq              = $d2           ; KIM's I.Q., $00-$10
rnd             = $d3           ; 6-byte random shift register ($d3-$d8)
scratch         = $d9           ; temporary
rate            = $da           ; flicker/blink phase counter
turn            = $db           ; 0 = player to move, 1 = KIM to move
play_stat       = $db           ; per-square counters, indexed 1-9 ($dc-$e4)

; ---- Square flags (in board) ---------------------------------------
SQ_BLINK        = $20           ; square is blinking (winning line/draw)
SQ_PLAYER       = $40           ; player's mark (steady)
SQ_KIM          = $80           ; KIM's mark (flicker)

; ---- Line totals: line_sum = 4*KIM marks + 1*player marks ----------
COUNT_PLAYER    = 1
COUNT_KIM       = 4
LINE_PLAYER_WIN = 3 * COUNT_PLAYER
LINE_KIM_WIN    = 3 * COUNT_KIM

; ---- Line patterns searched by load_stat -----------------------------
; Each pass records, per open square, how many lines through it have
; this total.  Pass 1 ends in bits 7-6 of play_stat, pass 4 in bits 1-0.
PAT_KIM_2       = 2 * COUNT_KIM         ; KIM has two, third is open
PAT_PLAYER_2    = 2 * COUNT_PLAYER      ; player has two, third is open
PAT_KIM_1       = 1 * COUNT_KIM         ; KIM has one, two are open
PAT_PLAYER_1    = 1 * COUNT_PLAYER      ; player has one, two are open

; ---- Masks for get_play (which play_stat bits to look for) ----------
MASK_KIM_WIN    = %11000000     ; pass 1: KIM can win
MASK_BLOCK      = %00110000     ; pass 2: player threatens to win
MASK_KIM_FORK   = %00001000     ; pass 3: square on 2+ of KIM's lines
MASK_PLAYER_FORK = %00000010    ; pass 4: square on 2+ of player's lines

; ---- Seven-segment display -------------------------------------------
SEG_A           = $01
SEG_D           = $08
SEG_G           = $40
DIGIT_2         = $0b           ; first of the 3 digits used (X value)
DIGIT_END       = $11           ; X value after the third digit
DISPLAY_DDR     = $7f           ; SADD: segments a-g as outputs

; ---- Misc -------------------------------------------------------------
IQ_START        = $0c           ; 75%
IQ_MAX          = $10
ODDS_DISPLAY    = $0dd5         ; shows as "ODDS" on the display


; ======================================================================
; Page 1: subroutines and tables
; ======================================================================
        .segment "LOWCODE"                      ; $0100

entry:                                          ; start the program here
        jmp     start_iq
        nop                                     ; spare
        nop
        nop

; ---- set_blink: flag square X as blinking ---------------------------
set_blink:
        lda     #SQ_BLINK
        ora     square,x
        sta     square,x
        rts

        nop                                     ; spare
        nop

; ---- Segment lit for each square (squares 1-9, zero-based) ----------
; Squares 1-3 share digits 2-4 with 4-6 and 7-9, so each digit shows
; one segment per row: bottom (d), middle (g), top (a).
seg_table:
        .byte   SEG_D, SEG_D, SEG_D
        .byte   SEG_G, SEG_G, SEG_G
        .byte   SEG_A, SEG_A, SEG_A

; ---- The 8 lines: 3 rows, 3 columns, 2 diagonals ----------------------
; Indexed 1-8 (hence the -1): first, second and third square of each.
;                 rows     columns  diagonals
line_sq1_tbl:   .byte 1,4,7, 1,2,3, 1,3
line_sq2_tbl:   .byte 2,5,8, 4,5,6, 5,5
line_sq3_tbl:   .byte 3,6,9, 7,8,9, 9,7
line_sq1        = line_sq1_tbl - 1
line_sq2        = line_sq2_tbl - 1
line_sq3        = line_sq3_tbl - 1

; ---- get_play: find a square whose play_stat has any bit in A -------
; In:  A = mask.   Out: X = square 1-9 (Z clear), or X = 0 (Z set).
get_play:
        sta     scratch
        ldx     #9
@loop:  lda     scratch
        and     play_stat,x                     ; mask the status byte
        bit     scratch                         ; any bit left?
        bne     @done                           ; yes - square in X
        dex
        bne     @loop
@done:  rts

; ---- test_inc: if square X is open, bump its play_stat ---------------
test_inc:
        lda     square,x
        bne     @done                           ; count open squares only
        inc     play_stat,x
@done:  rts

; ---- update: mark square X with flag A, then rebuild line_sum --------
update:
        sta     square,x
        ldy     #8
@line:  lda     #0
        sta     line_sum,y
        ldx     line_sq1,y
        jsr     add_square
        ldx     line_sq2,y
        jsr     add_square
        ldx     line_sq3,y
        jsr     add_square
        dey
        bne     @line
        rts


; ======================================================================
; Pages 2-3: main program
; ======================================================================
        .segment "CODE"                         ; $0200

; ---- new_game: clear state, build random play orders ----------------
new_game:
        lda     #0
        ldx     #delay - play_no + 1            ; clear $b5-$d1
@clear: sta     play_no - 1,x
        dex
        bne     @clear
        lda     #5
        sta     play_order + 5                  ; centre: fixed slot
        ldy     #4                              ; sides in random order
@side:  jsr     random_play
        ldx     #4
@chk_s: cmp     side_order,x
        beq     @side                           ; already used - retry
        dex
        bne     @chk_s
        sta     side_order,y
        dey
        bne     @side
        inc     odev                            ; now generate odd values
        ldy     #4                              ; corners in random order
@corner:
        jsr     random_play
        ldx     #5                              ; (includes the centre,
@chk_c: cmp     play_order,x                    ;  so 5 is never picked)
        beq     @corner
        dex
        bne     @chk_c
        sta     play_order,y
        dey
        bne     @corner

; ---- check for a win --------------------------------------------------
check_player:
        lda     #LINE_PLAYER_WIN
check_win:                                      ; A = total to look for
        ldy     #8
@line:  cmp     line_sum,y
        beq     @win                            ; found - blink the line
        dey
        bne     @line
        beq     check_draw                      ; no winner yet
@win:   ldx     line_sq1,y
        jsr     set_blink
        ldx     line_sq2,y
        jsr     set_blink
        ldx     line_sq3,y
        jsr     set_blink
        jmp     winner

; ---- check for a draw ------------------------------------------------
check_draw:
        ldx     #9
@open:  lda     #SQ_KIM | SQ_PLAYER
        and     square,x                        ; open square?
        beq     next_turn                       ; yes - game goes on
        dex
        bne     @open
        ldx     #9                              ; none open: draw,
@blink: jsr     set_blink                       ; blink them all
        dex
        bne     @blink
        jmp     done

; ---- next_turn: whose move? ------------------------------------------
next_turn:
        inc     play_no
        lda     turn
        bne     kim_move                        ; KIM's turn
@key:   jsr     get_key                         ; player's turn
        beq     @key                            ; no key 0
        cmp     #10
        bcs     @key                            ; ignore non-digits
        tax                                     ; square number
        ldy     square,x
        bne     @key                            ; occupied - try again
        lda     #SQ_PLAYER
        jsr     update
        inc     turn                            ; KIM next ...
        bne     check_player                    ; ... but check for a win

; ---- kim_move: KIM picks a square -------------------------------------
kim_move:
        jsr     display                         ; delay, so KIM seems
        inc     delay                           ; to think
        bne     kim_move
        lda     #PAT_KIM_2                      ; analyse the board
        jsr     load_stat
        lda     #PAT_PLAYER_2
        jsr     load_stat
        lda     #PAT_KIM_1
        jsr     load_stat
        lda     #PAT_PLAYER_1
        jsr     load_stat
        lda     #MASK_KIM_WIN                   ; win if possible
        jsr     get_play
        bne     play
        lda     #MASK_BLOCK                     ; else block the player
        jsr     get_play
        bne     play
        lda     #MASK_KIM_FORK                  ; else make a squeeze play
        jsr     get_play
        bne     play

        jsr     random                          ; how much smarts?
        and     #$0f
        cmp     iq
        bcs     dumb                            ; random >= I.Q.: poor move
        ldy     play_no                         ; smart
        cpy     #1
        bne     @not_1st
        and     #1                              ; 1st play: half the time
        bne     pick                            ; take a corner
@not_1st:
        cpy     #4
        bne     @not_4th
        bit     square + 5                      ; 4th play: who has centre?
        bmi     dumb                            ; KIM - play a side
        bvs     smart                           ; player - play a corner
@not_4th:
        lda     #MASK_PLAYER_FORK               ; block a player squeeze
        jsr     get_play
        bne     play
smart:  ldy     #5                              ; try centre, then corners
        bne     pick
dumb:   ldy     #9                              ; try sides first
pick:   ldx     play_order,y                    ; next square in the
        lda     square,x                        ; random-order table
        beq     play                            ; open - play it
        dey
        bne     pick
        beq     dumb                            ; ran out: start over
play:   lda     #SQ_KIM
        jsr     update
        dec     turn                            ; player's turn next
        lda     #LINE_KIM_WIN                   ; first, did KIM win?
        jmp     check_win

; ---- winner: adjust I.Q.; done: wait for a key ----------------------
winner:
        lda     turn
        bne     iq_up                           ; player won: raise I.Q.
iq_down:
        dec     iq                              ; KIM won: lower it,
        bpl     done                            ; but not below zero
iq_up:  inc     iq
        lda     #IQ_MAX                         ; nor above $10
        cmp     iq
        bcc     iq_down
        bcs     done
start_iq:
        lda     #IQ_START
        sta     iq
        cld
done:   jsr     get_key                         ; show result, get a key
        ldy     #1                              ; GO: KIM starts
        cmp     #KEY_GO
        beq     set_turn
        dey                                     ; "+": player starts
        cmp     #KEY_PLUS
        beq     set_turn
        cmp     #KEY_PC                         ; PC: change I.Q.
        bne     done
show_iq:
        lda     #>ODDS_DISPLAY                  ; display "ODDS" and I.Q.
        sta     POINTH
        lda     #<ODDS_DISPLAY
        sta     POINTL
        lda     iq
        sta     INH
        jsr     SCANDS
        jsr     KEYIN
        jsr     GETKEY
        cmp     #KEY_DA
        beq     done                            ; DA: back to done loop
        bcs     show_iq                         ; above DA: ignore
        sta     iq                              ; $00-$10: new I.Q.
        bcc     show_iq                         ; (always taken)
set_turn:
        sty     turn
        jmp     new_game
        nop                                     ; spare

; ---- display: one multiplexing pass over the board -------------------
; Squares 0-8 are drawn one segment at a time, three per digit.
; Player's marks are steady, KIM's flicker, blinking squares alternate.
display:
        lda     #DISPLAY_DDR
        sta     SADD                            ; open display channels
        inc     rate
        ldy     #0
@digit: ldx     #DIGIT_2
@seg:   lda     board,y                         ; control byte
        sta     TEMP
        beq     @off                            ; open square
        and     #SQ_BLINK
        beq     @flicker                        ; not blinking
        bit     rate
        bvs     @off                            ; blink: alternate on/off
@flicker:
        lda     TEMP
        and     #SQ_PLAYER
        bne     @on                             ; player: steady
        lda     rate
        and     #$08
        beq     @on                             ; KIM: flicker
@off:   lda     #0
        beq     @out
@on:    lda     seg_table,y
@out:   sty     TEMP                            ; the monitor restores Y
        jsr     OUTSEG                          ; show segment, X += 2
        iny
        cpy     #9
        beq     @last                           ; all squares done
        cpx     #DIGIT_END
        beq     @digit                          ; past last digit: wrap
        bne     @seg
@last:  rts

; ---- add_square: add square X's value into line_sum,y ----------------
add_square:
        lda     square,x
        sta     scratch
        bit     scratch                         ; whose square?
        bmi     @kim
        bvs     @player
        lda     #0                              ; open
        beq     @add
@kim:   lda     #COUNT_KIM
        bne     @add
@player:
        lda     #COUNT_PLAYER
@add:   clc
        adc     line_sum,y
        sta     line_sum,y
        rts

; ---- get_key: display until a key is pressed, return it in A and X ---
get_key:
@wait:  jsr     display
        jsr     KEYIN                           ; key down?
        beq     @wait
        jsr     GETKEY
        tax                                     ; recover the flags
        rts

; ---- random: 6-byte lagged-Fibonacci generator -----------------------
; New byte = rnd[1] + rnd[4] + rnd[5] + 1, shifted in at rnd[0].
random:
        cld
        sec
        lda     rnd + 1
        adc     rnd + 4
        adc     rnd + 5
        sta     rnd
        ldx     #4
@roll:  lda     rnd,x
        sta     rnd + 1,x
        dex
        bpl     @roll
        rts
        nop                                     ; spare

; ---- load_stat: count open squares fitting pattern A -----------------
; Shifts every play_stat up two bits, then for each line whose
; line_sum equals A, adds 1 to play_stat of each open square on it.
load_stat:
        sta     scratch
        ldx     #9
@shift: asl     play_stat,x                     ; move old data out
        asl     play_stat,x                     ; of the way
        dex
        bne     @shift
        ldy     #8
@line:  lda     scratch
        cmp     line_sum,y
        bne     @next
        ldx     line_sq1,y
        jsr     test_inc
        ldx     line_sq2,y
        jsr     test_inc
        ldx     line_sq3,y
        jsr     test_inc
@next:  dey
        bne     @line
        rts

; ---- random_play: random square number 1-9 --------------------------
; Even values while odev = 0, odd values once odev = 1.
random_play:
        jsr     random
        and     #$0e                            ; 0-14, even
        ora     odev                            ; make odd if odev = 1
        beq     random_play                     ; no zeros
        cmp     #10
        bcs     random_play                     ; 1-9 only
        rts
