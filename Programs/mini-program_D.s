; mini program D - show the code of the key being pressed

        .include "kim.inc"

start:  cld             ; clear decimal mode
        lda #0          ; zero into A
store:  sta POINTH      ; first 2 digits
        sta POINTL      ; next 2 digits
        sta INH         ; last 2 digits
        jsr SCANDS      ; light display
        jsr GETKEY      ; test keys
        jmp store       ; and show the result