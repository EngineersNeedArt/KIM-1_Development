; codetest.s -- Morse code group sender for the KIM-1
;
; From "The First Book of KIM".  Needs a speaker on PA0 (figure 5.1 of
; the KIM-1 User Manual).  Start at $0200.
;
; The program sends 5 groups of 5 random characters in International
; Morse over the speaker: A-Z, 0-9, period, comma, question mark and
; equal sign.  When the transmission ends, the groups sent are shown on
; the display so reception can be checked; any key steps to the next
; group, and after the last group it cycles back to the first.  Some
; 7-segment glyphs are strange and a few are ambiguous (5/S, I/comma),
; but slowing the transmission down makes each one recognizable.
;
; Morse storage: each code byte holds the elements left-justified, one
; bit per element (0 = dot, 1 = dash), followed by a single 1 bit as an
; end marker and zero fill.  Shifting left until the byte is zero walks
; the elements; the carry out of each shift is the element.  See Byte
; magazine, October 1976, page 36.
;
; Random numbers: J. Butterfield, KIM User Notes, Vol. 1, #1.
;
; Tuning (change the equates and the init table together):
;   groups, grpsize  number of groups sent, characters per group
;   nchars           size of the character set; 26 = letters only
;   init table       speed ($33 = about 16 groups/min, $66 = about
;                    8 groups/min) and tone


        .include "kim.inc"

; ---- Parameters -----------------------------------------------------

groups  = 5                     ; groups sent (and displayed afterward)
grpsize = 5                     ; characters per group
nchars  = 40                    ; character set size; 26 = letters only
                                ; (the AND #$3F mask below needs <= 64)

; ---- Zero page ($D0-$ED is free user area) ----------------------------

rnd     = $d0                   ; 6-byte random seed, $D0-$D5
ticks   = $dd                   ; mark/space length counter
codebyte = $df                  ; Morse bits being shifted out
cnt     = $e0                   ; characters left in the group (+1)

; $E2-$ED are loaded from inittab at startup, in this order:
index   = $e2                   ; characters generated so far
grpleft = $e3                   ; groups left to display
grpptr  = $e4                   ; ptr to the group before the one shown
speed   = $e6                   ; timer count per time unit
tone    = $e7                   ; tone delay (bigger = lower pitch)
window  = $e8                   ; 6 display digits ($E8-$ED)

store   = $033b                 ; segment patterns of characters sent
                                ; ($033B-$03FF)

; ---- Program ----------------------------------------------------------

        .org PROGRAM_ORG

morse:  ldx #ninit-1            ; load the init values
init:   lda inittab,x
        sta index,x
        dex
        bpl init

grup:   ldx #4                  ; space length between groups
        jsr space
        lda #grpsize+1          ; counted down first, so +1
        sta cnt
nextch: dec cnt                 ; next character in group
        beq grup                ; group finished, start a new one
        ldx #3                  ; space length between characters
        jsr space
numb:   jsr rand                ; get a random number
        and #$3f                ; make it 0-63
        cmp #nchars             ; in the character set?
        bpl numb                ; no, get another
        tax                     ; use as index
        lda segtab,x            ; display conversion
        ldy index
        sta store,y             ; remember it for the readout
        inc index
        lda index               ; one past the last character yet?
        cmp #groups*grpsize+1
        beq debo                ; yes, go to the readout
        lda codetab,x           ; Morse code for this character
        sta codebyte
elem:   asl codebyte            ; shift out next element
        beq nextch              ; only the end marker left: next character
        bcs dash                ; carry set = dash
        ldx #1                  ; dot
        jsr mark
gap:    ldx #1                  ; space after each element
        jsr space
        clc
        bcc elem                ; always
dash:   ldx #3                  ; dash length
        jsr mark
        clc
        bcc gap                 ; always

; ---- Readout: show each group, one key press per group ----------------

debo:   jsr INIT1               ; reset the monitor's I/O port state
        jsr disp
        bne debo                ; wait for key release
wait:   jsr disp
        beq wait                ; wait for key down
        clc
        lda grpptr              ; advance pointer to the next group
        adc #grpsize
        sta grpptr
        ldy #grpsize-1          ; copy the group's segment patterns
wind:   lda (grpptr),y          ; into the display window
        sta window,y
        dey
        bpl wind
        dec grpleft             ; last group?
        bne debo                ; no, wait for the next key
        lda #<(store-grpsize)   ; yes: point back before the first group
        sta grpptr
        lda #groups
        sta grpleft
        bne debo                ; always

; ---- Mark: sound the tone for X time units ----------------------------

mark:   stx ticks
timm:   lda speed               ; one time unit
        sta T1024_NOIRQ         ; start the timer
        lda #$01                ; PA0 to output
        sta PADD
togg:   inc PAD                 ; toggle PA0
        ldx tone                ; tone delay
freq:   dex
        bne freq
        bit TIMER_FLAG          ; time up?
        bpl togg                ; no
        dec ticks               ; more time units?
        bne timm
        rts

; ---- Space: stay silent for X time units ------------------------------

space:  stx ticks
tims:   lda speed               ; one time unit
        sta T1024_NOIRQ         ; start the timer
hold:   bit TIMER_FLAG          ; done?
        bpl hold                ; no
        dec ticks               ; more time units?
        bne tims
        rts

; ---- Disp: show the window once; Z set on return = no key down --------
; The book and manual call the segment port direction register PADD;
; it is the system RIOT's port A direction, SADD ($1741) in kim.inc.
; (kim.inc's PADD, $1701, is the user port used by mark.)

disp:   lda #$7f                ; segment lines to outputs
        sta SADD
        ldy #0                  ; index into the window
        ldx #9                  ; first digit select
six:    lda window,y            ; segment pattern
        sty TEMP                ; OUTPUT restores Y from TEMP
        jsr OUTPUT              ; show it; X += 2
        iny
        cpy #6                  ; all six digits?
        bcc six
        jsr KEYTS               ; digits off (needs X = $15), key down?
        rts

; ---- Random number subroutine -----------------------------------------
; Sum three of the six seed bytes plus carry (SEC), then shift the
; seed block up one byte.  SEC keeps an all-zero seed from sticking.

rand:   sec
        cld
        lda rnd+1
        adc rnd+4
        adc rnd+5
        sta rnd
        ldx #4
roll:   lda rnd,x
        sta rnd+1,x
        dex
        bpl roll
        rts

; ---- Initialization values for $E2-$ED --------------------------------

inittab:
        .byte   $00             ; index: nothing generated yet
        .byte   groups          ; grpleft
        .word   store-grpsize   ; grpptr: first group is at store
        .byte   $33             ; speed
        .byte   $64             ; tone
        .byte   $c0,$c0,$c0,$c0,$c0 ; window: dashes until the first key
        .byte   $00             ; sixth digit blank
inittab_end:
ninit   = inittab_end-inittab

; ---- Morse code table: A-Z, 0-9, ".", ",", "?", "=" -------------------

codetab:
        .byte   $60,$88,$a8,$90,$40,$28,$d0,$08 ; A B C D E F G H
        .byte   $20,$78,$b0,$48,$e0,$a0,$f0,$68 ; I J K L M N O P
        .byte   $d8,$50,$10,$c0,$30,$18,$70,$98 ; Q R S T U V W X
        .byte   $b8,$c8                         ; Y Z
        .byte   $fc,$7c,$3c,$1c,$0c,$04,$84,$c4 ; 0 1 2 3 4 5 6 7
        .byte   $e4,$f4                         ; 8 9
        .byte   $56,$ce,$32,$8c                 ; . , ? =

; ---- Display conversion table, same order -----------------------------
; Bit 7 is set in every entry (PA7 is the keypad input, so it is ignored
; on output).  Several glyphs are approximations: 5 and S are identical,
; as are I and comma.

segtab:
        .byte   $f7,$fc,$b9,$de,$f9,$f1,$bd,$f6 ; A B C D E F G H
        .byte   $84,$9e,$f0,$b8,$b7,$d4,$dc,$f3 ; I J K L M N O P
        .byte   $e7,$d0,$ed,$f8,$be,$ea,$9c,$94 ; Q R S T U V W X
        .byte   $ee,$c9                         ; Y Z
        .byte   $bf,$86,$db,$cf,$e6,$ed,$fd,$87 ; 0 1 2 3 4 5 6 7
        .byte   $ff,$ef                         ; 8 9
        .byte   $90,$84,$d3,$c8                 ; . , ? =
