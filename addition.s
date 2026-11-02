; addition.s -- six-digit adding machine for the KIM-1 / PAL-2
; From "The First Book of KIM"
;
; GO clears the total.  Key in a number, press + to add it to the total.
; To fix a mistake while entering, press 0 several times to roll the bad
; digits out the left end, then retype.  No overflow indication, no
; subtraction or multiplication.  Fully relocatable (no absolute addresses
; inside the program; only monitor calls).
;
; The display (INH, POINTL, POINTH) holds six BCD digits, low byte first.
; ACCUM holds the running total in the same order.

        .include "kim.inc"

; ---- Zero page variables (user area is $00-$EE) ----
prev    = $60                   ; last key seen (for debounce)
flag    = $61                   ; 0 = total is in display, <>0 = entering digits
accum   = $62                   ; 3 bytes, BCD running total, low byte first

        .org PROGRAM_ORG

; NOTE: this label used to be START in the book, which collides with the
; monitor's START ($1C4F) in kim.inc.
main:   jsr SCANDS              ; light display
        jsr GETKEY              ; read keyboard
        cmp prev                ; same as last time?
        beq main                ; ..yes, skip
        sta prev                ; ..no, save new key
        cmp #$0a                ; numeric key?
        bcc num                 ; ..yes, branch
        cmp #KEY_GO             ; GO key?
        beq do_go               ; ..yes, branch
        cmp #KEY_PLUS           ; + key?
        bne main                ; ..no, invalid key

; ---- + : add display to total, show the result ----
        sed                     ; decimal mode
        clc                     ; prepare to add
        ldx #<-3                ; X = $FD, counts -3..-1 (3 bytes)
; Indexed zero-page wraps within page 0, so INH+3,x with X=$FD is INH,
; and accum+3,x with X=$FD is accum.  The loop is written with INX/BMI
; because CPX would clobber the carry we need between bytes.
add_lp: lda INH+3,x             ; display byte
        adc accum+3,x           ; add total
        sta INH+3,x             ; sum to display
        sta accum+3,x           ; ..and to total
        inx                     ; next byte (leaves carry alone)
        bmi add_lp              ; more bytes?
        stx flag                ; X = 0: flag total-in-display
        cld
        bpl main                ; always taken (N = 0 after INX to 0)

; ---- GO : clear the display, mark total-in-display ----
do_go:  lda #0
        sta flag                ; total-in-display
        ldx #2                  ; 3 bytes
clear:  sta INH,x               ; clear display
        dex                     ; next byte
        bpl clear               ; more bytes?
        bmi main                ; finished (N = 1 after DEX to $FF)

; ---- digit key ----
num:    ldy flag                ; total in display?
        bne pass                ; ..no, just add new digit
        inc flag                ; ..yes, clear total-in-display flag
        pha                     ; save key
        ldx #2                  ; 3 bytes to move
move:   lda INH,x               ; get display byte
        sta accum,x             ; copy to total
        sty INH,x               ; clear display (Y = 0)
        dex                     ; next byte
        bpl move                ; more bytes?
        pla                     ; recall key

; Shift the digit in A (low nibble) into the display from the right.
pass:   asl a                   ; move digit to the
        asl a                   ; high nibble
        asl a
        asl a
        ldx #4                  ; 4 bits
shift:  asl a                   ; bit from A
        rol INH                 ; ..into INH
        rol POINTL              ; ..then the rest of the display
        rol POINTH
        dex                     ; next bit
        bne shift               ; more bits?
        beq main                ; ..no, back to main (Z = 1 after DEX to 0)
