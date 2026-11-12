; horserace.s -- Horse Race for the KIM-1
; From "The First Book of KIM"; starts at $0200.
;
; Eight-lap, three-horse race shown across the six display digits.
; You are the jockey: whip your horse to make it go faster, but whip it
; too much and it poops out (and then slows down instead).
;
;   Horse             Track     Whip button
;   Prince Charming   top       PC
;   Colorado Cowboy   middle    C
;   Irish Rover       bottom    4
;
; Each horse is a single lit segment (top, middle or bottom) that moves
; one digit to the right every time its "window counter" runs out.  The
; counter is reloaded from the horse's speed, so a bigger speed value
; means a longer wait and a slower horse.  After the last digit the
; field wraps back to the left for the next lap; on the final lap a
; finish line (the two right-hand segments) is drawn in the last digit.
; When the lap counter goes negative the display freezes.
;
; Uses KEYTS ($1F3D), which turns off the digits and tests the keypad.

        .include "kim.inc"

; ---- Zero page ----------------------------------------------------
digits  = $7c           ; 7 bytes: display digits $7c-$82 (only 6 shown)
shelf   = digits-6      ; $76: digit $82 lands in $7c on a lap change
hpos    = $83           ; 3 bytes: digit position of each horse
count   = $86           ; 3 bytes: window counter per horse
pflag   = $89           ; 3 bytes: poop flag per horse ($00 ok, $ff pooped)
speed   = $8c           ; 3 bytes: speed per horse
lap     = $8f           ; laps remaining
seed    = $91           ; 6 bytes: random number shift register
hidx    = $99           ; index of horse being moved (0 = top)
upd     = $9a           ; speed update / scratch

        .org PROGRAM_ORG

start:  cld

; ---- Horses to the starting gate ----------------------------------
        ldx #$13                ; 20 bytes: $7c-$8f
init:   lda startup,x
        sta digits,x
        dex
        bpl init

; ---- Light the display --------------------------------------------
disp:   lda #$7f
        sta SADD
        ldy #$00
        ldx #$09                ; leftmost digit
lite:   lda digits,y
        sty TEMP                ; OUTPUT restores Y from TEMP
        jsr OUTPUT              ; output one digit
        iny
        cpy #$06                ; six digits displayed?
        bcc lite                ; ..not yet
        jsr KEYTS               ; turn off digits
        lda lap                 ; finished all laps?
        bmi disp                ; ..yes, freeze display

; ---- Find the next horse whose counter runs out -------------------
        ldx #$03
next:   dex                     ; next horse
        bmi disp                ; finished 3 horses
        dec count,x             ; decrement counter, horse x
        bne next                ; not zero, next horse

; ---- Move horse x one digit to the right --------------------------
        stx hidx                ; save horse index
        ldy hidx                ; and put it in Y as well
        ldx hpos,y              ; digit position of horse in X
        lda masks,y             ; mask to remove horse
        and digits,x            ; get rid of horse
        sta digits,x            ; return remaining horses
        inx                     ; go to next digit right
        stx hpos,y              ; update horse digit position
        lda masks,y             ; get mask
        eor #$ff                ; change to an insert mask
        ora digits,x            ; put horse in next
        sta digits,x            ; digit right
        cpx #$05                ; reached right side?
        bmi poop                ; ..not yet
        bne nlap                ; off right side, change lap
        lda lap                 ; check lap counter
        beq last                ; if zero, last lap
        bne poop                ; (always)

; ---- Change to a new lap ------------------------------------------
nlap:   ldx #$02
down:   sec                     ; shift all horse digit
        lda hpos,x              ; positions six places
        sbc #$06                ; down
        sta hpos,x
        dex
        bpl down
        ldx #$06
store:  lda digits,x            ; also shift digit contents
        sta shelf,x             ; into storage area
        lda #$80                ; and clear display
        sta digits,x            ; area
        dex
        bne store
last:   dec lap                 ; decrement lap counter
        bne poop                ; not last lap, continue
        lda digits+5            ; last lap, put finish
        ora #$06                ; line in last digit
        sta digits+5

; ---- Poop check ---------------------------------------------------
poop:   lda pflag,y             ; horse y poop flag
        beq nopo                ; horse not pooped
        jsr rand                ; pooped, but may
        and #$3c                ; become un-pooped depending
        bne fast                ; on random number
        sta pflag,y
nopo:   jsr rand                ; not pooped, but may
        and #$38                ; become pooped depending
        sta upd                 ; on random number...
        lda speed,y
        bmi fast
        and #$38
        cmp upd
        bcs fast
        lda #$ff                ; if pooped, set poop
        sta pflag,y             ; flag to $ff

; ---- Whip and speed update ----------------------------------------
fast:   jsr KEYTS               ; get key from keyboard
        ldy #$ff                ; init Y to max
        ldx hidx                ; horse index in X
        and whip,x              ; mask (is horse whipped?)
        beq skip                ; ..no, not being whipped
        dey                     ; ..whipped, Y made smaller
skip:   tya                     ; change sign if pooped
        eor pflag,x             ; exclusive OR with $00 or $ff
        sta upd                 ; save speed update
        jsr rand                ; get a random number
        sec
        and #$01                ; lowest bit of number
        adc upd                 ; combine whip update,
        clc                     ; random number (0 or 1) and carry
        ldx hidx                ; horse index in X
        adc speed,x             ; horse's speed added in
        sta speed,x             ; save new speed
        sta count,x             ; also in window counter
        jmp next                ; loop

; ---- Random number subroutine -------------------------------------
; From J. Butterfield, KIM User Notes #1, page 4
rand:   sec
        lda seed+1
        adc seed+4
        adc seed+5
        sta seed
        ldx #$04
move:   lda seed,x
        sta seed+1,x
        dex
        bpl move
        rts

; ---- Tables -------------------------------------------------------
        .byte $00               ; unused

startup:                        ; copied to $7c-$8f
        .byte $80,$80,$80,$80,$80,$80,$80       ; digits $7c-$82
        .byte $ff,$ff,$ff                       ; horse digit positions
        .byte $80,$80,$80                       ; window counters
        .byte $00,$00,$00                       ; poop flags
        .byte $80,$80,$80                       ; speeds
        .byte $08                               ; eight laps

masks:  .byte $fe,$bf,$f7       ; remove segments a, g, d (top, mid, bottom)
whip:   .byte $01,$02,$04       ; whip key masks
