; directory.s -- DIRECTORY tape utility (The First Book of KIM, Utilities)
;
; Start it, then start the audio tape input.  When a program is found, the
; display shows its start address (four left digits) and its program ID
; (two right digits).  Hit any key to scan for the next program.
;
; Fully relocatable.  The first part (through the BNE at the second "tst"
; branch) does the same job as the KIM monitor's LOAD sync search.

        .include "kim.inc"

; Monitor tape routines used here that kim.inc does not define
RDBIT       = $1A41     ; read one bit from tape (returned in bit 7 of A)
RDCHT       = $1A24     ; read one character from tape
RDBYT       = $19F3     ; read one byte from tape

        .segment "ZPDATA"       ; kim.cfg: loaded at $0000, file directory-zp.bin

go:     cld
        lda #$07                ; port B data (book: "directional reg")
        sta SBD
syn:    jsr RDBIT               ; scan through bits..
        lsr INH                 ; ..shifting new bit
        ora INH                 ; ..into left of
        sta INH                 ; ..byte INH
tst:    cmp #$16                ; SYNC character?
        bne syn                 ; no, back to bits
        jsr RDCHT               ; get a character
        dec INH                 ; count 22 SYNCs
        bpl tst
        cmp #$2A                ; then test asterisk
        bne tst                 ; ..or SYNC
        ldx #$FD                ; if asterisk,
rd:     jsr RDBYT               ; stack 3 bytes
        sta POINTH+1,x          ; into display area (zero page wraps:
        inx                     ; X = $FD,$FE,$FF -> INH,POINTL,POINTH)
        bmi rd
show:   jsr SCANDS              ; ..and shine
        bne go                  ; until keyed
        beq show                ; that's all folks
