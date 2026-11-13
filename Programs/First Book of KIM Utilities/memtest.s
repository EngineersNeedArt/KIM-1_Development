; memtest.s -- MEMORY TEST (The First Book of KIM, Utilities)
;
; Fast RAM test that also looks for interference between locations.
; Adapted from an algorithm by Knaizuk and Hartmann (IEEE Transactions on
; Computers, April 1977).
;
; Each pass fills the area with FLIP, changes every third location to
; FLAG, then checks everything.  That is repeated with the "third"
; shifted twice more.  The whole thing runs twice, with FF and 00
; interchanged (FLAG = 00 first, FF second).
;
; To run: put the first and last page to test in $0000 and $0001, then
; start at $0002.  It halts with an address on the display.  If memory is
; good that is one past the last location tested; otherwise it is the
; first bad location.
;
; Example: for $0100-$02FF set $0000 = 01, $0001 = 02 and start at $0002;
; good memory shows 0300.
;
; Page 0 itself can't be tested (the program and its pointer live there).
; The program makes no subroutine calls, so testing the stack page is fine.

        .include "kim.inc"

; Zero-page cells.  The first two are the bytes at the start of the program
; (set them before running); the others are at the book's addresses, just
; above the code.
FIRST_PAGE  = $00           ; starting page for test
LAST_PAGE   = $01           ; ending page for test
FLAG        = $70           ; $00 first pass, $FF second pass
FLIP        = $71           ; the other value: $FF first pass, $00 second
PHASE       = $72           ; which third gets FLAG (book: MOD)

        .segment "ZPDATA"       ; kim.cfg: loaded at $0000, file memtest-zp.bin

        .byte $00, $00          ; FIRST_PAGE, LAST_PAGE

begin:  lda #0                  ; zero pointers
        tay                     ; for low-order
        sta POINTL              ; addresses;
biglp:  sta FLAG                ; =00 first pass, =FF second pass
        ldx #2
        stx PHASE               ; set 3 tests each pass
pass:   lda FIRST_PAGE          ; set pointer to
        sta POINTH              ; start of test area
        ldx LAST_PAGE
        lda FLAG
        eor #$FF                ; reverse FLAG;
        sta FLIP                ; FF first pass, 00 second pass
clear:  sta (POINTL),y          ; write above FLIP value
        iny                     ; into all locations
        bne clear
        inc POINTH
        cpx POINTH
        bcs clear

; FLIP value in all locations - now change 1 in 3
        ldx PHASE
        lda FIRST_PAGE          ; set pointer
        sta POINTH              ; back to start
fill:   lda FLAG                ; change value
top:    dex
        bpl skip                ; skip 2 out of 3
        ldx #2                  ; restore 3-counter
        sta (POINTL),y          ; change 1 out of 3
skip:   iny
        bne top
        inc POINTH              ; new page
        lda LAST_PAGE           ; have we passed
        cmp POINTH              ; end of test area?
        bcs fill                ; nope, keep going

; Memory set up - now test it
        lda FIRST_PAGE          ; set pointer..
        sta POINTH              ; back to start
        ldx PHASE               ; set up 3-counter
pop:    lda FLIP                ; test for FLIP value
        dex                     ; ..2 out of 3 times..
        bpl slip                ;     - or -
        ldx #2                  ; 1 out of 3
        lda FLAG                ; test for FLAG value;
slip:   cmp (POINTL),y          ; here's the test...
        bne out                 ; branch if failed
        iny
        bne pop
        inc POINTH
        lda LAST_PAGE
        cmp POINTH
        bcs pop

; Above test OK - change & repeat
        dec PHASE               ; change 1/3 position
        bpl pass                ; .. & do next third
        lda FLAG                ; invert
        eor #$FF                ; flag for pass two
        bmi biglp
out:    sty POINTL              ; put low order address to display
        jmp START               ; and exit to KIM
