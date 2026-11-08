; reaction.s -- speed of reaction test
; From The First Book of KIM. Starts at $0300.
;
; Press GO and the display blanks for a random period of time. When it
; lights, hit any numbered key. The number shown is your reaction time
; (smaller is faster). Press GO for each new test.

        .include "kim.inc"

        .org $0300

restart:
        lda INH             ; randomize delay
        rol a               ; by multiplying
        adc INH             ; by 3 and
        and #$7f            ; masking
        sta POINTH          ; work in display area

zip:    jsr KEYIN           ; if you cheat by keying...
        bne zip             ; ...program waits you out
        inc POINTL
        bne zip             ; count down for
        inc POINTH
        bne zip             ; random delay

        sta INH             ; set to zero

run:    ldx #$fd            ; negative three
        sed                 ; count in decimal
        sec                 ; add value 1
digit:  lda POINTH+1,x      ; INH, POINTL, POINTH (zero-page wrap)
        adc #$00            ; add it in
        sta POINTH+1,x
        inx                 ; move on to next digits
        bne digit
        cld
        jsr SCANDS          ; light up count
        beq run             ; and keep counting

stand:  jsr SCANDS
        jsr GETKEY
        cmp #KEY_GO         ; "GO" key depressed?
        bne stand           ; ..nope, hold it
        beq restart         ; ..yup, start over
