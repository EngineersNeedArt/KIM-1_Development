; vutape.s -- VUTAPE (The First Book of KIM, Utilities)
;
; Lets you watch the contents of a KIM-format tape as it goes by.  First
; the display shows the bit stream as the processor tries to synchronize
; (a steady sync shows segments b, c and e on the right-hand digit), then
; the characters roll across the six digits one at a time until an END or
; illegal character drops it back into sync mode.  Useful for diagnosing
; tape and recorder trouble, and for seeing how data is stored on tape.
;
; Starts at $0000 and is fully relocatable.
;
; Test tape: the second routine (start at $0050) writes an endless stream
; of SYNC characters.  Record a little of it, then play it back under
; VUTAPE: the display should show a steady b-c-e pattern on the right-hand
; digit.  Vary the volume and tone controls to see over what range the
; pattern stays locked in; the wider the range, the better the cassette
; and recorder.

        .include "kim.inc"

; Monitor entry points used here that kim.inc does not define
RDBIT       = $1A41     ; read one bit from tape (in bit 7 of A)
RDCHT       = $1A24     ; read one character from tape
PACKT       = $1A00     ; ASCII in A -> hex; Z set if the character was legal
OUTCHT      = $197A     ; write the character in A to tape
                        ; (kim.inc's OUTCH is the teleprinter routine)

WINDOW      = $E0       ; digit-select value of the display position in use
                        ; (book: POINT)

        .segment "ZPDATA"       ; kim.cfg: loaded at $0000, file vutape-zp.bin

begin:  cld
        lda #$7F
        sta SADD                ; set display direction register
syn:    lda #$13                ; window 6 (rightmost digit) and tape in
        sta WINDOW              ; and keep pointer
        sta SBD
        jsr RDBIT               ; get a bit and
        lsr INH                 ; slip it into
        ora INH                 ; the right-hand
        sta INH                 ; side:
        sta SAD                 ; show bit flow on display
tst:    cmp #$16                ; is it a SYNC?
        bne syn                 ; ..nope, keep 'em rolling
        jsr RDCHT               ; ..yup, start grabbing
        cmp #$2A                ; 8 bits at a time and
        bne tst                 ; if it's not an "*"
stream: lda #$00                ; then start showing
        sta SAVX                ; characters 1 at a time
        jsr RDCHT
        jsr PACKT               ; converting to hexadecimal,
        bne syn                 ; if legal
        ldx WINDOW
        inx
        inx                     ; move along to next
        cpx #$15                ; display position
        bne over                ; (if last digit,
        ldx #$09                ; reset to first)
over:   stx WINDOW
        stx SBD
        tax                     ; change character read
        lda TABLE,x             ; to segments and
        sta SAD                 ; send to the display
        bne stream              ; unconditional jump

; The book puts the test-tape writer at $0050
        .res 7

go:     ldy #$BF                ; directional..
        sty SBDD                ; ..registers (book calls it PBDD)
lp:     lda #$16                ; SYNC
        jsr OUTCHT              ; ..out to tape
        bne lp
