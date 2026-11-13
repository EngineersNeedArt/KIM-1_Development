; multi-maze.s -- MULTI-MAZE for the KIM-1
; From "The First Book of KIM".  Starts at $0200.
;
; You are the flashing light in the centre of the display.  Move with
;   9 = up   1 = down   4 = left   6 = right
; and the walls of the maze scroll past.  Only a small window of the
; maze is visible at any time.  Reaching the large open area means you
; have won.  Press GO at any time for a new maze.

        .include "kim.inc"

; ---- zero page ----
rnd     = $d0           ; random seed / maze patch bits
mzpt    = $d2           ; pointer into maze (2 bytes, indexed column pair)
posit   = $d4           ; vertical position
plug    = $d5           ; flasher countdown
stall   = $d6           ; display delay counter
sok     = $d7           ; last key seen
work    = $d8           ; 6 rows x 2 bytes; work+6 holds the flasher digit

        .org PROGRAM_ORG

restart:
        inc rnd                 ; random seed
        jsr KEYIN
        bne restart             ; wait for key release
        ldx #7                  ; patch the maze
@patch: rol rnd                 ; in 8 places
        bcc @next
        ldy place,x
        lda point1,x
        eor maze,y
        sta maze,y
        iny
        iny
        lda point2,x
        eor maze,y
        sta maze,y
@next:  dex
        bpl @patch
        ldx #2
        cld
slink:  bmi restart
setup:  lda init,x              ; 3 values from init
        sta mzpt,x
        dex
        bpl setup

; ---- pick out specific part of maze ----
map:    ldy #11
getmor: lda (mzpt),y            ; 6 rows x 2
        sta work,y
        dey
        bpl getmor

; ---- shift for vertical position ----
        ldx #10                 ; for each of 6 rows
nxdig:  ldy posit               ; shift Y positions
        lda #$ff                ; filling with 'walls'
rerol:  sec                     ; on both sides
        rol work+1,x
        rol work,x              ; roll 'em
        rol a
        dey
        bne rerol

; ---- calculate segments ----
        and #7
        tay
        lda tab1,y              ; 3 bits to segment
        sta work,x              ; stored
        dex
        dex
        bpl nxdig

; ---- test flasher ----
light:  dec plug                ; time out?
        bpl mug                 ; ..no
        lda #5                  ; ..yes, reset
        sta plug
        lda work+6              ; and
        eor #$40                ; flip
        sta work+6              ; flasher

; ---- light display ----
mug:    lda #$7f                ; open the gate
        sta SADD
        ldy #$09
        ldx #10
show:   lda work,x              ; tiptoe thru
        sta SAD                 ; the segments
        sty SBD
st1:    dec stall               ; pausing
        bne st1
        iny
        iny
        dex
        dex
        bpl show

; ---- test new key depression ----
        jsr KEYIN               ; set direction register
        jsr GETKEY
        cmp sok                 ; same as last?
        beq light
        sta sok

; ---- test which key ----
        ldx #4                  ; 5 items in table
scan:   cmp tab2,x
        beq found
        dex
        bpl scan
        bmi light
found:  dex
        bmi slink               ; 'GO' key?
        ldy tab3,x
        lda work,y
        and tab4,x
        bne light               ; wall in the way

; ---- move ----
        dex
        bpl notup
        dec posit               ; upward move
mlink:  bne map                 ; l..o..n..g branch
notup:  bne sidewy
        inc posit               ; downward move
        bne mlink
sidewy: dex
        bne left
right:  dec mzpt                ; right move
        dec mzpt
        bne mlink
left:   inc mzpt                ; left move
        inc mzpt
        bne mlink
        beq right

; ---- tables ----
tab1:   .byte $00, $08, $40, $48, $01, $09, $41, $49    ; 3 bits -> segments
tab2:   .byte KEY_GO, $09, $01, $06, $04                ; GO, up, down, right, left
tab3:   .byte $06, $06, $04, $08                        ; work offsets to test
tab4:   .byte $01, $08, $40, $40                        ; wall bit masks

; init and the last byte of tab4 must sit directly before maze:
; the first column window starts 4 bytes ahead of it.
init:   .word maze-4            ; initial mzpt
        .byte 8                 ; initial posit

maze:   .byte $ff, $ff, $04, $00, $f5, $7f, $15, $00
        .byte $41, $fe, $5f, $04, $51, $7d, $5d, $04
        .byte $51, $b6, $54, $14, $f7, $d5, $04, $54
        .byte $7f, $5e, $01, $00, $fd, $ff, $00, $00
        .byte $00, $00, $00, $00, $00, $00, $00, $00
        .byte $00, $00

place:  .byte $05, $0b, $10, $10, $14, $18, $17, $10    ; patch offsets
point1: .byte $01, $04, $80, $10, $80, $02, $40, $40
point2: .byte $02, $02, $40, $01, $10, $04, $80, $10
