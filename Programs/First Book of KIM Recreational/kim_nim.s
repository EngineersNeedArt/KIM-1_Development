; kim_nim.s -- KIM NIM, from The First Book of KIM
;
; A jumbo NIM for the KIM-1.  Six piles, one per display digit.  KIM
; matches wits with you: a duffer's game makes KIM sloppy, and as you
; start winning KIM moves up to the master player level.
;
; Hit GO and the lit digits are the piles.  Key A (left pile) through
; F (right pile) to choose one; it flashes.  Then key the number of
; items to take.  KIM picks a pile the same way (it flashes) and then
; takes some items.  The player who takes the last object wins; KIM
; shows "U LOSE" or "I LOSE".  GO starts a new game at any time.
;
; Strategy: EOR all the piles together (the nim-sum).  If it is
; non-zero, some pile can be cut to (pile EOR nim-sum), leaving a
; nim-sum of zero.  KIM plays that move only when iq is below the
; random timer value; otherwise it takes one from the largest pile.
; Each KIM loss shifts a 0 into iq (smarter), each KIM win shifts in
; a 1 (dumber).
;
; Not in the book: init clears the work area ($00-$12) once at power-up
; so the display is blank until GO, and sets iq to a middling skill.
; The book leaves all of it as whatever the last program left behind.
;
; Runs from $0200.

        .include "kim.inc"

        .org PROGRAM_ORG

; ---- zero page (lowercase; kim.inc's TEMP is the monitor's $FC) ----
iq      = $00           ; computer skill; smaller = smarter
pile    = $01           ; selected pile, 1-6; 0 = none
move    = $02           ; 0 = your move; else computer's move step
temp    = $03           ; amount taken / new pile value
value   = $04           ; six pile sizes, $04-$09
flashr  = $0a           ; flash mask (and scratch slot for digit 0)
window  = $0b           ; six display digits, $0b-$10
cue     = $11           ; display delay counter
wait    = $12           ; computer's move delay counter

init:   ldx #wait               ; clear $00-$12: blank display,
        lda #0                  ; your move, no pile selected
clr:    sta iq,x
        dex
        bpl clr
        lda #$80                ; middling skill; $ff = duffer, $00 = master
        sta iq

begin:  jsr KEYIN               ; directional regs
        jsr GETKEY
        cmp #KEY_GO             ; "go" key?
        bne nogo                ; ..nope, skip

        ; ---- new game: deal six piles ----
        lda TIMER_READ          ; get random #
        ldx #2                  ; split into 3
split:  tay                     ; save a
        and #7                  ; extract 3 bits
        beq zinch               ; unless zero
        clc                     ; add two
        adc #2
zinch:  sta value,x             ; store pile val
        tya                     ; bring back rand
        lsr a
        lsr a
        lsr a
        dex
        bpl split
stall:  jsr KEYIN               ; wait for
        bne stall               ; key release
        lda TIMER_READ          ; new random #
        ldx #2                  ; split 3 ways
splat:  tay                     ; again
        and #7                  ; 3 bits
        sta value+3,x
        tya
        lsr a
        lsr a
        lsr a
        dex
        bpl splat
        sta pile                ; pile zero
        sta move                ; it's your move
        ldx #6                  ; for each pile
dress:  lda value-1,x           ; change to
        jsr seg                 ; segments
        dex
        bne dress

        ; ---- player's turn ----
nogo:   ldx move                ; whose move?
        bne nokey               ; ..computer's, skip
        cmp #$10                ; hex digit keyed?
        bcs nokey               ; ..no, skip
        cmp #0                  ; zero key?
        beq nokey               ; ..yes, skip
        cmp #$0a                ; alphabetic?
        bcc num                 ; ..no, numeric
        sec                     ; change a-f
        sbc #9                  ; to 1-6
        ldx pile                ; pile already..
        bne nokey               ; selected?
        tax
        lda flashr,x
        beq nokey               ; nothing in pile?
        stx pile                ; ..ok, mark pile
        sta flashr              ; store flash code
        bcs nokey               ; unconditional (carry set by sbc)
num:    ldx pile
        beq nokey               ; no pile selected
        sta temp                ; save number
        lda value-1,x           ; pile value
        cmp temp                ; pile big enough?
        bcc nokey               ; ..nope
        sbc temp                ; ..yes, take out
        jsr seg                 ; compute segments
        inc move                ; computer's move
        jsr survey              ; is end of game?
        bne nokey               ; ..no, keep going
        jsr message             ; ..yes, show message
        sta window              ; "i lose"
        lsr iq                  ; get smart!

        ; ---- all routines join here: display ----
nokey:  ldx pile
        lda flashr              ; flash pile
        eor flashr,x
        sta flashr,x
        lda #$7f
        sta SADD
light:  ldy #$13
        ldx #5
lite:   lda window,x
        sta SAD
        sty SBD
litex:  inc cue
        bne litex
        dey
        dey
        dex
        bpl lite
        inc wait
        bne light
        lda #$f8
        sta wait

        ; ---- computer's turn ----
        ldx move                ; whose move?
        beq exit                ; ..not computer's
        dex                     ; first step?
        bne try                 ; ..no, skip strategy
        lda #0
        ldx #5                  ; merge all piles
merge:  eor value,x             ; by eor-ing them
        dex
        bpl merge
        sta flashr              ; save eor product
        ldx #6                  ; re-examine piles
loop:   lda value-1,x
        eor flashr
        cmp value-1,x
        bcc found
        dex
        bne loop
        beq moveit
found:  ldy iq                  ; iq high enuff?
        cpy TIMER_READ          ; ..randomly..
        bcs moveit              ; ..no, move dumb
        sta temp                ; amount
        stx pile                ; pile number
moveit: ldx pile
        lda flashr,x            ; flash mask
        sta flashr              ; flash...
try:    inc move                ; but don't make
        lda move                ; the move until
        cmp #$10                ; time has passed
        bcc exit
        ldx pile                ; time to move!
        lda temp
        jsr seg                 ; make move
        jsr survey              ; end of game?
        bne keep                ; ..nope, keep goin
        jsr message             ; "u lose"
        sec                     ; dummy up
        rol iq                  ; the computer
keep:   lda #0
        sta move                ; it's your move
        sta pile                ; un-flash
exit:   cld
        jmp begin

; ---- end of play: copy the message into the display ----
message:
        lda #0
        sta move                ; end of play
        sta pile                ; no flashing
        ldx #6                  ; move 7 digits
mloop:  lda data,x              ; pick em up
        sta flashr,x            ; put em down
        dex
        bpl mloop
        rts

; ---- survey piles: find the largest; z set if all empty ----
survey: lda #0
        sta flashr              ; un-flash
        ldx #6                  ; for all piles
revue:  cmp value-1,x
        bcs small
        lda value-1,x
        sta temp
        stx pile
small:  dex
        bne revue
        dec temp
        tay                     ; test a
        rts

; ---- store value, convert to segments in the window ----
seg:    sta value-1,x           ; store value
        beq nil                 ; blank digit
        tay
        lda TABLE,y
nil:    sta flashr,x            ; segments to window
        lda #0
        rts

        .byte $ff               ; unused; keeps data at $033b as in the book
data:   .byte $06,$be,$00,$b8,$bf,$ed,$f9       ; "u lose" (06 = "i")
