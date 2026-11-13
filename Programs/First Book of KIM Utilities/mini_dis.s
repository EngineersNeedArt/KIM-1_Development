; mini_dis.s -- MINI DIS semi-disassembler (The First Book of KIM, Utilities)
;
; Shows the address, opcode and operand bytes of each instruction of the
; program under study, and flags illegal opcodes by blinking the display.
;
; To run: store $00 in $17FA and $03 in $17FB (the NMI vector, which makes
; the ST key start this program), go to the beginning of your program and
; press ST.  The first instruction is displayed.
;   +    next instruction
;   PC   redisplay the current address and opcode (any time)
;   B    backstep (acts like PC at the beginning, or with the stack
;        pushes below removed)
;   RS   needed to leave a blinking illegal opcode
;
; The instruction length is worked out from bit patterns in the opcode
; (x = don't care).  Every absolute address is a label, so relocating is
; just a matter of moving the program and pointing the NMI vector at it.
; To keep MINI DIS off the stack, or to examine a program in page 1,
; change the two PHAs at "step" to NOPs.

        .include "kim.inc"

; Monitor entry points used here that kim.inc does not define
SCAND       = $1F19     ; load INH from (POINTL), then fall into SCANDS
INCPT       = $1F63     ; increment POINTL/POINTH

; Zero-page cells (all in the user area)
DBUF        = $E5       ; display buffer: $E6-$EB, one 7-segment code per digit
BLINK       = $EC       ; bit 0 flips every 1/4 second while blinking
LIMIT       = $ED       ; where the digit loop stops
NBYTES      = $EE       ; bytes converted so far / length of the instruction

        .segment "CODE"

        .res $100               ; the book puts MINI DIS at $0300

begin:  cld
        ldx #$FF                ; initialize stack
        txs                     ; pointer
init:   ldy #$00                ; clear $E6-$EE
        ldx #$09
init1:  sty DBUF,x
        dex
        bne init1
        inx                     ; X=1
length: lda (POINTL),y          ; get opcode, find length
        cmp #$20                ; analyze bit patterns
        beq bytes3              ; %00100000 ; 3 bytes (JSR)
        and #$9F                ; "x" means don't care
        beq bytes1              ; %0xx00000 ; 1 byte (00,40,60)
        cmp #$92
        beq flash               ; %1xx10010 ; illegal (92,B2,D2,F2)
        tay                     ; store temporarily
        and #$1D
        cmp #$19
        beq bytes3              ; %xxx110x1 ; 3 bytes (59,B9)
        and #$0D
        cmp #$08
        beq bytes1              ; %xxxx10x0 ; 1 byte (D8,4A)
        and #$0C
        cmp #$0C
        beq bytes3              ; %xxxx11xx ; 3 bytes (4C,EE)
        tya                     ; restore
        and #$8F
        cmp #$02                ; %0xxx0010 ; illegal (22,52)
        bne bytes2              ; all leftovers: 2 bytes

flash:  inc BLINK               ; flip bit 0
        lda #$FF                ; loop for 1/4 second
        sta T1024_NOIRQ
flash1: lda BLINK               ; blink on or off
        and #$01
        beq flash2              ; bit 0 = 0: blink off
        jsr SCAND               ; bit 0 = 1: blink on
flash2: bit TIMER_FLAG
        bmi flash
        bpl flash1

bytes1: inx
bytes2: inx
bytes3: txa                     ; center code: X = 3, 2 or 1 here, so
        eor #$07                ; LIMIT = 4, 5 or 6 for 1, 2 or 3 bytes
        sta LIMIT
convrt: ldy NBYTES              ; loop for each byte
        lda (POINTL),y          ; convert and store
        pha                     ; in E6-EB
        lsr a
        lsr a
        lsr a
        lsr a
        tay
        lda TABLE,y
        sta DBUF,x
        inx
        pla
        and #$0F
        tay
        lda TABLE,y
        sta DBUF,x
        inx
        inc NBYTES
        cpx LIMIT
        bcc convrt

kdown:  jsr disp                ; display until all keys
        bne kdown               ; are up
kup:    jsr disp                ; display and GETKEY
        jsr GETKEY
        cmp #$0B                ; is "B" pressed?
        bne plus                ; ..no, branch
bckstp: tsx
        cpx #$FF                ; is stack empty?
        beq window              ; ..yes, act like "PC"
        pla                     ; pull FB and FA
        sta POINTH              ; display word
        pla
        sta POINTL
neword: jmp init
plus:   cmp #KEY_PLUS           ; is "+" pressed?
        bne pckey               ; ..no, branch
step:   lda POINTL              ; push FA and FB
        pha
        lda POINTH
        pha
step1:  jsr INCPT               ; find new location
        dec NBYTES              ; display word
        beq neword
        bne step1
pckey:  cmp #KEY_PC             ; is "PC" pressed?
        bne kup                 ; ..no, get key
window: jsr SCAND               ; display location
        beq kup                 ; until key released
        bne window              ; then get key

; Light the six digits from the buffer; returns with A <> 0 if a key is down
disp:   lda #$7F                ; segments to count
        sta SADD
        ldx #$08                ; initialize (digit select; book has $08)
        ldy #$00
disp1:  sty TEMP
        lda DBUF+1,y            ; get character
        jsr OUTPUT              ; display character
        iny                     ; next character
        cpy #$06
        bcc disp1
        jmp KEYTS               ; done, key down?
