; farmer_brown.s -- Farmer Brown, from "The First Book of KIM"
;
; You are Farmer Brown, growing a crop of corn.  Animals (Ant, Bird, Cow,
; Dog, Elephant, Fox -- drawn in 7-segment form) walk in from the right
; across the six-digit display to steal it.  Press the key matching the
; animal's first letter (A..F) to send it back.  A wrong key is ignored.
; The animal can only be shooed once it is completely inside the display.
; An animal that gets all the way across costs you a bushel of corn; when
; the corn is gone the game ends.
;
; Starts at $0200.
; Speed: change the delay reload value at $026A (lower = faster).

        .include "kim.inc"

        .org PROGRAM_ORG

; ---- zero page ----
window  = $60           ; six display digits: $60-$65
wings   = window+6      ; six 'wings' locations: $66-$6B (animal waits here)
flag    = $6c           ; $FF = animal coming, $00 = animal retreating
got     = $6d           ; (cleared at start; maintained alongside corn)
corn    = $6e           ; bushels of corn left
key     = $6f           ; key code that shoos the current animal ($0A-$0F)
ptrl    = $70           ; indirect pointer to animal picture
ptrh    = $71
delay   = $72           ; countdown between animal moves
wait    = $73           ; display on-time counter

; ---- other ----
timer_rd = $1704        ; RIOT #1 timer, read for a random value
done    = $1925         ; monitor address jumped to at end of game
                        ; (not in kim.inc -- taken from the book listing)

start:
        ldx #13
        stx corn                ; bushels of corn to start
        lda #0                  ; clear the window (and flag, got)
sloop:  sta window,x
        dex
        bpl sloop

test:   ldx #11                 ; is window empty?
tloop:  lda window,x
        bne contin              ; ..no, keep going
        dex
        bpl tloop
        inc got                 ; ..yes, make new animal
        lda flag
        beq more                ; did last animal get in?
        dec got
        dec corn                ; take away some corn
        bne more                ; any left?
        jmp done                ; ..no, end of game

more:   lda timer_rd            ; random value..
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a                   ; to generate new random animal
        cmp #6                  ; 6 types of animal
        bcc make
        and #$03
make:   clc
        tax                     ; animal type to X
        adc #$0a                ; key type "A" to "F"
        sta key
        lda index,x             ; animal 'picture' address
        sta ptrl                ; to indirect pointer
        lda #>index
        sta ptrh
        ldy #5                  ; six locations to move
aloop:  lda (ptrl),y            ; from 'picture'
        sta wings,y             ; to 'wings'
        dey
        bpl aloop
        sty flag                ; flag FF - animal coming

contin: ldx #5                  ; test:
cloop:  lda wings,x             ; is animal out of 'wings'?
        bne nokey               ; ..no, ignore keyboard
        dex
        bpl cloop
        jsr KEYIN
        jsr GETKEY
        cmp key                 ; right animal named?
        bne nokey               ; ..no, ignore key
        lda flag
        bpl nokey               ; animal retreating?
        inc flag                ; make animal retreat

nokey:  dec delay               ; wait a while..
        bne nomove              ; before moving animal
        lda #$20                ; speed control value  ($026A)
        sta delay
        lda flag                ; move animal - which way?
        bmi coming              ; ..left
        ldx #10                 ; ..right
rloop:  lda window-6,x
        sta window-5,x
        dex
        bne rloop
        stx window-6            ; clear extreme left
        beq nomove              ; unconditional branch

coming: ldx #$f0                ; -16
cmloop: lda window+12,x
        sta window+11,x
        inx
        bmi cmloop

nomove: lda #$7f                ; light KIM display
        sta SADD
        ldy #$13
        ldx #5                  ; six display digits
lite:   lda window,x
        sta SAD
        sty SBD
litex:  inc wait
        bne litex
        dey
        dey
        dex
        bpl lite
        jmp test

; index and animal 'pictures'
index:  .byte <ant, <bird, <cow, <dog, <elephant, <fox

ant:      .byte $08,$00,$00,$00,$00,$00
bird:     .byte $01,$61,$61,$40,$00,$00
cow:      .byte $61,$51,$47,$01,$00,$00
dog:      .byte $63,$58,$4e,$00,$00,$00
elephant: .byte $71,$1d,$41,$1f,$01,$00
fox:      .byte $63,$58,$4c,$40,$00,$00
