; dungeon_dice.s -- Dungeons and Dragons dice simulator for the KIM-1
;
; Myron A. Calhoun, Manhattan, KS; COMPUTE! issue 13, June 1981, pp. 145-146.
; Claude converted from the article's IEEE-draft-standard assembly (29XII80) 
; to ca65.
;
; Keys 0-5 roll a d4, d6, d8, d10, d20 or d100; the result (1..max) is shown
; in decimal on the display.  Any other key blanks the display to zeroes.
; Holding a key re-rolls continuously (too fast to read).  The random number
; comes from the free-running RIOT timer.
;
; The article ran at $0000 (zero page).  This version is built for the main
; area: load the 70-byte binary at $0200 and GO from address 0200.  Nothing in
; the program depends on its address; only the operands that point back into
; it (two jmps, and the table indexing, now absolute,X) differ from the
; article's hex dump.
;
; The article assumes the user RIOT timer is already free-running and reads it
; at $1704.  On the PAL-2 it has to be started first, so this version starts
; the timer with a write at start and reads it at TIMER_READ.
;
; Build:  ca65 dungeon_dice.s && ld65 -C kim.cfg -o dungeon_dice dungeon_dice.o

        .include "kim.inc"

; Display layout as drawn by SCANDS: POINTH POINTL INH, left to right.
; The article called these LEFT, MIDDLE, RIGHT ($FB, $FA, $F9).
left    = POINTH
middle  = POINTL
right   = INH

        .segment "CODE"

; ---- blank the display ----------------------------------------------------
start:  lda #0                  ; clear the initial display
        sta right               ;   to all zeroes
        sta middle
        sta T64_NOIRQ           ; start user timer (underflows, then free-runs)

newvalu:
        sta left                ; set new value (found below)

display:
        jsr SCANDS              ; "pump" the display and also
        beq display             ;   see if any keys are pressed

; ---- a key is down ------------------------------------------------------------
        cld                     ; binary mode: GETKEY and the sbc below need it
        jsr GETKEY              ;   key value from the keyboard
        cmp #KEY_NONE           ; if no key is being pressed
        beq display             ;   right now, continue display.  If
        cmp #6                  ;   a key larger than "5" is pressed,
        bcs start               ;   then clear the display again
        tax                     ; save valid key (0,1,2,3,4,5)

; ---- random number 0..max-1 ---------------------------------------------------
        lda TIMER_READ          ; fetch "random" number from timer
        and #$7F                ;   and convert to value between 0
tryagin:
        cmp table,x             ;   and 3, 5, 7, 9, 19, or 99
        bcc convert             ;   (depending on value in X register)
        sec                     ;   by repeatedly subtracting 4, 6,
        sbc table,x             ;   8, 10, 20, or 100 (from the table)
        jmp tryagin             ;   and check again

; ---- binary to BCD, then add one ----------------------------------------------
convert:
        tax                     ; number is still in binary form, so
        lda #0                  ;   convert to decimal by counting
        sed                     ;   the binary down while counting
notyet: clc                     ;   the decimal up.
        adc #1                  ;   (this is a "cheap and dirty"
        dex                     ;   conversion method!)
        bpl notyet              ;   N=0 for X=0..127: runs X+1 times, A=1..max

        sta middle              ; then put possible 2-byte answer
        lda #0                  ;   into address part of display
        rol a                   ;   (leftmost byte can only contain
        jmp newvalu             ;   the "1" as in "100")

; ---- die sizes ----------------------------------------------------------------
table:  .byte 4, 6, 8, 10, 20, 100      ; max values for 6 dice
