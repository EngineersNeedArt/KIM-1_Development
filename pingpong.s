; pingpong.s -- PING PONG for the KIM-1
; From "The First Book of KIM".  Starts at $0200.
;
; Play against the computer, or change the program for a two-player game.
; On each shot, choose one of four plays: Spin, Lob, Block or Slam.
; The left player uses the left-hand keys, the right player the right-hand:
;
;       "C"  Slam   "F"
;       "8"  Block  "B"
;       "4"  Lob    "7"
;       "0"  Spin   "3"
;
; Each shot has its own strengths and weaknesses; a Slam is powerful but
; likely to be "fluffed".  The chance of success depends on the last two
; shots played, not just the one chosen.  The net is in the middle of the
; court: don't play the ball until it is on your side, or you lose the point.
; Spin lights the bottom segment, Lob the middle, Block the top; Slam lights
; all three and travels faster.
;
; Holding down any unused key ("AD", "5", ...) freezes the ball.
; To slow the ball, increase the speeds at SPD ($0331-$0334):
;   "40 40 40 28" halves the speed.
; Two-player game, KIM not playing the right side: set PRITE ($032C) to $01.
; KIM plays the left side: set PLEFT ($032B) to $00.
;
; The original was published for the HP-67 in "65 Notes", v4N2P5.
; Authorship was not given.

        .include "kim.inc"

        .org PROGRAM_ORG

; ---- Zero page ----
speed   = $80           ; speed ball travels
spot    = $81           ; segment(s) ball lights
log     = $82           ; record of recent plays
pause   = $83           ; delay before ball moves
direct  = $84           ; direction of ball
place   = $85           ; position of ball
score   = $86           ; left score in high nibble, right in low
pleft   = $87           ; 0 for KIM to play left
prite   = $88           ; 0 for KIM to play right
digit   = $89           ; counts score digits (1 = right, 0 = left)
arg     = $8A           ; left score digit, held while right is shown
mod     = $8B           ; display delay counter (never initialized)
temp    = $8C           ; odds threshold, 0 to 6 (not the monitor's TEMP)

; Free-running timer, read for random numbers
timer   = T1_NOIRQ      ; $1704

start:
        jsr KEYIN               ; directional registers
        jsr GETKEY              ; input key
        cmp #KEY_GO             ; 'GO' key?
        bne nogo                ; ..nope, skip
; 'GO' key - set up game here
        ldx #8                  ; get nine
setup:  lda init,x              ; initial values
        sta speed,x             ; to zero page
        dex
        bpl setup
; Test legal keys (0,3,4,7,8,B,C,F)
nogo:   cmp #$10                ; key 0 to F?
        bcs nokey               ; ..no, skip
        tax                     ; save key in X
        and #3                  ; test column
        beq key                 ; col 0 (0,4,8,C)?
        cmp #3                  ; col 3 (3,7,B,F)?
        bne nokey               ; ..neither, skip
key:    eor place               ; check vs ball position
        tay
        and #4                  ; ball off screen?
        bne nokey
        txa                     ; restore key
        eor direct              ; ball going away?
        and #2
        beq nokey               ; ..yes, ignore key
        tya                     ; ball position
        and #2                  ; wrong side of net?
        bne point               ; ..yes, lose!
; Legal play found here
        txa                     ; restore key
        lsr a
        lsr a                   ; type (0=Spin, etc)
        jsr shot                ; make shot
; Key routines complete - play ball
nokey:  jsr KEYIN               ; if key still pressed
        bne freeze              ; freeze ball
        dec pause
        bpl freeze              ; wait til timeout
        lda speed
        sta pause
        clc
        lda place               ; move
        adc direct              ; ball
        sta place
        and #4                  ; ball still
        beq freeze              ; in court?
; Ball outside - KIM to play?
        lda place
        bmi testl               ; ball on left
        lda prite               ; KIM plays right?
        bpl skpt                ; unconditional
testl:  lda pleft               ; KIM plays left?
skpt:   bne point               ; ..no, lose point
; KIM plays either side here
        ldx log                 ; log determines
        lda play,x              ; ..KIM's play
        jsr shot                ; make the shot
freeze: lda #$7F
        sta SADD                ; open registers
; Light display here
        ldy #$13
        ldx #1
        stx digit               ; count score digits
        lda score
        lsr a
        lsr a                   ; shift & store
        lsr a
        lsr a                   ; left player score
        sta arg
        lda score
        and #$0F                ; right player score
        tax
hoop:   lda TABLE,x
        jsr show
        ldx arg
        dec digit
        bpl hoop
        ldx #3
vue:    lda pix,x
        cpx place
        bne nopix
        ora spot                ; show the ball
nopix:  jsr show
        dex
        bpl vue
        bmi slink
; Lose! Score & reverse board
point:  jsr skore
slink:  cld
        jmp start               ; return to main loop

; Display subroutine
show:   sta SAD
        sty SBD
stall:  dec mod
        bne stall
        dey
        dey
        rts

shot:   tay                     ; save shot in Y
        ldx log                 ; old log in X
        asl log
        asl log
        ora log
        and #$0F                ; update log book
        sta log                 ; ..last two shots
        sec
        lda speed
        sbc pause               ; invert timing
        sta pause
; Set speed & display segment(s)
        lda spd,y
        sta speed
        lda seg,y
        sta spot
; Test play success - random
        lda chance,x            ; odds from log book
git:    dey
        bmi get
        lsr a
        lsr a
        bpl git                 ; unconditional
get:    and #3                  ; odds 0 to 3..
        asl a                   ; now 0 to 6
        sta temp
        lda timer               ; random number
        and #7                  ; now 0 to 7
        cmp temp
        beq revrs               ; success?
        bcc revrs               ; success?
; Lose a point & position to serve
skore:  ldx #4                  ; position ball R
        lda direct
        asl a
        asl a
        asl a
        asl a
        bpl over
        ldx #$FF                ; position ball L
        lda #1
over:   stx place
        clc
        adc score
        sta score
        ldy #0                  ; end game, kill ball
tlp:    tax
        and #$0F                ; get one score
        cmp #$0B                ; 11 points?
        bne ski
        sty direct              ; kill ball
ski:    txa
        lsr a
        lsr a
        lsr a
        lsr a
        bne tlp
; Set serve - speed, spot, log, pause
        ldx #3
srv:    lda init,x
        sta speed,x
        dex
        bpl srv
; Reverse ball direction
revrs:  lda direct
        clc
        eor #$FF
        adc #1
        sta direct
        rts

; Tables
init:   .byte $30,$C0,$00,$80,$01,$FF,$00,$01,$00      ; $0324
pix:    .byte $00,$06,$30,$00                          ; $032D
spd:    .byte $20,$20,$20,$14                          ; $0331
seg:    .byte $08,$40,$01,$49                          ; $0335
play:   .byte $02,$02,$01,$02,$01,$03,$01,$02          ; $0339
        .byte $03,$03,$00,$02,$00,$00,$02,$02
chance: .byte $78,$B5,$9E,$76,$6E,$A1,$AE,$75          ; $0349
        .byte $AA,$EB,$8F,$75,$5B,$56,$7A,$35
