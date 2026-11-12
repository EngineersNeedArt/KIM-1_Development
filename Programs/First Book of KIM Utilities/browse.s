; browse.s -- BROWSE mini-monitor (The First Book of KIM, Utilities)
;
; A mini-monitor for entering and proof-reading programs.  Most keys work
; as usual, but:
;   +    start browsing forward through memory (keeps going by itself)
;   PC   browse backward
;   any other key freezes the browsing
;   DA   data entry steps to the next address automatically: set the
;        address *before* the one to change, then just key in digits; the
;        display shows the last value entered.  No "+" needed.
;
; Fully relocatable.  The book lists it at $0110; start it with AD 0 1 1 0 GO.

        .include "kim.inc"

; Monitor entry points used here that kim.inc does not define
SCAND       = $1F19     ; load INH from (POINTL), then fall into SCANDS
INCPT       = $1F63     ; increment POINTL/POINTH
GOEXEC      = $1DC8     ; GO: start the program at POINTL/POINTH

; Zero-page cells the program reuses
WAIT        = ACC       ; browse-speed counter
DIGIT       = YREG      ; DA entry: which hex digit of the byte comes next

        .segment "PAGE1"

        .res $10                ; keep the book's start address of $0110

begin:  cld
        lda #$13                ; "GO" key image
        sta CHAR
        lda #$00                ; value zero..
        sta POINTL              ; ..to address pointer
        sta POINTH

loop:   dec WAIT                ; main program loop
        bne lp1                 ; pause between browse steps
        lda TMPX                ; up or down?
        beq lp1                 ; neither
        bpl up
        lda POINTL              ; down, decrement
        bne down                ; next page?
        dec POINTH
down:   dec POINTL
lp1:    jsr SCAND               ; light display
        jsr GETKEY              ; check keys
        cmp CHAR                ; same key as last time?
        beq loop
        sta CHAR                ; note new key input
        cmp #KEY_NONE           ; no key?
        beq loop                ; yes, skip
        ldx #0
        stx TMPX                ; clear up/down flag
        cmp #$10                ; numeric?
        bcc num                 ; yes, branch
        stx DIGIT
        cmp #KEY_DA             ; "DA"?
        beq over                ; yes, leave X=0
        inx                     ; no, set X=1
over:   stx MODE                ; 0 or 1 into MODE
        cmp #KEY_PLUS           ; "+"?
        bne pass                ; no, skip
        inc TMPX                ; yes, set browse
pass:   cmp #KEY_PC             ; "PC"?
        bne pass2               ; no, skip
        dec TMPX                ; yes, down-browse
pass2:  cmp #KEY_GO             ; "GO"?
        bne lp1                 ; no, loop
        jmp GOEXEC              ; start program

; Numeric (hex) entry comes here
num:    asl a                   ; position digit..
        asl a
        asl a
        asl a                   ; ..to left
        sta TEMP
        ldx #4                  ; 4 bits to move
        ldy MODE                ; "AD" or "DA"?
        bne addr                ; branch if "AD" mode
        dec DIGIT               ; time to step?
        bpl same                ; no, skip
        jsr INCPT               ; yes, step
        inc DIGIT               ; ..and restore
        inc DIGIT               ; ..digit count
same:   lda (POINTL),y          ; get data
dada:   asl TEMP                ; move a bit..
        rol a                   ; ..into data
        sta (POINTL),y
        dex
        bne dada                ; last bit?
        beq lp1                 ; yes, exit
addr:   asl a                   ; move bits
        rol POINTL              ; ..into address
        rol POINTH
        dex
        bne addr
        beq lp1

; Increment address for browsing
up:     jsr INCPT
        tax                     ; A is positive here, so N is clear:
        bpl lp1                 ; an always-taken branch back to the display
