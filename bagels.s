; BAGELS -- from "The First Book of KIM"
; Code-breaking game: the computer picks four letters from A-F (repeats
; allowed); you get ten moves.  Each move shows two counts at the right of
; the display: letters exactly right, and letters right but misplaced.
; A response of "4-0" is a win.  After a win, or after the answer is shown,
; touching a key starts a new game.
;
; Converted to ca65 using kim.inc.  Assembles byte-for-byte to the book's
; hex dump ($0200-$02EB).

        .include "kim.inc"

; ---- Work areas (zero page) -------------------------------------------
SECRET  = $00                   ; 4  computer's secret code
WINDOW  = SECRET+4              ; 6  display window
INPUT   = WINDOW+6              ; 4  player's input area
EXACT   = INPUT+4               ; 1  # of exact matches
MATCH   = EXACT+1               ; 1  # of other matches
POINTR  = MATCH+1               ; 1  digit being input
MOD     = POINTR+1              ; 1  divisor / delay flag
RND     = MOD+1                 ; 6  random number series
COUNT   = RND+6                 ; 1  number of guesses left

SQUARE  = $E3                   ; "square" flag: game-over marker in WINDOW+4
                                ; (the printed listing's $C3 is an OCR error)

        .org PROGRAM_ORG

go:     inc RND+4               ; randomize
        jsr KEYIN               ; 'ON' pushbutton delay
        bne go
        cld
new:    lda #$0A                ; ten guesses/game
        sta COUNT               ; new game starting
        lda #3                  ; create 4 mystery codes
        sta POINTR
rand:   sec                     ; one plus
        lda RND+1               ; ..three previous
        adc RND+4               ; ..random numbers
        adc RND+5
        sta RND                 ; new random value
        ldx #4
rlp:    lda RND,x               ; move random numbers over
        sta RND+1,x
        dex
        bpl rlp
        ldx POINTR
        ldy #$C0                ; divide by 6
        sty MOD                 ; keeping remainder
        ldy #6
set:    cmp MOD
        bcc pass
        sbc MOD
pass:   lsr MOD
        dey
        bne set                 ; continue division
        clc
        adc #$0A                ; random value A to F
        sta SECRET,x
        dec POINTR
        bpl rand
guess:  dec COUNT               ; new guess starts here
        bmi finish              ; ten guesses?
        lda #0
        ldx #$0C                ; clear from WINDOW
wipe:   sta WINDOW,x            ; to POINTR
        dex
        bpl wipe

; ---- Wait for key to be pressed ---------------------------------------
wait:   jsr show
        beq wait
        jsr show
        beq wait                ; debounce key
        lda WINDOW+4            ; new guess?
        beq resume              ; no, input digit
        and #$60
        eor #$60                ; previous game finished?
        beq new                 ; ..yes, new game;
        bne guess               ; ..no, next guess
resume: jsr GETKEY
        cmp #$10                ; guess must be in
        bcs wait                ; ..range "A" to "F"
        cmp #$0A
        bcc wait
        tay
        ldx POINTR              ; zero to start
        inc POINTR
        lda TABLE,y             ; segment pattern
        sta WINDOW,x
        tya
        cmp SECRET,x            ; exact match?
        bne notex
        inc EXACT
        txa                     ; destroy input
notex:  sta INPUT,x
        lda WINDOW+3            ; has 4th digit arrived?
        beq butt                ; ..no
        ldy #3                  ; ..yes, calculate matches
step:   lda INPUT,y             ; for each digit:
        and #$18                ; has it already been
        beq on                  ; matched?
        lda SECRET,y
        ldx #3                  ; if not, test
look:   cmp INPUT,x             ; against input
        beq got
        dex
        bpl look
        bmi on
got:    inc MATCH               ; increment counter
        asl INPUT,x             ; and destroy input
on:     dey
        bpl step
        ldx #1                  ; display counts
trans:  ldy EXACT,x
        lda TABLE,y
        sta WINDOW+4,x
        dex
        bpl trans
delay:  jsr show                ; long pause for debounce
        inc MATCH
        bne delay
butt:   jsr show                ; wait for key release
        bne butt
        beq wait

; ---- Ten guesses made: show answer ------------------------------------
finish: ldx #3
fin2:   ldy SECRET,x
        lda TABLE,y
        sta WINDOW,x
        dex
        bpl fin2
        lda #SQUARE             ; 'square' flag
        sta WINDOW+4
        bne delay               ; unconditional jump

; ---- Subroutine to display / test keyboard ----------------------------
show:   ldy #$13
        ldx #5
        lda #$7F
        sta SADD                ; (the book's PADD = $1741 is kim.inc's SADD)
lite:   lda WINDOW,x
        sta SAD
        sty SBD
poz:    inc MOD                 ; pause loop
        bne poz
        dey
        dey
        dex
        bpl lite
        jsr KEYIN
        rts
