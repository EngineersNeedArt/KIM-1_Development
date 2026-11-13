; movit.s -- MOVIT block mover (The First Book of KIM, Utilities)
;
; Moves anything anywhere: no limit on the number of bytes, and the source
; and destination may overlap.  Use it to lift sections of code, to close
; up or open gaps, or to move a program (use Butterfield's RELOCATE to fix
; the branches and addresses afterward).
;
; Before running:
;   old start address in $D0,$D1   (OSAL, OSAH)
;   old end address   in $D2,$D3   (OEAL, OEAH)
;   new start address in $D4,$D5   (NSAL, NSAH)
; The program uses zero page $D0-$D9.
;
; It contains no absolute addresses, so it runs wherever it is loaded; the
; book puts it at $1780.  The break at the end needs the IRQ vector set to
; the monitor (KIM: $1C00 at $17FE,$17FF).
;
; The book's addition: assemble with -D SHOW_END to leave the last address
; filled in POINTL/POINTH and return to the monitor to display it.

        .include "kim.inc"

OSAL        = $D0       ; old start address
OSAH        = $D1
OEAL        = $D2       ; old end address
OEAH        = $D3
NSAL        = $D4       ; new start address
NSAH        = $D5
NEAL        = $D6       ; new end address (worked out below)
NEAH        = $D7
BCL         = $D8       ; byte count
BCH         = $D9

        .segment "CODE"

begin:  cld
        ldy #$FF                ; store test value
        sec
        lda OEAL                ; how many bytes
        sbc OSAL                ; ..to move?
        sta BCL
        lda OEAH
        sbc OSAH
        sta BCH
        clc
        lda BCL                 ; add the count to
        adc NSAL                ; the new start to
        sta NEAL                ; get a new end
.ifdef SHOW_END
        sta POINTL
.endif
        lda BCH
        adc NSAH
        sta NEAH
.ifdef SHOW_END
        sta POINTH
.endif
        inc BCL                 ; adjust the byte count
        inc BCH                 ; to permit zero testing
        sec
        lda NSAL                ; if new location
        sbc OSAL                ; higher than old
        lda NSAH                ; carry flag is set
        sbc OSAH
loop:   ldx #$00                ; LO pointer index
        bcc move
        ldx #$02                ; HI pointer index
move:   lda (OSAL,x)            ; move old
        sta (NSAL,x)            ; ..to new
        bcc down
        dec OEAL                ; adjust up pointer (old)
        tya                     ; below zero?
        eor OEAL
        bne no                  ; no, enough
        dec OEAH                ; yes, adjust the high byte
no:     dec NEAL                ; adjust the other one (new)
        tya
        eor NEAL                ; need high byte adjusted?
        bne nein                ; no
        dec NEAH                ; yes, do it
nein:   bcs count               ; (carry is still set)
down:   inc OSAL                ; adjust "old" down pointer
        bne nyet
        inc OSAH                ; and the high byte if needed
nyet:   inc NSAL                ; and the "new" one
        bne count
        inc NSAH
count:  dec BCL                 ; tick off the bytes,
        bne one                 ; enough fingers?
        dec BCH                 ; use the other hand
one:    bne loop                ; 'til they're all done
.ifdef SHOW_END
        jmp START               ; back to monitor, showing the last address
.else
        brk                     ; and back to monitor
.endif
