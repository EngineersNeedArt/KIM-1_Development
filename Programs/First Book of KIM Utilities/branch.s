; branch.s -- relative branch calculator (The First Book of KIM, Utilities)
;
; Fully relocatable. Key in the last two digits of the address of the
; branch instruction, then the last two digits of the address being
; branched to. The offset appears on the two right-hand display digits.
;
; Example: for the BNE at $0026 branching to $0020, key 26 then 20;
; the display shows F8 on the right.
;
; The program is stopped with the RS key.
;
; Uses zero page only for ACC (as the "last key" cell), INH, POINTL and
; POINTH.  POINTH = branch address, POINTL = target; the offset is
; target - branch - 2, computed as POINTL - POINTH - 1 (CLC before SBC)
; followed by one DEC.

        .include "kim.inc"

        .segment "ZPDATA"       ; kim.cfg: loaded at $0000, file branch-zp.bin

begin:  cld
        clc
        lda POINTL              ; target
        sbc POINTH              ; minus branch address, minus 1 (carry clear)
        sta INH
        dec INH                 ; minus 2 more in total: relative offset
        jsr SCANDS              ; POINTH POINTL INH on the display
        jsr GETKEY
        cmp ACC                 ; ACC holds the last key seen
        beq begin               ; same as last time: key still held
        sta ACC
        cmp #$10
        bcs begin               ; not a hex key (also records key release)
        asl a                   ; move key into the high nibble
        asl a
        asl a
        asl a
        ldx #4
shift:  asl a                   ; shift the nibble into POINTL / POINTH
        rol POINTL
        rol POINTH
        dex
        bne shift
        beq begin               ; always taken (X = 0)
