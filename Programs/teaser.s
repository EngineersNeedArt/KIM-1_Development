; teaser.s -- TEASER for the KIM-1
;
; Adaptation of the "Shooting Stars" game for the KIM-1 keyboard and
; display, from The First Book of KIM.  Originally published in the
; Sept. '74 issue of PCC; a version also appeared in the May '76 issue
; of Byte.  Program starts at $0200.
;
; The starfield is shown on the horizontal segments of display digits
; 2-4 (top, middle and bottom segment of each, nine stars in all),
; numbered as in the diagram:
;
;       7 8 9       (key numbers, lower left = 1, upper right = 9)
;       4 5 6
;       1 2 3
;
; Shooting a star leaves a hole where it was, and the "explosion"
; flips the state of certain neighbouring stars/holes (star <-> hole);
; the flip patterns are in the "shots" table below.
;
; The game starts with a star in position 5 and holes elsewhere.  The
; object is to reverse that: 5 a hole and all the rest stars.  Eleven
; moves is the minimum.
;
; "Shooting" a hole puts "H" in the first digit until a star key is
; pressed.  The first digit otherwise shows the key just pressed.  The
; number of valid moves is shown in the two right-hand digits.  A win
; shows "F" in the first digit; all holes is a loss ("L").  Press GO
; at any time to start over.
;
; Starfield state is kept in two bytes.  The nine stars form a 9-bit
; field, star 1 = bit 0 ... star 9 = bit 8.  lofield holds bits 0-7
; (stars 1-8); hifield holds the field shifted right one bit, so its
; bit 7 is star 9.  Keys 1-5 are tested against lofield and keys 6-9
; against hifield.

; Note: the scanned listing had "A0 D0" for the LDY at dela; it is
; LDY #$00 (A0 00), as the comment on that line says.

        .include "kim.inc"

; ---- zero page ----
displ       = $00d0     ; display buffer: six digits at $d0,$d2,...,$da
                        ;   $d0 = status digit (key, H, F or L)
                        ;   $d2,$d4,$d6 = starfield digits
                        ;   $d8,$da = move count (tens, units)
keynum      = $00d1     ; last valid key (1-9)
gamemode    = $00d3     ; 0 = waiting for key, 1 = delay and update
midseg      = $00d4     ; middle starfield digit (initial middle segment)
count       = $00d5     ; valid move count (BCD)
lofield     = $00de     ; starfield bits 0-7 (stars 1-8)
hifield     = $00df     ; 9-bit field shifted right one bit (star 9 = bit 7)

seg_h       = $76       ; 7-segment "H"
seg_f       = $71       ; 7-segment "F"
seg_l       = $38       ; 7-segment "L"

        .org PROGRAM_ORG

begn:   lda #$00                ; zero registers $d0-$df
        ldx #$10
clop:   sta displ-1,x
        dex
        bne clop
        lda #$40                ; initialize display
        sta midseg
        lda #$10                ; initialize starfield registers
        sta lofield
        lsr a
        sta hifield
mlop:   jsr disp                ; display
        ldx gamemode            ; mode?
        bne dela                ; mode = 1: delay and update
        jsr KEYIN               ; mode = 0: get key
        beq mlop                ; no key, return
        jsr KEYIN               ; key still pressed?
        beq mlop                ; no, return
        jsr GETKEY              ; yes, get key
        cmp #KEY_GO             ; "GO" key?
        beq begn                ; yes, start again
        cmp #$0a                ; over 9?
        bpl mlop                ; yes, try again
        tay                     ; use as index
        beq mlop                ; 0? not valid
        sta keynum              ; 1-9, store it
        jsr seg                 ; convert to segments
        sta displ               ; display - left digit
        lda startest-1,y        ; get star test bit
        cpy #$06                ; test key number
        bmi skip                ; 1-5, skip
        bit hifield             ; 6-9, test hi field
        bne star                ; it's a star
        beq hole                ; it's a hole
skip:   bit lofield             ; 1-5, test lo field
        bne star                ; it's a star
hole:   lda #seg_h              ; it's a hole, load "H"
        sta displ               ; display - left digit
        bne mlop                ; unconditional jump

star:   sed                     ; update count
        sec
        lda #$00
        adc count               ; by adding one
        sta count               ; store it
        cld
        jsr seg                 ; unpack, convert
        sta displ+10            ; to segments and
        lda count               ; display in digits
        jsr left                ; 5 and 6
        sta displ+8
        inc gamemode            ; set mode to 1
        jmp mlop                ; main loop again

dela:   ldy #$00                ; mode = 1
dloop:  jsr disp                ; delay about 0.8 sec
        dey                     ; while displaying
        bne dloop
        ldx keynum              ; key number as index
        lda shots-1,x           ; get shot pattern
        tay                     ; save in Y register
        cpx #$06                ; key number over 5?
        bmi lowf                ; no, go to lo field
        eor hifield             ; update hi field, 6-9
        sta hifield
        tya                     ; recall pattern, 6-9
        ldy #$00                ; no shot 3rd time
        asl a                   ; align with lo field
lowf:   eor lofield             ; update lo field
        sta lofield
        tya                     ; recall pattern, 1-5
        lsr a                   ; align with hi field
        eor hifield             ; update hi field, 1-5
        sta hifield             ; (blank shot if 6-9)
        asl a                   ; shift 9 to carry
        lda lofield             ; get rest of field
        ldx #$06                ; star display
dlop:   rol a                   ; align with display
        pha                     ; save it for next time
        and #$49                ; mask to horizontal segments
        sta displ,x             ; into display window
        pla                     ; recall field
        dex                     ; shift to next
        dex                     ; display digit
        bne dlop                ; repeat until done
        rol a                   ; bit for 5 to carry
        bcs setmode0            ; 5 is star, continue
        beq lose                ; 5 is holes, all holes
        cmp #$ff                ; all the rest stars?
        bne setmode0            ; no
        lda #seg_f              ; yes, load "F"
        bne frst                ; and skip
lose:   lda #seg_l              ; load "L" (lose)
        bne frst                ; and skip
setmode0:
        dec gamemode            ; set mode to 0
        lda #$00                ; blank first digit
frst:   sta displ               ; fill first digit
        bne done                ; end of game
        jmp mlop                ; main loop again
done:   jsr disp                ; display until
        jsr KEYIN               ; "GO" key is
        jsr GETKEY              ; pushed
        cmp #KEY_GO
        bne done
        jmp begn                ; start a new game

; star test bits, indexed by key 1-9 (startest-1,y)
startest:
        .byte $01,$02,$04,$08,$10,$10,$20,$40,$80

; shot patterns, indexed by key 1-9 (shots-1,x)
shots:
        .byte $1b,$07,$36,$49,$ba,$92,$6c,$e0,$d8

; ---- display subroutine ----
disp:   lda #$7f                ; turn on display
        sta SADD
        ldx #$09
more:   lda displ-9,x           ; put in segments
        sty TEMP                ; save Y
        jsr OUTPUT              ; display them
        cpx #$15                ; done? 6 times
        bne more                ; no, loop
        rts                     ; yes, return

; ---- hex conversion subroutine ----
left:   lsr a
        lsr a
        lsr a
        lsr a
seg:    and #$0f                ; mask to 4 bits
        tay                     ; use as index
        lda TABLE,y             ; convert to segments
        rts                     ; return
