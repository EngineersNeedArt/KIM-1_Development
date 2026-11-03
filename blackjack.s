; blackjack.s -- BLACKJACK for the KIM-1
; From "The First Book of KIM", converted to modern ca65 source.
;
; KIM plays blackjack against you with a real 52-card deck, so counting
; cards (especially aces and face cards) works until the next shuffle.
;
; Start at $0200.  The display shows SHUFFL while the deck is shuffled, then
; BET? followed by your balance (you start with $20).  Bet $1-$9 with keys
; 1-9; the cards are dealt the instant you press the key.  A zero bet, or a
; bet larger than your balance, is ignored.
;
; After the deal the display shows your two cards on the left and one of
; KIM's cards on the right (the other is the hole card).  Aces show as A,
; tens and face cards as F, other cards as 2-9.  Aces count 1 or 11.
;   3, 4, 5  hit: ask for your third, fourth, fifth card
;   0        stand: KIM shows your total, then plays its own hand
; Over 21 shows BUSTED and loses.  Five cards without busting wins
; automatically (KIM can win this way too).  KIM draws to 17.  Equal
; totals are a push.  The balance is BCD and is capped at $99.
; KIM re-shuffles when fewer than 9 cards remain.

        .setcpu "6502"
        .include "kim.inc"

; ---- Zero page ---------------------------------------------------------
deck    = $40           ; 52 cards, each 0-51: rank = card >> 2, low 2 = suit
pointr  = $74           ; 2-byte pointer used by fill (high byte set at init)
dpt     = $76           ; index of next card to deal (counts down)
amt     = $77           ; your balance (BCD)
bet     = $79           ; current bet (binary, 1-9)
hole    = $7a           ; rank of KIM's hole card
pause   = $7b           ; display multiplex delay counter
ysav    = $7f           ; Y save for light
rnd     = $80           ; 6-byte random shift chain, seeded from the timer
window  = $90           ; the six display digits (segment patterns)

; Hand state.  The player and KIM blocks have the same layout, so that
; show_total can use X = 0 (player) or X = 3 (KIM) to index either one.
ucnt    = $96           ; number of player cards
utot    = $97           ; player's point total (BCD, aces counted as 1)
uace    = $98           ; $10 if player holds an ace, else 0
mcnt    = $99           ; KIM's card count, kept negated (counts down from 0)
mtot    = $9a           ; KIM's point total (BCD, aces counted as 1)
mace    = $9b           ; $10 if KIM holds an ace, else 0

        .assert mtot = utot + 3, error, "KIM/player blocks must be 3 apart"
        .assert mace = uace + 3, error, "KIM/player blocks must be 3 apart"

        .org PROGRAM_ORG

; ---- Build an ordered deck, set up variables, seed the random chain ----
start:
        ldx #51                 ; 52 cards in the deck
make_deck:
        txa
        sta deck,x              ; card n goes in slot n
        dex
        bpl make_deck

        ldx #2                  ; copy the three init values to
init_loop:
        lda init,x              ; pointr+1 / dpt / amt
        sta pointr+1,x
        dex
        bpl init_loop

        lda TIMER_READ          ; use the running timer
        sta rnd                 ; to seed the random chain

; ---- Main loop: shuffle if needed, take a bet, play a hand -------------
deal:
        cld
        ldx dpt                 ; next-card pointer
        cpx #9                  ; fewer than 9 cards left?
        bcs no_shuffle          ; no, keep playing this deck

        ldy #<msg_shuffl        ; show SHUFFL
        jsr fill
        ldy #51                 ; full deck again
        sty dpt

shuffle_loop:                   ; swap each card into a random slot
        jsr light               ; keep the display lit
        sec
        lda rnd+1               ; make a new random number from
        adc rnd+2               ; three of the chain's bytes
        adc rnd+5
        sta rnd
        ldx #4
rnd_move:
        lda rnd,x               ; shift the chain along one place
        sta rnd+1,x             ; (A ends up holding the new number)
        dex
        bpl rnd_move
        and #$3f                ; reduce to 0-63
        cmp #52
        bcs shuffle_loop        ; 52-63: try again
        tax
        lda deck,y              ; swap deck[y] with deck[random]
        pha
        lda deck,x
        sta deck,y
        pla
        sta deck,x
        dey
        bpl shuffle_loop

; ---- Ask for a bet ----------------------------------------------------
no_shuffle:
        ldy #<msg_bet           ; show BET? and the balance
        jsr fill
        lda amt
        jsr show_number
bet_in:
        jsr light               ; wait for a key
        cmp #10
        bcs bet_in              ; not 0-9, ignore
        tax
        stx bet
        dex
        bmi bet_in              ; zero bet, ignore
        cpx amt
        bcs bet_in              ; more than the balance, refuse

; ---- Bet accepted: clear hands and deal --------------------------------
        ldx #11                 ; clear window and the hand counters
        lda #0
clear_loop:
        sta window,x
        dex
        bpl clear_loop

        jsr deal_you            ; one for you
        jsr deal_me             ; one for KIM (shown)
        jsr deal_you            ; second for you
        jsr get_card            ; KIM's second card goes
        stx hole                ; face down in the hole
        jsr wait_lit            ; brief pause

; ---- Your turn: hit or stand -------------------------------------------
get_key:
        jsr light
        tax                     ; key code -> X, then
        dex                     ; "n" key means card number n
        bmi stand               ; key 0: stand
        cpx ucnt                ; is it the next card number?
        bne get_key             ; no, ignore the key

        jsr deal_you            ; hit: deal another card
        cmp #$22                ; BCD 22 or more?
        bcs player_bust
        cpx #5                  ; five cards?
        beq player_win
        bne get_key             ; (always taken) keep going

; ---- Stand: show your total, then reveal KIM's hand --------------------
stand:
        lda window+5            ; save KIM's up card
        pha
        ldx #0                  ; show the player's total
        jsr show_total
        ldx #4
        lda #0
stand_clear:
        sta window,x            ; clear the player's side
        dex
        bpl stand_clear
        pla                     ; put KIM's up card back
        sta window+5
        ldx hole                ; rebuild the hole card
        jsr card_rec
        jsr me_store            ; add it to KIM's hand and display

; ---- KIM plays ---------------------------------------------------------
kim_play:
        jsr wait_lit            ; pause to show the cards
        lda mtot
        cmp #$22                ; 22 or over?
        bcs kim_bust
        adc mace                ; count an ace as 11 (carry is clear)
        ldx window+1            ; has KIM filled all five slots?
        bne kim_wins            ; yes: five-card win
        cmp #$22                ; over 21 with the ace high?
        bcc ace_high
        lda mtot                ; yes, count the ace low
ace_high:
        cmp #$17                ; 17 or more?
        bcs kim_stands          ; yes, stand
        jsr deal_me             ; no, hit
        bne kim_play            ; (always taken)

; ---- KIM wins ----------------------------------------------------------
player_bust:
        jsr wait_lit            ; show the busting hand,
        jsr bust                ; then BUSTED
        jsr wait_lit
kim_wins:
        lda amt                 ; balance -= bet
        sed
        sec
        sbc bet
store_amt:
        sta amt                 ; store the new balance
next_hand:
        jmp deal

; ---- You win -----------------------------------------------------------
kim_bust:
        jsr bust                ; show BUSTED
player_win:
        jsr wait_lit
add_bet:
        lda amt                 ; balance += bet
        sed
        clc
        adc bet
        ldy #$99                ; cap the balance at $99
        bcc no_overflow
        tya                     ; carry out: use $99
no_overflow:
        bne store_amt           ; (always taken)

; ---- KIM stands: compare totals ----------------------------------------
kim_stands:
        ldx #3                  ; show KIM's total
        jsr show_total
        lda mtot
        cmp utot
        beq next_hand           ; same total: push
        bcs kim_wins            ; KIM higher: KIM wins
        bcc add_bet             ; KIM lower: you win

; ---- Subroutines -------------------------------------------------------

; show_total: display "TOT-nn".  X = 0 for the player, X = 3 for KIM.
; An ace is counted as 11 if that does not bust the hand.
; Falls through into wait_lit.
show_total:
        lda utot,x
        sed
        clc
        adc uace,x              ; try adding the ace's extra 10
        cmp #$22                ; over 21?
        bcs show_over           ; yes, keep the hard total
        sta utot,x              ; no, make the soft total permanent
show_over:
        cld
        lda utot,x              ; the (possibly revised) total
        pha
        ldy #<msg_tot
        jsr fill                ; put TOT- in the window
        pla
        jsr show_number         ; and the total after it

; wait_lit: keep the display lit for roughly a second
wait_lit:
        ldy #$80                ; timing constant
wait_loop:
        jsr light
        dey
        bne wait_loop
                                ; falls through for one more light pass

; light: multiplex the six digits once, then scan the keypad.
; Returns the key code in A (>= $15 means no key); Y is preserved.
light:
        sty ysav
        ldy #$13                ; digit-select code of the rightmost digit
        ldx #5                  ; six digits to show
        lda #$7f
        sta SADD                ; PA7 is the keypad/TTY input, rest outputs
digit:
        lda window,x
        sta SAD                 ; segments
        sty SBD                 ; which digit
delay:
        inc pause
        bne delay
        dey                     ; next digit select code is 2 lower
        dey
        dex
        bpl digit
        jsr KEYIN               ; switch the direction register
        jsr GETKEY              ; read the keyboard
        ldy ysav
        rts

; bust: put BUSTED in the window.  fill: copy the 6-byte message at
; page-3 offset Y into the window.
bust:
        ldy #<msg_busted
fill:
        sty pointr              ; (pointr+1 was set to the message page)
        ldy #5
fill_loop:
        lda (pointr),y
        sta window,y
        dey
        bpl fill_loop
        rts

; get_card: deal the next card from the deck.
; Returns X = rank 0-12 (0 = ace), A = BCD value, Y = display segments,
; carry set if it is an ace.
get_card:
        ldx dpt
        dec dpt
        lda deck,x              ; the card, 0-51
        lsr a
        lsr a                   ; drop the suit
        tax                     ; rank 0-12
; card_rec: same as above, for a rank already in X
card_rec:
        clc                     ; no-ace flag
        bne not_ace
        sec                     ; ace flag
not_ace:
        lda value,x
        ldy segs,x
        rts

; deal_you: deal a card to the player, display it and add it to the total.
; Returns A = new total (BCD), X = number of player cards.
deal_you:
        jsr get_card
        inc ucnt
        ldx ucnt                ; use as display pointer
        sty window-1,x          ; cards fill the window left to right
        ldy #$10                ; "ten" for aces
        bcc you_over            ; not an ace
        sty uace
you_over:
        clc
        sed
        adc utot
        sta utot
        cld
        rts

; deal_me: deal a card to KIM, display it and add it to KIM's total.
; me_store does the same for a card already in A/Y/carry (the hole card).
; mcnt counts down from 0, so the cards fill the window right to left:
; the index $FF + 6 wraps within the zero page to window+5, and so on.
deal_me:
        jsr get_card
me_store:
        dec mcnt
        ldx mcnt
        sty window+6,x          ; zero-page indexing wraps around
        ldy #$10
        bcc me_over
        sty mace
me_over:
        clc
        sed
        adc mtot
        sta mtot
        cld
        rts

; show_number: put the BCD number in A into the two right-hand digits
show_number:
        pha
        lsr a
        lsr a                   ; high digit
        lsr a
        lsr a
        tay
        lda TABLE,y             ; monitor's hex -> segments table
        sta window+4
        pla
        and #$0f                ; low digit
        tay
        lda TABLE,y
        sta window+5
        rts

; ---- Tables (all in one page: fill uses pointr+1 = this page) ----------
init:
        .byte >init, 0, $20     ; pointr+1, dpt (0 forces a shuffle), amt $20

value:                          ; BCD point value by rank, ace first
        .byte $01,$02,$03,$04,$05,$06,$07,$08,$09,$10,$10,$10,$10

segs:                           ; display segments by rank: A,2-9,F,F,F,F
        .byte $F7,$DB,$CF,$E6,$ED,$FD,$87,$FF,$EF,$F1,$F1,$F1,$F1

msg_shuffl:                     ; "SHUFFL"
        .byte $ED,$F6,$BE,$F1,$F1,$B8
msg_bet:                        ; "BET?" -- fill copies 6 bytes, the last two
        .byte $FC,$F9,$F8,$D3   ; come from msg_tot but are overwritten by
msg_tot:                        ; show_number.  "TOT-" likewise.
        .byte $F8,$DC,$F8,$C0
msg_busted:                     ; "BUSTED"
        .byte $FC,$BE,$ED,$F8,$F9,$DE

        .assert >msg_busted = >init, error, "tables must share one page"
        .assert >msg_shuffl = >init, error, "tables must share one page"
