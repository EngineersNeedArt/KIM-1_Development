; super-dupe.s -- SUPER-DUPE, by Jim Butterfield
; "The First Book of KIM", Utilities section, pp. 138-140
;
; Copies a whole cassette, program by program: reads one KIM-format
; program into a RAM buffer, shows its start address + ID on the display,
; then rewrites it at a density chosen with a key (1 = Hypertape ... 6 = normal).
;
; Starts at $0000 (GO).  Needs HYPERTAPE! resident at $0100 (the book says
; "you must also include HYPERTAPE!"); this program only calls into it.
;
; Source follows the hex dump on p. 140, not the printed listing, which
; omits CMP #7 / BCS and repeats LDX #$64 / LDA #$16 before the HIC call.
;
; Keys:   0   skip this program, read the next
;         1-6 write it (1 = Hypertape, 6 = regular KIM tape)
;         7+  ignored
; Display after a write: 0000 A2  -- stop the output recorder, hit GO.

        .include "kim.inc"

; ---- Zero page ----
; NOTE: the book names F6 = CHKSUM (low) and F7 = CHKHI.  kim.inc has
; these two names the other way round, and the code depends on the real
; cells, so they are given neutral names here.
sum_lo  = $f6           ; running checksum, low  (book: CHKSUM)
sum_hi  = $f7           ; running checksum, high (book: CHKHI)
point   = $e0           ; end pointer: next free byte of the buffer
point2  = $e2           ; write pointer: start of buffer
gang    = $f5           ; scratch (same cell as XREG in kim.inc)

; ---- KIM monitor ROM routines (not in kim.inc) ----
RDBYT   = $19f3         ; read tape byte -> A
RDCHT   = $1a24         ; read tape character -> A
PACKT   = $1a00         ; pack ASCII hex char into A (Z = 1 if good)
RDBIT   = $1a41         ; read tape bit
LOADT9  = $1929         ; "FFFF option" re-entry into the monitor loader
CHK     = $1f91         ; add A to checksum

; ---- HYPERTAPE! entry points (see hypertape.s, staged at $0100) ----
HIC     = $0161         ; send X characters of A (sync leader)
OUTBT   = $0170         ; write byte A, with checksum
OUTCHT  = $0188         ; write character A
EXIT    = $0154         ; finish: write last byte, return to monitor
NPUL    = $01be         ; Hypertape pulse-count cell
TIMG    = $01bf         ; Hypertape timing cell (code uses TIMG+1)

        .segment "ZPDATA"

start:  ldx #3                  ; copy the 4-byte data area at $E2 into
loop:   lda point2,x            ; $E0-$E3, so point = buffer address
        sta point,x             ; and point2 = buffer address
        dex
        bpl loop
        lda #0
        sta sum_lo
        sta sum_hi
        cld
        lda #7
        sta SBD
syn:    jsr RDBIT               ; shift bits in until the sync char ($16)
        lsr INH
        ora INH
        sta INH
tst:    cmp #$16                ; sync?
        bne syn
        jsr RDCHT
        dec INH
        bpl tst
        cmp #$2a                ; start-of-data char
        bne tst
        jsr RDBYT               ; ID
        sta INH
        ldx #$fe                ; neg 2
addr:   jsr RDBYT               ; start address -> POINTL, POINTH
        sta POINTH+1,x
        jsr CHK
        inx
        bmi addr
byte:   ldx #2
dubl:   jsr RDCHT
        cmp #$2f                ; eot?
        beq wind
        jsr PACKT
        bne elnk                ; error?
        dex
        bne dubl
        sta (point,x)
        jsr CHK
        inc point
        bne over
        inc point+1
over:   bne byte
wind:   jsr RDBYT
        cmp sum_hi
        bne elnk                ; error?
        jsr RDBYT
        cmp sum_lo
elnk:   bne start               ; (or 65?)
flsh:   jsr SCANDS
        beq flsh                ; display SA, ID
        jsr GETKEY
        cmp #7
        bcs flsh                ; only 0-6 are density keys
        sta gang
        asl a
        beq start               ; key 0: skip this program
        sta NPUL
        adc gang                ; carry is clear (key < 7)
        sta TIMG+1
        lda #$27                ; register mask
        sta gang
        lda #$bf
        sta SBDD                ; port B direction (book calls it PBDD)
        ldx #$64                ; send 100
        lda #$16                ; sync
        jsr HIC
        lda #$2a                ; start char
        jsr OUTCHT
        lda INH                 ; write ID
        jsr OUTBT
        lda POINTL              ; start adds
        jsr OUTBT
        lda POINTH
        jsr OUTBT
data:   ldy #0
        lda (point2),y
        jsr OUTBT               ; write data
        inc point2
        bne samp                ; next addrs
        inc point2+1
samp:   lda point2
        cmp point
        lda point2+1
        sbc point+1
        bcc data                ; more data?
        lda #$2f                ; eot
        jsr OUTCHT
        lda sum_hi              ; checksum
        jsr OUTBT
        lda sum_lo
        jmp EXIT

        .byte $ff,$ea           ; unused; present in the book's hex dump

ffff_opt:  jmp LOADT9              ; FFFF option

        .res $00e2 - (ffff_opt - start) - 3        ; pad to the data area

; data area; set as desired.  Buffer address, given twice (see start).
        .word $0200, $0200
