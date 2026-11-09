; mini program A - swap the contents of $10 and $11

        .org $0200

start:  lda $10       ; $10 to A
        ldx $11       ; $11 to X
        sta $11       ; A to $11
        stx $10       ; X to $10
        brk           ; stop the program
