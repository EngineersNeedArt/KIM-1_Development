; reaction.s -- two-player reaction game for the KIM-1
; From "The First Book of KIM"; converted to ca65.
;
; Each player starts with 10 points, shown at opposite ends of the display.
; The center two digits stay blank for a random delay, then light up.
; First player to press his key while they are lit gains a point and the
; opponent loses one.  Pressing while the center is blank costs you a point.
; When either score reaches zero the game is over; restart at $0200.
; Left player uses key 0, right player uses key 7.

        .include "kim.inc"

; The scores and the center digits live in the monitor's display buffer
; (INH, POINTL, POINTH), so SCANDS-style output and the game share them.
; right_score + 2 = left_score, which the X-indexed score code relies on.
right_score = INH               ; $F9  BCD score, right player
center      = POINTL            ; $FA  center digits ($00 blank, $36 lit)
left_score  = POINTH            ; $FB  BCD score, left player
delay       = $EE               ; random delay countdown (negative = time up)

CONVD       = $1F48             ; monitor: convert hex digit in A and display it
                                ; (OUTPUT in kim.inc is its mid-routine entry)

        .org PROGRAM_ORG

start:
        lda #$10                ; initialize both scores to 10
        sta right_score
        sta left_score
rand:
        lda CLK1T               ; get "random" number
        and #$1F                ; not too big
        ora #$01                ; not too small
        sta delay               ; put in decrement location
        lda #$00                ; blank center digits
        sta center
disp:
        jsr lite                ; display digits
        lda TIMER_FLAG          ; timer expired?
        beq more                ; ..no
        lda #$FF
        sta T1024_NOIRQ         ; restart timer
        dec delay               ; full delay elapsed?
        bpl more                ; ..no, skip
        lda #$36                ; ..yes, light the center digits
        sta center
more:
        cld                     ; clear for keyboard
        jsr KEYIN               ; init keyboard
        jsr GETKEY              ; key depressed?
        cmp #KEY_NONE           ; valid key?
        bpl disp                ; ..no
        cmp #$07                ; right key?
        beq rite                ; ..yes
        cmp #$00                ; left key?
        beq left                ; ..yes
        bne disp                ; not a "0" or a "7"

left:
        ldx #left_score-right_score     ; index for left
        lda delay               ; time up?
        bpl los1                ; ..no, decrease left one
        bmi add1                ; ..yes, increase left
rite:
        ldx #$00                ; index for right
        lda delay               ; check time
        bpl los1                ; ..no, not yet
add1:
        sed
        clc                     ; increase score
        lda right_score,x       ; by one
        adc #$01
        sta right_score,x
        txa                     ; index to other
        eor #$02                ; side
        tax
los1:
        sed                     ; decrease score
        sec                     ; by one
        lda right_score,x
        sbc #$01
        sta right_score,x
        beq fin                 ; go to fin if zero
wait:
        jsr lite                ; wait for switch
        jsr KEYIN               ; to be released
        bne wait
        beq rand                ; then start new delay
fin:
        jsr lite                ; finished: display final scores forever
        clv
        bvc fin                 ; unconditional jump

; ---- Display subroutine ----------------------------------------------------
lite:
        lda #$7F
        sta SADD
        ldx #$09                ; init digit #
        lda left_score
        jsr hex2
        lda center              ; get center digits
        jsr OUTPUT              ; convert non-hex char
        jsr OUTPUT              ; two of them
        lda right_score
        jsr hex2
        rts

; ---- Hex character conversion subroutine -----------------------------------
; Displays one byte as two hex characters, blanking a leading zero.
hex2:
        tay
        lsr a
        lsr a
        lsr a
        lsr a
        beq zblk                ; high nibble zero: blank it
        jsr CONVD
second:
        tya                     ; second character
        and #$0F
        jsr CONVD
        rts
zblk:
        lda #$80                ; blank leading zero
        sty TEMP                ; OUTPUT restores Y from TEMP
        jsr OUTPUT              ; convert non-hex char
        clv
        bvc second              ; unconditional jump
