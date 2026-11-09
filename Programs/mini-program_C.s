; mini program C - light up the display with 000000

        .include "kim.inc"

start:  lda #0          ; zero into A
        sta POINTH      ; first 2 digits
        sta POINTL      ; next 2 digits
        sta INH         ; last 2 digits
loop:   jsr SCANDS      ; light up!
        jmp loop        ; do it again