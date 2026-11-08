; wumpus.s -- WUMPUS for the KIM-1
; From "The First Book of KIM".  Adapted from the game by Gregory Yob in
; "The Best of Creative Computing".
;
; Wumpus lives in a cave of 16 rooms (0-F), each with four tunnels to other
; rooms.  You, Wumpus, two bottomless pits and two rooms of Superbats are
; placed at random.  Bats pick you up and drop you in another room; pits and
; Wumpus kill you (Wumpus may instead wake and wander off).  You are warned
; when any of them is in an adjacent room.
;
; You have three cans of "mood change" gas.  Press PC at the room prompt,
; then the room to throw into.  Gas in Wumpus's room wins; gas anywhere
; makes that room off limits.  Wumpus hears every throw and moves.
;
; Run at $0305.  After a loss, $0316 starts again with the same layout.
; The byte at $0229 (speed, below) sets the message scroll speed; a lower
; number is faster.
;
; Zero page ($0000-$00BF) and page 1 ($0100-$01A6) hold message and room
; data, so the program uses these segments of the shared kim.cfg:
;   ZPDATA $0000   PAGE1 $0100   CODE $0200 (padded in the source to $0305)
; Message characters are 7-segment patterns (bit 7 is ignored: PA7 is the
; keypad input).  $80 is a blank; $00 ends a message.
;
; Known bug, kept on purpose for historical accuracy: see "room" below.

        .include "kim.inc"

; Data labels used by the code before their definitions (zero page)
        .globalzp nbr0, nbr1, nbr2, nbr3, where_room, where_adj, gascount

; ---- Zero page: game state ----------------------------------------------
rnd     = $40           ; random-number state ($40-$45), from Butterfield's
                        ; KIM User Notes #1
rndtmp  = $c0           ; rand result scratch
gas     = $c0           ; gassed rooms: gas+cans, i.e. $c3..$c1 (see pitch)
adj     = $c6           ; the four rooms adjacent to "you" ($c6-$c9)
you     = $ca           ; your room
wumpus  = $cb           ; Wumpus's room
pit1    = $cc           ; pits
pit2    = $cd
bat1    = $ce           ; Superbats
bat2    = $cf           ; ($ca-$cf are filled together with random rooms)
pitroom = $d1           ; room a can is being thrown into
dlyctr  = $db           ; delay-display countdown
scanpos = $dc           ; scan pointer, saved across the delay
ptr     = $dd           ; message pointer ($dd lo, $de hi)
step    = $df           ; scroll step for scan
cans    = $e0           ; cans of gas left
hzidx   = $e1           ; adjacent-room index while checking for hazards
dispbuf = $e8           ; six characters being displayed ($e8-$ed)

; ==========================================================================
; Page 2 subroutines
; ==========================================================================
        .segment "CODE"

; ---- scan: scroll a message across the six digits ------------------------
; In:  A = message address low, Y = high.  Scrolls one character per step
; until the terminator ($00) is read.
scan:   sty ptr+1               ; transfer pointer HI
        sta ptr                 ; transfer pointer LO
        lda #$07                ; initialize scan forward
        sta step
        ldy #$05                ; initialize Y
cont:   ldx #$05                ; initialize X
char:   lda (ptr),y             ; get character
        cmp #$00                ; last character?
        bne more                ; ..if not, continue
        rts
more:   sta dispbuf,x           ; store it
        dey                     ; set up next character
        dex                     ; set up next store location
        bpl char                ; loop if not 6th character
        cld                     ; binary mode
        clc                     ; prepare to add
        tya                     ; get character pointer
        adc step                ; update for 6 new characters
        sta scanpos             ; save new pointer
        jsr delay               ; delay-display
        ldy scanpos             ; restore pointer
        jmp cont                ; continue rest of message

; ---- delay: display the buffer for a while -------------------------------
delay:  ldx #$0a                ; set rate
        stx dlyctr              ; put in decrement location
time:   lda #$52                ; load timer
        sta T1024_NOIRQ         ; start timer
lite:   jsr disp                ; jump to display sub
        bit TIMER_FLAG          ; timer done?
        bpl lite                ; ..if not, loop
        dec dlyctr              ; decrement timer
        bne time                ; not finished
        rts                     ; get 6 new characters

speed   = delay+1               ; $0229: display speed (lower = faster)

; ---- disp: one pass of the six-digit display -----------------------------
disp:   lda #$7f                ; change segments..
        sta SADD                ; ..to output
        ldy #$00                ; init recall index
        ldx #$09                ; init digit number
six:    lda dispbuf,y           ; get character
        sty TEMP                ; save Y
        jsr OUTPUT              ; display character
        iny                     ; set up for new character
        cpy #$06                ; 6 characters displayed?
        bcc six                 ; ..no
        jsr KEYTS               ; key down?
        rts                     ; exit

; ---- debo: debounce, return key in A -------------------------------------
debo:   jsr INIT1
        jsr disp                ; wait for previous key
        bne debo                ; to be released
show:   jsr disp                ; wait for new key to
        beq show                ; be depressed
        jsr disp                ; check again after
        beq show                ; slight delay
        jsr GETKEY              ; get a key
        cmp #KEY_NONE           ; a valid key?
        bpl debo                ; ..no
        rts

; ---- rand: random number in A (X preserved) ------------------------------
; From J. Butterfield, KIM User Notes #1 (p. 4)
rand:   txa                     ; save X register
        pha
        cld
        sec
        lda rnd+1
        adc rnd+4
        adc rnd+5
        sta rnd
        ldx #$04
nxtn:   lda rnd,x
        sta rnd+1,x
        dex
        bpl nxtn
        sta rndtmp
        pla                     ; return X register
        tax
        lda rndtmp
        rts
        nop                     ; $028E: unused (the original dump has a
                                ; stray $60 here); keeps comp at $028F

; ---- comp: compare room in A with each hazard ----------------------------
; Out: X = 0 Wumpus, 1-2 pit, 3-4 bat, $FF none
comp:   ldx #$04                ; compare room in A
hazd:   cmp wumpus,x            ; with each hazard
        beq out
        dex
        bpl hazd                ; X on exit shows match
out:    rts

; ---- move: maybe move Wumpus (75% of the time) ---------------------------
move:   jsr rand                ; get a random number
        and #$0f                ; strip to hex digit
        cmp #$04                ; change rooms 75%
        bmi noch                ; of the time
        jsr next                ; get adjacent rooms (to Wumpus)
move2:  lda TIMER_READ          ; get random number, 0-3
        and #$03
        tax                     ; use as index
        lda adj,x               ; get an adjacent room
        sta wumpus              ; put Wumpus in it
noch:   lda wumpus              ; Wumpus room in A
        rts

; ---- next: load adjacent rooms of "you" (next2: of room X) ---------------
next:   ldx you                 ; your room as index
next2:  lda nbr0,x              ; next rooms are loaded
        sta adj                 ; into $c6-$c9 from
        lda nbr1,x              ; tables
        sta adj+1
        lda nbr2,x
        sta adj+2
        lda nbr3,x
        sta adj+3
        rts

; ---- valid: X >= 0 if A is one of the adjacent rooms, else X = $FF -------
valid:  ldx #$03                ; check if A matches $c6-$c9
nxtv:   cmp adj,x
        beq yval                ; ..yes, valid room
        dex
        bpl nxtv
yval:   rts

; ---- lose: show the reason (page 1, address low in A), then YOU LOSE -----
lose:   ldy #$01                ; display reason lost,
        jsr scan
rept:   ldy #$00                ; then "YOU LOSE"
        lda #<msg_youlose
        jsr scan
        jmp rept

; ---- gasleft: show the cans-left message, then carry on ------------------
gasleft: ldy cans               ; get cans left
        lda TABLE,y             ; get conversion
        sta gascount            ; store in message
        ldy #>msg_gasleft       ; (page zero)
        lda #<msg_gasleft       ; display cans of gas left message
        jsr scan
        jmp adjr

; ==========================================================================
; Main program -- start at $0305
; ==========================================================================
        .assert scan = $0200, error, "CODE must start at $0200"
        .res $0105 - (* - scan), $ea    ; unused up to $0304, so start is $0305

start:  lda #$ff                ; initialization
        ldx #$0e                ; clean out rooms
init:   sta gas+1,x             ; initialize to $ff
        dex                     ; finished?
        bpl init                ; ..no
        lda #$03                ; give three cans of gas
        sta cans
        ldy #$05                ; randomize
        bpl getn                ; you, Wumpus, pits and bats
chng:   ldy #$00                ; (only-you entry)
getn:   ldx #$05
        jsr rand
        and #$0f
ckno:   cmp you,x               ; making sure all
        beq getn                ; are different
        dex
        bpl ckno
        sta you,y               ; store in $ca-$cf
        dey
        bpl getn
adjr:   jsr next                ; set up adjacent room list
        ldy #$03                ; hazards in adjacent rooms?
        sty hzidx
nxtr:   lda adj,y
        jsr comp                ; compare each to hazards
        txa                     ; (X contains match info)
        bmi noma                ; no match, no hazards
        cpx #$03                ; bats?
        bmi skp1                ; ..no
        lda #<msg_bats          ; (bats nearby message)
        bpl mess
skp1:   cpx #$01                ; pit?
        bmi skp2                ; ..no
        lda #<msg_pit           ; (pit close message)
        bpl mess
skp2:   lda #<msg_wumpus        ; must be Wumpus
mess:   ldy #$01                ; (page one)
        jsr scan                ; display hazard message
noma:   dec hzidx               ; try next adjacent room
        ldy hzidx               ; finished?
        bpl nxtr                ; ..no
        ldy you                 ; load and display --
        lda TABLE,y             ; "YOU ARE IN ... TUNNELS LEAD TO ..."
        sta where_room          ; message
        ldx #$03                ; (four next rooms)
xro:    ldy adj,x
        lda TABLE,y             ; conversion
        sta where_adj,x         ; put in message
        dex                     ; finished?
        bpl xro                 ; ..no
room:   ldy #$00                ; location and
        tya                     ; page of message
        jsr scan                ; display message
        jsr debo                ; debounce key
        cmp #KEY_PC             ; "PC" pushed?
        beq pitch               ; ..yes
        jsr valid               ; an adjacent room?
        sta you                 ; update your room
                                ;
                                ; BUG in the original, kept for historical
                                ; accuracy: this store happens before the
                                ; validity test, so a keypress that is not
                                ; an adjacent room still overwrites "you".
                                ; The next valid key repairs it.  But if PC
                                ; is pressed after a bad key, the throw is
                                ; made from the wrong room: "did he move
                                ; into your room" compares against the bad
                                ; value, and adjr then rebuilds the room
                                ; list from it (a teleport, with no hazard
                                ; check).  Keys $10-$13 index past the end
                                ; of the room tables.
                                ;
                                ; Fix: hold the key in a temp until valid:
                                ;   jsr valid / sta pitroom / txa / bmi room
                                ;   / lda pitroom / sta you
        txa
        bmi room                ; if X=$FF, not a valid room
        lda you                 ; check for gas in room
        ldx #$04                ; 5 possible (expansion)
nxtg:   cmp gas+1,x
        beq gasm                ; gassed!!
        dex                     ; all checked?
        bpl nxtg                ; ..no
        jsr comp                ; check your new
        txa                     ; room for hazards..
        bmi adjr                ; no match, no hazards
        cpx #$03
        bpl batm                ; bats
        cpx #$01
        bpl pitm                ; pit!!!
        ldy #>msg_bump
        lda #<msg_bump          ; must have bumped Wumpus
        jsr scan                ; display message
        jsr move                ; ..see if he moves..
        cmp you                 ; still in your room?
        bne adjr                ; ..no, you're okay
caught: lda #<msg_hahawump      ; he got you!
        jmp lose
batm:   ldy #>msg_snatch        ; bat message
        lda #<msg_snatch
        jsr scan
        jmp chng                ; change your room
pitm:   lda #<msg_pit_fell      ; fell in pit!
        jmp lose
gasm:   lda #<msg_gas_room      ; gas in room!
        jmp lose
pitch:  ldy #>msg_room          ; pitch can and see
        lda #<msg_room          ; if you get him
        jsr scan                ; room?
        jsr debo
        jsr valid               ; valid room?
        sta pitroom
        txa
        bmi pitch               ; if X=$FF, not valid
        lda pitroom
        ldx cans                ; cans of gas left
        sta gas,x               ; is Wumpus in
        cmp wumpus              ; room gassed?
        beq win                 ; ..yes, you got him
        dec cans                ; decrease can count
        beq out2                ; gas is gone
        ldx wumpus              ; move Wumpus to an
        jsr next2               ; adjacent room (for him)
        jsr move2
        cmp you                 ; did he move into your room?
        beq caught              ; ..yes
        jmp gasleft             ; display cans left message
        nop                     ; $03F0-$03F1: padding in the original
        nop
win:    ldy #>msg_win           ; great & etc. message
        lda #<msg_win
        jsr scan
        beq win                 ; repeat
out2:   lda #<msg_nogas         ; out of gas!
        jmp lose                ; (the hex dump has JSR here, the listing
                                ; JMP; lose never returns, so same effect)

; ==========================================================================
; Page 0 data: messages and room tables
; ==========================================================================
        .segment "ZPDATA": zeropage

; "YOU ARE IN x - TUNNELS LEAD TO wxyz"  (x and wxyz are patched at run time)
msg_where:
        .byte $80,$ee,$dc,$be,$80,$f7,$d0,$f9,$80,$84,$d4,$80  ; " YOU ARE IN "
where_room:
        .byte $ef                                               ; your room
        .byte $80,$c0,$80                                       ; " - "
        .byte $f8,$be,$d4,$d4,$f9,$b8,$ed,$80                   ; "TUNNELS "
        .byte $b8,$f9,$f7,$de,$80,$f8,$dc,$80                   ; "LEAD TO "
where_adj:
        .byte $fd,$ff,$f7,$b9                                   ; adjacent rooms
        .byte $80,$00

; " OOPS - BUMPED A WUMPUS  "
msg_bump:
        .byte $80,$dc,$dc,$f3,$ed,$80,$c0,$80                   ; " OOPS - "
        .byte $fc,$be,$b7,$f3,$f9,$de,$80,$f7,$80               ; "BUMPED A "
        .byte $9c,$be,$b7,$f3,$be,$ed,$80,$80,$00               ; "WUMPUS  "

        .res $10                ; $0040-$004F: random-number state at $40-$45

; Next-room tables: the four tunnels out of room X are nbr0..nbr3 [X]
nbr0:   .byte $02,$02,$00,$01,$01,$00,$03,$04,$00,$06,$07,$00,$09,$0a,$01,$04
nbr1:   .byte $05,$03,$01,$02,$03,$02,$05,$06,$05,$08,$09,$08,$0b,$0c,$0b,$07
nbr2:   .byte $08,$04,$03,$04,$07,$06,$07,$0a,$09,$0a,$0f,$0c,$0d,$0e,$0c,$0a
nbr3:   .byte $0b,$0e,$05,$06,$0f,$08,$09,$0f,$0b,$0c,$0d,$0e,$0e,$0f,$0d,$0d

; " MISSED - ONLY n CANS LEFT "  (n patched at run time)
msg_gasleft:
        .byte $80,$b7,$84,$ed,$ed,$f9,$de,$80,$c0,$80          ; " MISSED - "
        .byte $dc,$d4,$b8,$ee,$80                               ; "ONLY "
gascount:
        .byte $db                                               ; cans left
        .byte $80,$b9,$f7,$d4,$ed,$80,$b8,$f9,$f1,$f8,$80,$00   ; " CANS LEFT "

; " YOU LOSE "
msg_youlose:
        .byte $80,$ee,$dc,$be,$80,$b8,$dc,$ed,$f9,$80,$00

; " ROOM? "
msg_room:
        .byte $80,$d0,$dc,$dc,$b7,$d3,$80,$00
        .byte $00               ; $00BF: unused (the original dump has $05)

; ==========================================================================
; Page 1 data: messages
; ==========================================================================
        .segment "PAGE1"

msg_wumpus:                     ; " WUMPUS CLOSE"
        .byte $80,$9c,$be,$b7,$f3,$be,$ed,$80,$b9,$b8,$dc,$ed,$f9,$00
msg_pit:                        ; " PIT CLOSE"
        .byte $80,$f3,$84,$f8,$80,$b9,$b8,$dc,$ed,$f9,$00
msg_bats:                       ; " BATS CLOSE "
        .byte $80,$fc,$f7,$f8,$ed,$80,$b9,$b8,$dc,$ed,$f9,$80,$00
msg_hahawump:                   ; " HA HA WUMPUS GOT YOU "
        .byte $80,$f6,$f7,$80,$f6,$f7,$80
        .byte $9c,$be,$b7,$f3,$be,$ed,$80,$bd,$dc,$f8,$80,$ee,$dc,$be,$80,$00
msg_snatch:                     ; " SUPERBAT SNATCH "
        .byte $80,$ed,$be,$f3,$f9,$d0,$fc,$f7,$f8,$80
        .byte $ed,$d4,$f7,$f8,$b9,$f6,$80,$00
msg_pit_fell:                   ; " YYIIEEE FELL IN PIT "
        .byte $80,$ee,$ee,$84,$84,$f9,$f9,$f9,$80,$f1,$f9,$b8,$b8,$80
        .byte $84,$d4,$80,$f3,$84,$f8,$80,$00
msg_gas_room:                   ; " GAS IN ROOM "
        .byte $80,$bd,$f7,$ed,$80,$84,$d4,$80,$d0,$dc,$dc,$b7,$80,$00
msg_nogas:                      ; " OUT OF GAS "
        .byte $80,$dc,$be,$f8,$80,$dc,$f1,$80,$bd,$f7,$ed,$80,$00
msg_win:                        ; "GREAT - YOU GET A HUG FROM WUMPUS"
        .byte $80,$80,$80,$80,$80
        .byte $bd,$d0,$f9,$f7,$f8,$c0,$80,$ee,$dc,$be,$80
        .byte $bd,$f9,$f8,$80,$f7,$80,$f6,$be,$bd,$80
        .byte $f1,$d0,$dc,$b7,$80,$9c,$be,$b7,$f3,$be,$ed,$80,$00

; ==========================================================================
; Layout checks: the code depends on these addresses
; ==========================================================================
        .assert nbr0 = $50, error, "room tables must start at $0050"
        .assert msg_gasleft = $90, error, "gas-left message must be at $0090"
        .assert msg_youlose = $ac, error, "YOU LOSE must be at $00AC"
        .assert msg_room = $b7, error, "ROOM? must be at $00B7"
        .assert msg_bump = $26, error, "bump message must be at $0026"
        .assert >msg_wumpus = 1 .and >msg_win = 1, error, "page-1 messages"
        .assert >msg_hahawump = 1 .and >msg_pit_fell = 1, error, "page-1 reasons"
        .assert >msg_nogas = 1 .and >msg_gas_room = 1, error, "page-1 reasons"
        .assert <msg_bats < $80 .and <msg_pit < $80 .and <msg_wumpus < $80, error, "bpl mess"
        .assert speed = $0229, error, "speed byte must be at $0229"
        .assert chng = $0316, error, "restart entry must be $0316"
