; relocate.s -- RELOCATE, by Jim Butterfield
; (The First Book of KIM, Utilities)
;
; Fixes up the addresses and branches in a program before you open it up,
; close it up, or move it.  It doesn't move any data.  Zero-page addresses
; are left alone, and it won't warn you if a branch goes out of range.
;
; The program must be a continuous series of instructions (no data mixed
; in: a data value of $10 would be taken for a BPL) with a dud instruction
; ($FF) placed behind the last one to mark the end.
;
; Before running, set these zero-page cells (low order first):
;   PAGLIM  $E7       page limit: addresses on this page or above are not
;                     relocated ($17 keeps timer, I/O and monitor
;                     addresses safe; $FF with expanded memory)
;   ADJST   $E8,$E9   increment: how far to move things above the boundary
;                     (+3 opens up three locations, $FFFC closes up four)
;   POINT   $EA,$EB   program start: the first instruction of the whole
;                     program, including the part that doesn't move
;   BOUND   $EC,$ED   boundary: the first address that will move
;
; Start at $0110.  When it halts (BRK), POINT should be pointing at the $FF
; that ends the program.  The BRK needs the IRQ vector ($17FE,$17FF) set to
; $1C00.  Then move the program with a separate move routine (or MOVIT).
;
; Credit for the concept of RELOCATE goes to Stan Ockers.

        .include "kim.inc"

PAGLIM      = $E7       ; limit above which relocation is off
ADJST       = $E8       ; adjustment distance (signed), 2 bytes
POINT       = $EA       ; start of program, 2 bytes
BOUND       = $EC       ; lower boundary for adjustment, 2 bytes

; Scratch cells (not named in the book's header)
ALOC        = $E0       ; low order of the branch's own (adjusted) address
LIMIT       = $E3       ; $00 or $FF: sign extension of a branch offset

        .segment "PAGE1"

        .res $10                ; the book puts RELOCATE at $0110

begin:  cld
        ldy #0
        lda (POINT),y           ; get op code
        tay                     ; +cache in Y
        ldx #7
loop:   tya                     ; restore op code
        and tab1-1,x            ; remove unwanted bits
        eor tab2-1,x            ; ..& test the rest
        beq found
        dex                     ; on to the next test
        bne loop                ; if any
found:  ldy tab3,x              ; length or flag
        bmi trip                ; triple length?
        beq bran                ; branch?
skip:   inc POINT               ; moving right along
        bne inex                ; to next op code
        inc POINT+1
inex:   dey
        bne skip
        beq begin

; Length 3 or illegal
trip:   iny
        bmi begin+2             ; illegal/end: go to the BRK (the $00 operand
                                ; of the "ldy #0" above)
        iny                     ; set Y to 1
        lda (POINT),y           ; lo-order operand
        tax                     ; into X reg
        iny                     ; Y=2
        lda (POINT),y           ; hi-order operand
        jsr adjust              ; change address, maybe
        sta (POINT),y           ; and put it back
        dey                     ; Y=1
        txa
        sta (POINT),y           ; ..also lo-order
        ldy #3                  ; Y=3
        bpl skip

; Branch: check "to" and "from" address
bran:   iny                     ; Y=1
        ldx POINT               ; "from" address lo-order
        lda POINT+1             ; ..& hi-order
        jsr adjust              ; change, maybe
        stx ALOC                ; save lo-order only
        ldx #$FF                ; flag for "back" branches
        lda (POINT),y           ; get relative branch
        clc
        adc #2                  ; adjust the offset
        bmi over                ; backwards branch?
        inx                     ; ..nope
over:   stx LIMIT
        clc
        adc POINT               ; calculate "to" lo-order
        tax                     ; and put in X
        lda LIMIT               ; 00 or FF
        adc POINT+1             ; "to" hi-order
        jsr adjust              ; change, maybe
        dex                     ; reduce to just the offset
        dex
        txa
        sec
        sbc ALOC                ; recalculate relative branch
        sta (POINT),y           ; and re-insert
        iny                     ; Y=2
        bpl skip

; Examine address (A = high, X = low) and adjust, maybe
adjust: cmp PAGLIM
        bcs out                 ; too high?
        cmp BOUND+1
        bne tes2                ; hi-order?
        cpx BOUND               ; lo-order?
tes2:   bcc out                 ; too low?
        pha                     ; stack hi-order
        txa
        clc
        adc ADJST               ; adjust lo-order
        tax
        pla                     ; unstack hi-order
        adc ADJST+1             ; and adjust
out:    rts

; Tables for op-code identification.  The opcode is ANDed with tab1 and
; compared with tab2; the first match from the top (X = 7) picks the entry
; in tab3: $FF = three bytes, $FE = illegal/end, $00 = branch, else length.
; No match gives tab3[0] = 2 bytes.
tab1:   .byte $0C,$1F,$0D,$87,$1F,$FF,$03
tab2:   .byte $0C,$19,$08,$00,$10,$20,$03
tab3:   .byte $02,$FF,$FF,$01,$01,$00,$FF,$FE
