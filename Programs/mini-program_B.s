; mini program B - zero the ten bytes from $30 to $39

        .org $0200

start:  lda #0          ; value 0 into A
        ldx #9          ; start X at 9
loop:   sta $30,x       ; zero into $0030+X
        dex             ; decrease X by 1
        bpl loop        ; back if X positive
        brk             ; stop the program