; carddealer.s -- deal a 52-card deck, one card per keypress (KIM-1)
;
; From "The First Book of KIM". The value and suit of each card show in
; the right-hand two display digits (A 2-9 T J Q K / S H D C). Press any
; key for the next card; every card comes up exactly once. After the 52nd
; card the next keypress returns to the monitor -- start again at $0200.
;
; The "random" number is whatever the two free-running RIOT timers happen
; to read when the key goes down.

        .include "kim.inc"

DECK_SIZE = 52

; ---- zero page ($0000-$00EE is the user area) ------------------------------
disp_buf    = $8c               ; six display digits, leftmost first ($8c-$91)
value_digit = disp_buf+4        ; 5th digit: card value
suit_digit  = disp_buf+5        ; 6th digit: card suit
cards_left  = $92
deck        = $93               ; 52 flags: 1 = still in deck, 0 = dealt
                                ; card n: value = n/4 (A..K), suit = n mod 4 (S H D C)

; ---- monitor entry not (yet) in kim.inc ------------------------------------
; Three bytes ahead of KEYIN ($1F40): blanks the digit drive, then falls
; into KEYIN, which returns A <> 0 if a key is down (and sets Z to match).
BLANK_KEYIN = $1f3d

        .org PROGRAM_ORG

start:
        ldx #6                  ; blank the display buffer
        ldy #0
@clear:
        sty disp_buf-1,x
        dex
        bne @clear

        cld
        ldx #DECK_SIZE          ; 52 cards left
        stx cards_left
        iny                     ; y = 1
@fill:
        sty deck-1,x            ; every card starts in the deck
        dex
        bne @fill

new_card:
        lda cards_left
        bne @deal
        jmp START               ; deck finished -- back to the monitor

@deal:
        lda TIMER_READ          ; random number $01-$FF
        bne reduce
        lda CLK1T               ; first timer read 0, try the other one
        bne reduce
        lda cards_left          ; both zero: use about the middle of the deck
        lsr
        clc
        adc #1

reduce:                         ; fold a into 1..cards_left
        cmp cards_left
        bcc find
        beq find
        sbc cards_left          ; carry is set here, and still set afterward
        bcs reduce              ; ...so this always loops

find:                           ; locate the a-th card still in the deck
        ldx #DECK_SIZE-1
@next:
        sec
        sbc deck,x              ; subtract 1 for each card still in the deck
        beq @found              ; reaches 0 exactly on the chosen card
        dex                     ; (dealt cards subtract 0)
        bpl @next
@found:
        sta deck,x              ; a = 0: mark card dealt
        dec cards_left

        txa                     ; value = position / 4  (0..12)
        lsr
        lsr
        tay
        lda value_table,y
        sta value_digit

        txa                     ; suit = position mod 4
        and #3
        tay
        lda suit_table,y
        sta suit_digit

@wait_release:
        jsr show                ; show the card until any key is let go
        bne @wait_release
@wait_press:
        jsr show                ; ...then until a key goes down
        bne new_card
        beq @wait_press         ; (always)

; ---- refresh the six digits once; returns A <> 0 / Z clear if a key is down
show:
        lda #$7f
        sta SADD                ; segment lines out
        ldy #0
        ldx #$09                ; first digit select (OUTPUT adds 2 each call)
@digit:
        lda disp_buf,y
        sty TEMP                ; OUTPUT restores y from TEMP
        jsr OUTPUT
        iny
        cpy #6
        bcc @digit
        jmp BLANK_KEYIN         ; tail call: returns to our caller

; ---- 7-segment patterns ----------------------------------------------------
value_table:                    ;  A   2   3   4   5   6   7   8   9   T   J   Q   K
        .byte $77,$5b,$4f,$66,$6d,$7d,$07,$7f,$6f,$78,$1e,$67,$70
suit_table:                     ;  S   H   D   C
        .byte $6d,$76,$5e,$39
