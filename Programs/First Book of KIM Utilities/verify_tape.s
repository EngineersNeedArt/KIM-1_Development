; verify_tape.s -- VERIFY TAPE (The First Book of KIM, Utilities)
;
; Compares a cassette tape against memory instead of loading it.
;
; 1) Check that the start address (SAL,SAH = $17F5,$17F6), end address
;    (EAL,EAH = $17F7,$17F8) and block ID ($17F9) are right in memory.
; 2) Put $00 in CHKL ($17E7) and CHKH ($17E8).
; 3) Put the 11 bytes below at $17EC (VEB), i.e. load verifytape.bin
;    there.  It replaces the monitor's usual "store byte" subroutine:
;    the loader calls VEB with each tape byte in A, and the monitor's own
;    routines (INTVEB/INCVEB) keep the address inside the CMP up to date.
; 4) Rewind the tape, GO at $188C (not $1873), and play the tape back.
;    The display relights with 0000 if the tape matches memory, or FFFF if
;    not.
;
; Note: the routine occupies $17EC-$17F6, so its last JMP overwrites
; SAL and SAH ($17F5,$17F6) with $29,$19.  Per the KIM manual, SAL/SAH are
; only used on load when the ID is $FF.

        .include "kim.inc"

LOAD12      = $190F     ; monitor: carry on with the load loop
LOADT9      = $1929     ; monitor: error exit (display FFFF)

        .segment "CODE"

; Assembles to  CD 00 00  D0 03  4C 0F 19  4C 29 19
veb:    cmp a:$0000             ; absolute on purpose: the monitor patches the
                                ; address in the two bytes after the opcode
        bne failed
        jmp LOAD12
failed: jmp LOADT9
