; microchess.s -- MicroChess for the KIM-1, ca65 version
;
; KIM-1 MicroChess (C) 1976-2005 Peter Jennings, www.benlo.com
;
; Claude reconstructed original source by Hans Otten, 2021, from various 
; sources: disassembly of the cassette dumps, plus the source and hex dumps in 
; the manual. Binary compatible with the tape dump (excluding stack and unused
; page zero). Differences from the printed listing: OPNING and MOVEX.
;
; This file is a ca65 conversion of that source (lowercase, segments instead
; of .org, symbols from kim.inc).
;
; Build:
;   ca65 -o microchess.o microchess.s
;   ld65 -C microchess.cfg -o microchess.bin microchess.o
; Load the image at $0000 and run from $0000.  Keys:
;   C = set up board   E = reverse board   F = make the entered move
;   PC = let the computer play
;
; Memory map (everything below the monitor's RAM at $17E7):
;   $0000-$004D  main loop (page zero!)      $0050-$006F  board, white
;   $0060-$006F  black pieces                $0070-$00DB  tables (see below)
;   $0100-$01xx  janus, move ranking         $0200-$03xx  move generator
;   $1780-$17E6  strategy / move evaluation

.include "kim.inc"

; ---- choose the built-in opening ---------------------------------------
; 0 French Defence (W)    1 French Defence (B)    2 Giuoco Piano (W)
; 3 Giuoco Piano (B)      4 Ruy Lopez (W)         5 Ruy Lopez (B)
; 6 Queen's Indian (W)    7 Queen's Indian (B)    8 Four Knights (W)
; 9 Four Knights (B)
; (W = the computer plays white, B = the computer plays black.)
; Override with:  ca65 -D opening_choice=N
.ifndef opening_choice
opening_choice = 2
.endif

; ---- page zero variables -----------------------------------------------
board       = $50       ; location of pieces
bk          = $60       ; opponent's pieces
piece       = $B0       ; current piece under analysis
square      = $B1       ; to-square or piece
sp2         = $B2       ; stack pointer for stack 2
sp1         = $B3       ; stack pointer for stack 1
incheck     = $B4       ; move-into-check flag
state       = $B5       ; state of analysis
moven       = $B6       ; move table pointer
rev         = $B7       ; opening table pointer (unused)
omove       = $DC       ; opening move table pointer
wcap0       = $DD       ; computer capture 0
count       = $DE       ; start of count table
bcap2       = $DE       ; opponent capture 2
wcap2       = $DF       ; computer capture 2
bcap1       = $E0       ; opponent capture 1
wcap1       = $E1       ; computer capture 1
bcap0       = $E2       ; opponent capture 0
mob         = $E3       ; mobility
maxc        = $E4       ; maximum capture
cc          = $E5       ; capture count
pcap        = $E6       ; opponent maxp
bmob        = $E3       ; opponent mobility
bmaxc       = $E4       ; opponent maximum capture
bccnt       = $E5       ; opponent capture count (the listing calls it BCC,
                        ; which collides with the 6502 mnemonic)
bmaxp       = $E6       ; opponent maxp
xmaxc       = $E8       ; computer maximum capture
wmob        = $EB       ; computer mobility
wmaxc       = $EC       ; computer maximum capture
wcc         = $ED       ; computer capture count
wmaxp       = $EE       ; computer maxp
pmob        = $EF       ; previous computer mob
pmaxc       = $F0       ; previous computer maxc
pcc         = $F1       ; previous computer cc
pcp         = $F2       ; previous computer maxp
oldky       = ACC       ; key input temporary ($F3)
; These share the monitor's display buffer: what is shown is what was found.
bestp       = POINTH    ; piece of best move found
bestv       = POINTL    ; value of best move found
bestm       = INH       ; to-square of best move
dis1        = POINTH    ; display point 1
dis2        = POINTL    ; display point 2
dis3        = INH       ; display point 3

; ---- page zero tables ----------------------------------------------------
; These must be assembled as page zero: the opening table is indexed with
; X = $FF and relies on zero-page indexing wrapping around to $DB.
.segment "TABLES": zeropage

; initial board, copied to board..board+$1F by [C]
setw:       .byte $03, $04, $00, $07, $02, $05, $01, $06
            .byte $10, $17, $11, $16, $12, $15, $14, $13
            .byte $73, $74, $70, $77, $72, $75, $71, $76
            .byte $60, $67, $61, $66, $62, $65, $64
            .byte $63                   ; 32nd board byte, doubles as movex[0]

; direction offsets; index 0 is never used, so the table overlaps the last
; byte of setw to save a byte.  1-8 king/queen/rook/bishop, 9-16 knight
movex       = * - 1
            .byte $F0, $FF, $01, $10, $11, $0F, $EF, $F1
            .byte $DF, $E1, $EE, $F2, $12, $0E, $1F, $21

; capture values, indexed by piece number
points:     .byte $0B, $0A, $06, $06, $04, $04, $04, $04
            .byte $02, $02, $02, $02, $02, $02, $02, $02

            .res $10                    ; $B0-$BF: variables piece..rev

; Opening book: the computer plays the opening specified from memory.
; $C0-$DB, read backwards from opning with X = $FF, $FE, ...  The last
; entry of each table is the sentinel ($CC for white, $44 for black).
opening_start:
.if opening_choice = 0
; French Defence (W)
            .byte $99, $22, $06, $45, $32, $0C, $72, $14, $01, $63, $63, $05, $64, $43, $0F, $63
            .byte $41, $05, $52, $25, $07, $44, $43, $0E, $53, $33, $0F, $CC
.elseif opening_choice = 1
; French Defence (B)
            .byte $99, $22, $07, $55, $32, $0D, $45, $06, $00, $63, $14, $01, $14, $13, $06, $34
            .byte $14, $04, $36, $25, $06, $52, $33, $0E, $43, $24, $0F, $44
.elseif opening_choice = 2
; Giuoco Piano (W)
            .byte $99, $25, $0B, $25, $01, $00, $33, $25, $07, $36, $34, $0D, $34, $34, $0E, $52
            .byte $25, $0D, $45, $35, $04, $55, $22, $06, $43, $33, $0F, $CC
.elseif opening_choice = 3
; Giuoco Piano (B)
            .byte $99, $52, $04, $52, $52, $06, $75, $44, $06, $52, $41, $03, $43, $43, $0F, $43
            .byte $25, $06, $52, $32, $04, $42, $22, $07, $55, $34, $0F, $44
.elseif opening_choice = 4
; Ruy Lopez (W)
            .byte $99, $25, $07, $66, $43, $0E, $55, $55, $04, $54, $13, $01, $63, $34, $0E, $33
            .byte $01, $00, $52, $46, $04, $55, $22, $06, $43, $33, $0F, $CC
.elseif opening_choice = 5
; Ruy Lopez (B)
            .byte $99, $06, $00, $52, $11, $06, $34, $22, $0B, $22, $23, $06, $64, $14, $04, $43
            .byte $44, $06, $75, $25, $06, $31, $22, $07, $55, $34, $0F, $44
.elseif opening_choice = 6
; Queen's Indian (W)
            .byte $99, $25, $01, $25, $15, $01, $33, $25, $07, $72, $01, $00, $63, $11, $04, $66
            .byte $21, $0A, $56, $22, $06, $53, $35, $0D, $52, $34, $0E, $CC
.elseif opening_choice = 7
; Queen's Indian (B)
            .byte $99, $35, $0C, $52, $52, $06, $62, $44, $06, $52, $06, $00, $75, $14, $04, $66
            .byte $11, $05, $56, $21, $0B, $55, $24, $0F, $42, $25, $06, $43
.elseif opening_choice = 8
; Four Knights (W)
            .byte $99, $03, $02, $63, $25, $0B, $25, $41, $05, $54, $24, $0E, $72, $01, $00, $36
            .byte $46, $04, $52, $25, $07, $55, $22, $06, $43, $33, $0F, $CC
.elseif opening_choice = 9
; Four Knights (B)
            .byte $99, $03, $07, $74, $14, $01, $52, $52, $04, $36, $23, $0E, $53, $06, $00, $75
            .byte $41, $04, $31, $25, $06, $52, $22, $07, $55, $34, $0F, $44
.else
.fatal "opening_choice must be 0-9"
.endif

opning      := *                        ; = omove ($DC), just past the table
.assert opning - opening_start = $1C, error, "opening table must be 28 bytes"
.assert opning = omove, error, "opening table must end at $DC"

; ---- main loop, assembled at $0000 (execution begins at address 0000) ----
.segment "START"

chess:      cld                         ; initialise
            ldx #$FF                    ; two stacks
            txs
            ldx #$C8
            stx sp2

; routines to light the LED display and get a key from the keyboard

out:        jsr SCANDS                  ; display and
            jsr GETKEY                  ; get input
            cmp oldky                   ; key in acc
            beq out                     ; (debounce)
            sta oldky

            cmp #$0C                    ; [C]
            bne noset                   ; set up
            ldx #$1F                    ; board
whset:      lda setw,x                  ; from
            sta board,x                 ; setw
            dex
            bpl whset
            stx omove                   ; opening not yet used (X = $FF)
            lda #$CC
            bne cldsp

noset:      cmp #$0E                    ; [E]
            bne norev                   ; reverse
            jsr reverse                 ; board
            lda #$EE
            bne cldsp

norev:      cmp #$14                    ; [PC]
            bne nogo                    ; play chess
            jsr go

cldsp:      sta dis1                    ; display
            sta dis2                    ; across
            sta dis3                    ; display
            bne chess

nogo:       cmp #$0F                    ; [F]
            bne nomv                    ; move man
            jsr move                    ; as entered
            jmp disp

nomv:       jmp input

; ---- janus, $0100 ----------------------------------------------------------
; janus directs the analysis by determining what should occur after each
; move generated by gnm
.segment "JANUS"

janus:      ldx state
            bmi nocount

; this routine counts occurrences; it depends on state to index the
; correct counters

counts:     lda piece
            beq over                    ; if state = 8
            cpx #$08                    ; do not count
            bne over                    ; blk max cap
            cmp bmaxp                   ; moves for
            beq xrt                     ; white

over:       inc mob,x                   ; mobility
            cmp #$01                    ; + queen
            bne noq                     ; for two
            inc mob,x

noq:        bvc nocap
            ldy #$0F                    ; calculate
            lda square                  ; points
eloop:      cmp bk,y                    ; captured
            beq foun                    ; by this
            dey                         ; move
            bpl eloop
foun:       lda points,y
            cmp maxc,x
            bcc less                    ; save if
            sty pcap,x                  ; best this
            sta maxc,x                  ; state

less:       clc
            php                         ; add to
            adc cc,x                    ; capture
            sta cc,x                    ; counts
            plp

nocap:      cpx #$04
            beq on4
            bmi tree                    ; (=00 only)
xrt:        rts

; generate further moves for count and analysis

on4:        lda xmaxc                   ; save actual
            sta wcap0                   ; capture
            lda #$00                    ; state = 0
            sta state
            jsr move                    ; generate
            jsr reverse                 ; immediate
            jsr gnmz                    ; reply moves
            jsr reverse

            lda #$08                    ; state = 8
            sta state                   ; generate
            jsr gnm                     ; continuation
            jsr umove                   ; moves

            jmp stratgy                 ; final evaluation
nocount:    cpx #$F9
            bne tree

; determine if the king can be taken, used by chkchk

            lda bk                      ; is king
            cmp square                  ; in check?
            bne retj                    ; set incheck = 0
            lda #$00                    ; if it is
            sta incheck
retj:       rts

; if a piece has been captured by a trial move, generate replies and
; evaluate the exchange gain/loss

tree:       bvc retj                    ; no cap
            ldy #$07                    ; (pieces)
            lda square
loopx:      cmp bk,y
            beq founx
            dey
            beq retj                    ; (king)
            bpl loopx                   ; save
founx:      lda points,y                ; best cap
            cmp bcap0,x                 ; at this
            bcc nomax                   ; level
            sta bcap0,x
nomax:      dec state
            lda #$FB                    ; if state = $FB
            cmp state                   ; time to turn
            beq uptree                  ; around
            jsr genrm                   ; generate further
uptree:     inc state                   ; captures
            rts

; the player's move is input

input:      cmp #$08                    ; not a legal
            bcs error                   ; square #
            jsr dismv
disp:       ldx #$1F
search:     lda board,x
            cmp dis2
            beq here                    ; display
            dex                         ; piece at
            bpl search                  ; from
here:       stx dis1                    ; square
            stx piece
error:      jmp chess

; ---- move generator, $0200 -------------------------------------------------
; generate all moves for one side, call janus after each one for next step
.segment "GEN"

gnmz:       ldx #$10                    ; clear
gnmx:       lda #$00                    ; counters
clear:      sta count,x
            dex
            bpl clear

gnm:        lda #$10                    ; set up
            sta piece                   ; piece
newp:       dec piece                   ; new piece
            bpl nex                     ; all done?
            rts                         ;   - yes

nex:        jsr reset                   ; ready
            ldy piece                   ; get piece
            ldx #$08
            stx moven                   ; common start
            cpy #$08                    ; what is it?
            bpl pawn                    ; pawn
            cpy #$06
            bpl knight                  ; knight
            cpy #$04
            bpl bishop                  ; bishop
            cpy #$01
            beq queen                   ; queen
            bpl rook                    ; rook

king:       jsr sngmv                   ; must be king!
            bne king                    ; moves
            beq newp                    ; 8 to 1
queen:      jsr line
            bne queen                   ; moves
            beq newp                    ; 8 to 1

rook:       ldx #$04
            stx moven                   ; moves
agnr:       jsr line                    ; 4 to 1
            bne agnr
            beq newp

bishop:     jsr line
            lda moven                   ; moves
            cmp #$04                    ; 8 to 5
            bne bishop
            beq newp

knight:     ldx #$10
            stx moven                   ; moves
agnn:       jsr sngmv                   ; 16 to 9
            lda moven
            cmp #$08
            bne agnn
            beq newp

pawn:       ldx #$06
            stx moven
p1:         jsr cmove                   ; right cap?
            bvc p2
            bmi p2
            jsr janus                   ; yes
p2:         jsr reset
            dec moven                   ; left cap?
            lda moven
            cmp #$05
            beq p1
p3:         jsr cmove                   ; ahead
            bvs newp                    ; illegal
            bmi newp
            jsr janus
            lda square                  ; gets to
            and #$F0                    ; 3rd rank?
            cmp #$20
            beq p3                      ; do double
            jmp newp

; calculate single step moves for king and knight

sngmv:      jsr cmove                   ; calc move
            bmi ill1                    ; - if legal
            jsr janus                   ; - evaluate
ill1:       jsr reset
            dec moven
            rts

; calculate all moves down a straight line for queen, bishop and rook

line:       jsr cmove                   ; calc move
            bcc ovl                     ; no chk
            bvc line                    ; nocap
ovl:        bmi ill                     ; return
            php
            jsr janus                   ; evaluate posn
            plp
            bvc line                    ; not a cap
ill:        jsr reset                   ; line stopped
            dec moven                   ; next dir
            rts

; exchange sides for reply analysis

reverse:    ldx #$0F
etc:        sec
            ldy bk,x                    ; subtract
            lda #$77                    ; position
            sbc board,x                 ; from 77
            sta bk,x
            sty board,x                 ; and
            sec
            lda #$77                    ; exchange
            sbc board,x                 ; pieces
            sta board,x
            dex
            bpl etc
            rts

; cmove calculates the to-square using square and the move table.  Flags
; are set as follows:
;   N - illegal move
;   V - capture (legal unless in check)
;   C - illegal because of check
; [my thanks to Jim Butterfield who wrote this more efficient version of
;  cmove]

cmove:      lda square                  ; get square
            ldx moven                   ; move pointer
            clc
            adc movex,x                 ; move list
            sta square                  ; new pos'n
            and #$88
            bne illegal                 ; off board
            lda square

            ldx #$20
loop:       dex                         ; is to
            bmi no                      ; square
            cmp board,x                 ; occupied?
            bne loop

            cpx #$10                    ; by self?
            bmi illegal

            lda #$7F                    ; must be cap!
            adc #$01                    ; set v flag
            bvs spx                     ; (jmp)

no:         clv                         ; no capture

spx:        lda state                   ; should we
            bmi retl                    ; do the
            cmp #$08                    ; check check?
            bpl retl

; chkchk reverses sides and looks for a king capture to indicate illegal
; move because of check.  Since this is time consuming, it is not always
; done.

chkchk:     pha                         ; state
            php
            lda #$F9
            sta state                   ; generate
            sta incheck                 ; all reply
            jsr move                    ; moves to
            jsr reverse                 ; see if king
            jsr gnm                     ; is in
            jsr rum                     ; check
            plp
            pla
            sta state
            lda incheck
            bmi retl                    ; no - safe
            sec                         ; yes - in chk
            lda #$FF
            rts

retl:       clc                         ; legal
            lda #$00                    ; return
            rts

illegal:    lda #$FF
            clc                         ; illegal
            clv                         ; return
            rts

; replace piece on correct square

reset:      ldx piece                   ; get logat
            lda board,x                 ; for piece
            sta square                  ; from board
            rts

genrm:      jsr move                    ; make move
genr2:      jsr reverse                 ; reverse board
            jsr gnm                     ; generate moves
rum:        jsr reverse                 ; reverse back

; routine to unmake a move made by move

umove:      tsx                         ; unmake move
            stx sp1
            ldx sp2                     ; exchange
            txs                         ; stacks
            pla                         ; moven
            sta moven
            pla                         ; captured
            sta piece                   ; piece
            tax
            pla                         ; from square
            sta board,x
            pla                         ; piece
            tax
            pla                         ; to square
            sta square
            sta board,x
            jmp strv

; this routine moves piece to square; parameters are saved in a stack to
; unmake the move later

move:       tsx
            stx sp1                     ; switch
            ldx sp2                     ; stacks
            txs
            lda square
            pha                         ; to square
            tay
            ldx #$1F
check:      cmp board,x                 ; check for
            beq take                    ; capture
            dex
            bpl check
take:       lda #$CC
            sta board,x
            txa                         ; captured
            pha                         ; piece
            ldx piece
            lda board,x
            sty board,x                 ; from
            pha                         ; square
            txa
            pha                         ; piece
            lda moven
            pha                         ; moven
strv:       tsx
            stx sp2                     ; switch
            ldx sp1                     ; stacks
            txs                         ; back
            rts

; continuation of stratgy: checks for check or checkmate and assigns a
; value to the move

ckmate:     ldx bmaxc                   ; can blk cap
            cpx points                  ; my king?
            bne nochek
            lda #$00                    ; gulp!
            beq retv                    ; dumb move!

nochek:     ldx bmob                    ; is black
            bne retv                    ; unable to
            ldx wmaxp                   ; move and
            bne retv                    ; king in ch?
            lda #$FF                    ; yes! mate

retv:       ldx #$04                    ; restore
            stx state                   ; state = 4

; the value of the move (in accu) is compared to the best move and
; replaces it if it is better

push:       cmp bestv                   ; is this best
            bcc retp                    ; move so far?
            beq retp
            sta bestv                   ; yes!
            lda piece                   ; save it
            sta bestp
            lda square
            sta bestm                   ; flash display
retp:       jmp SCANDS                  ; and rts

; main program to play chess: play from opening or think

go:         ldx omove                   ; opening?
            bpl noopen                  ; - no
            lda dis3                    ; - yes, was
            cmp opning,x                ; opponent's
            bne end                     ; move ok?
            dex
            lda opning,x                ; get next
            sta dis1                    ; canned
            dex                         ; opening move
            lda opning,x
            sta dis3                    ; display it
            dex
            stx omove                   ; move it
            bne mv2                     ; (jmp)

end:        sta omove                   ; flag opening
noopen:     ldx #$0C                    ; finished
            stx state                   ; state = c
            stx bestv                   ; clear bestv
            ldx #$14                    ; generate p
            jsr gnmx                    ; moves

            ldx #$04                    ; state = 4
            stx state                   ; generate and
            jsr gnmz                    ; test available moves

            ldx bestv                   ; get best move
            cpx #$0F                    ; if none
            bcc mate                    ; oh oh!

mv2:        ldx bestp                   ; move
            lda board,x                 ; the
            sta bestv                   ; best
            stx piece                   ; move
            lda bestm
            sta square                  ; and display
            jsr move                    ; it
            jmp chess

mate:       lda #$FF                    ; resign
            rts                         ; or stalemate

; subroutine to enter the player's move

dismv:      ldx #$04                    ; rotate
drol:       asl dis3                    ; key
            rol dis2                    ; into
            dex                         ; display
            bne drol
            ora dis3
            sta dis3
            sta square
            rts

; ---- strategy, $1780 -------------------------------------------------------
; this subroutine assigns a value to the move under consideration and
; returns it in the accumulator
.segment "STRAT"

stratgy:    clc
            lda #$80
            adc wmob                    ; parameters
            adc wmaxc                   ; with weight
            adc wcc                     ; of 0.25
            adc wcap1
            adc wcap2
            sec
            sbc pmaxc
            sbc pcc
            sbc bcap0
            sbc bcap1
            sbc bcap2
            sbc pmob
            sbc bmob
            bcs pos                     ; underflow
            lda #$00                    ; prevention
pos:        lsr a
            clc                         ; **************
            adc #$40
            adc wmaxc                   ; parameters
            adc wcc                     ; with weight
            sec                         ; of 0.5
            sbc bmaxc
            lsr a                       ; **************
            clc
            adc #$90
            adc wcap0                   ; parameters
            adc wcap0                   ; with weight
            adc wcap0                   ; of 1.0
            adc wcap0
            adc wcap1
            sec                         ; [under or over-
            sbc bmaxc                   ; flow may occur
            sbc bmaxc                   ; from this
            sbc bccnt                   ; section]
            sbc bccnt
            sbc bcap1
            ldx square                  ; ***************
            cpx #$33
            beq posn                    ; position
            cpx #$34                    ; bonus for
            beq posn                    ; move to
            cpx #$22                    ; centre
            beq posn                    ;    or
            cpx #$25                    ; out of
            beq posn                    ; back rank
            ldx piece
            beq noposn
            ldy board,x
            cpy #$10
            bpl noposn
posn:       clc
            adc #$02
noposn:     jmp ckmate                  ; continue
