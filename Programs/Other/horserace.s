; ---------------------------------------------------------------------------
; HORSE RACE  --  original KIM-1 design (six 7-segment digits, 3 horses)
; plain 6502, ca65.  Start with G 0200: a 3-byte stub there jumps to the game
; in FATMAIN ($0400, needs the PAL-2's extra RAM).  Load horserace and
; horserace-fat.bin.
;
; DISPLAY    digit 4 = leader.  Horse 1/2/3 = top (a) / middle (g) / bottom (d).
;            Markers are vertical segment pairs on 12 half-digit positions
;            scrolling right to left.  The track scrolls; the horses do not.
; CLOCKS     scan pass  = 10 ms  (RIOT timer, /64): display multiplexing,
;                         blink phase, ghost dimming.  No game logic.
;            game tick  = 3 passes = 30 ms: keys, AI, physics, scroll, render.
; SCALE      horse digit by gap: <2 m = 4, <5 m = 3, <9 m = 2, else 1 (ghost);
;            scroll 6.25 m per half-digit; a marker every 25 m
; UNITS      position = 1/256 m in 24 bits (1000 m = $03E800)
;            speed    = position units per tick (cruise 127 = 16.5 m/s)
;            stamina  = 16 bits, high byte is the 0-255 value
;            boost    = 16 bits (8.8 fixed), each whip adds, decays x31/32
; KEYS       read with the monitor's GETKEY ($15 = none), port A set to inputs first:
;            one key at a time (a second key held
;            down at the same time is not seen).  Key codes 0-6 and GO ($13).
; (old note) matrix key code = row*7 + column (21 keys; KEY_NONE = $15), so keys
;            0-6 are matrix row 0 (SBD $01) and GO ($13) is row 2 (SBD $05).
;            Column n = SAD bit n, a pressed key reads 0.  *** verify on hardware ***
; ---------------------------------------------------------------------------

        .include "kim.inc"

; Set to 1 to call the monitor's KEYIN before GETKEY (fallback if GETKEY alone misbehaves)
USE_KEYIN   = 0

; ---- timing ----
PASS_T      = 156           ; 156 * 64 us = 9.98 ms per scan pass
TICK_PASSES = 3             ; 30 ms game tick
TPS         = 33            ; ticks per countdown second (0.99 s)
D1          = 54            ; slot part 1 (~25 %): everything lit, incl. the ghost
D2          = 48            ; slot part 2 (~25 %): ghost off, markers still lit
D3          = 102           ; slot part 3 (~50 %): markers off too (horses and text only)
                            ; => ghost 25 %, markers 50 %, horses and text 100 %

; ---- display scale: scroll 6.25 m per half-digit; horse digits by gap behind the leader ----
GAP1        = $0200         ; 2 m   within this of the leader: digit 4 (with the leader)
GAP2        = $0500         ; 5 m   digit 3 below this
GAP3        = $0900         ; 9 m   digit 2 below this; this far or more behind: ghost on digit 1
SCROLLHI    = $06           ; one scroll step = $0640 = 1600 units = 6.25 m
SCROLLLO    = $40
RNDHI       = $03           ; round up above half a step ($0320)
RNDLO       = $21
NMARK       = 41            ; one marker every 25 m: 0 .. 1000 m
TURNLO      = 17            ; markers strictly inside the turn (425-775 m)
TURNHI      = 32

; ---- race physics (per 30 ms tick) ----
CRUISE      = 127           ; 16.5 m/s
POOPSPD     = 108           ; 85 % of cruise
BUMP        = $099A         ; each whip adds 1.25 m/s of boost (8.8 fixed)
BOOSTMAX    = $17           ; boost high byte cap (~3 m/s)
COSTHI      = $06           ; whip costs 6 stamina units ($0600)
REGEN       = 15            ; ~2 units/s
REGENP      = 46            ; ~6 units/s while pooped
TIRED       = $40           ; stamina high byte: below = tired, pooped exit
FINHI       = $03           ; finish = 1000 m = $03E800
FINMID      = $E8

; ---- states ----
ST_CHOOSE   = 0
ST_COUNT    = 1
ST_RACE     = 2
ST_FINISH   = 3

        .segment "ZEROPAGE"
phase:    .res 1            ; counts scan passes (blink / dim phase)
passcnt:  .res 1
state:    .res 1
nplayers: .res 1
cdsec:    .res 1
cdtick:   .res 1
rnd:      .res 1
keys0:    .res 1            ; keys 0-6, bit n = key n down
keys2:    .res 1            ; keys 14-20 (bit 5 = GO)
prev0:    .res 1
prev2:    .res 1
new0:     .res 1            ; new key-downs this tick
new2:     .res 1
plo:      .res 3            ; per horse: position, 24 bit
pmid:     .res 3
phi:      .res 3
stlo:     .res 3            ; stamina
sthi:     .res 3
bolo:     .res 3            ; boost
bohi:     .res 3
pooped:   .res 3
whipf:    .res 3            ; whip requested this tick
wflash:   .res 3            ; ticks left to hide the horse (whip feedback)
hdig:     .res 3            ; display digit index 0-5 ($FF = not shown)
hghost:   .res 3            ; 1 = dim (far behind)
hblink:   .res 3            ; 0 steady, 1 slow (tired), 2 fast (pooped)
lead:     .res 1
ldlo:     .res 1            ; leader position
ldmid:    .res 1
ldhi:     .res 1
oldlo:    .res 1
rlo:      .res 1            ; scroll remainder, 0..3199
rhi:      .res 1
sstep:    .res 1            ; whole scroll steps
scroll:   .res 1            ; rounded step used for drawing
tickslo:  .res 1
tickshi:  .res 1
mbuf:     .res 6            ; marker segments per digit (drawn at 50 % brightness)
sbuf:     .res 6            ; text / glyphs (full brightness): prompt, countdown, finish
hbuf:     .res 6            ; sbuf + visible horses, rebuilt each pass
pbuf:     .res 6            ; hbuf + mbuf (everything), rebuilt each pass
gmask:    .res 1
gmi:      .res 1
mk:       .res 1
mp:       .res 1
mtype:    .res 1
nmark:    .res 1
t0:       .res 1
t1:       .res 1
tmp:      .res 1
rg:       .res 1
r1:       .res 1
rh:       .res 1
rc:       .res 1

        .segment "CODE"            ; $0200: stub, so G 0200 still works
        jmp start

        .segment "FATMAIN"         ; $0400: the game (too big for $0200-$03FF)

start:
        sei
        cld
        lda #0                  ; clear variables $00-$7F
        tax
clrzp:  sta $00,x
        inx
        cpx #$80
        bne clrzp
        lda #$7f
        sta SADD                ; PA0-PA6 segment outputs
        lda #$1f
        sta SBDD                ; PB0-PB4: serial idle bit + digit decoder
        lda #$a5
        sta rnd
        jsr enter_choose
main:
        lda #PASS_T
        sta T64_NOIRQ
        jsr drawpass
        inc passcnt
        lda passcnt
        cmp #TICK_PASSES
        bcc waitpass
        lda #0
        sta passcnt
        jsr tick
waitpass:
        bit TIMER_FLAG
        bpl waitpass
        jmp main

; ---------------------------------------------------------------------------
; one scan pass: build pbuf, then light the six digits
; ---------------------------------------------------------------------------
drawpass:
        inc phase
        ldx #5
dp_cp:  lda sbuf,x
        sta hbuf,x
        dex
        bpl dp_cp
        lda #0
        sta gmask
        ldx #2
dp_h:   lda hdig,x
        cmp #6
        bcs dp_nh               ; not shown
        ldy hblink,x
        lda bmask,y
        beq dp_vis              ; steady
        bmi dp_nh               ; whip flash: hidden
        and phase
        beq dp_nh               ; blink: off phase
dp_vis: ldy hdig,x
        lda lane,x
        ora hbuf,y
        sta hbuf,y
        lda hghost,x
        beq dp_nh
        lda gmask
        ora lane,x
        sta gmask
dp_nh:  dex
        bpl dp_h
        lda gmask
        eor #$ff
        sta gmi
        ldx #5
dp_pb:  lda hbuf,x
        ora mbuf,x
        sta pbuf,x              ; pbuf = horses + text + markers
        dex
        bpl dp_pb
        ldx #0
dp_slot:
        lda #0
        sta SAD                 ; blank before changing digit
        lda digsel,x
        sta SBD
        lda pbuf,x
        sta SAD                 ; part 1: everything
        ldy #D1
dp_d1:  dey
        bne dp_d1
        lda pbuf,x
        and gmi
        sta SAD                 ; part 2: ghost off
        ldy #D2
dp_d2:  dey
        bne dp_d2
        lda hbuf,x
        and gmi
        sta SAD                 ; part 3: markers off too
        ldy #D3
dp_d3:  dey
        bne dp_d3
        inx
        cpx #6
        bne dp_slot
        lda #0
        sta SAD
        rts

; ---------------------------------------------------------------------------
; keypad: row 0 (keys 0-6) and row 2 (keys 14-20, GO = bit 5)
; ---------------------------------------------------------------------------
readkeys:
        ldx #0
        stx keys0
        stx keys2
        lda #0
        sta SADD                ; port A = inputs, so GETKEY can read the keypad
.if USE_KEYIN
        jsr KEYIN               ; fallback: monitor's own keypad setup
.endif
        jsr GETKEY              ; key code in A, KEY_NONE ($15) if none
        cmp #4
        bcs rk_hi
        tax                     ; keys 0-3 -> bit n of keys0
        lda bitn,x
        sta keys0
        bne rk_x
rk_hi:  cmp #KEY_GO
        bne rk_x                ; any other key is ignored
        lda #$20                ; GO -> bit 5 of keys2
        sta keys2
rk_x:   lda #$7f                ; back to outputs for the display
        sta SADD
        lda #$1f
        sta SBDD
        rts

; ---------------------------------------------------------------------------
; game tick
; ---------------------------------------------------------------------------
tick:
        jsr readkeys
        lda prev0
        eor #$ff
        and keys0
        sta new0
        lda prev2
        eor #$ff
        and keys2
        sta new2
        lda keys0
        sta prev0
        lda keys2
        sta prev2
        lda state
        beq tk_choose
        cmp #ST_COUNT
        beq tk_count
        cmp #ST_RACE
        beq tk_race
        jmp do_finish
tk_choose:
        jmp do_choose
tk_count:
        jmp do_count
tk_race:
        jmp do_race

; ---- choose number of human players: key 0-3 ----
enter_choose:
        lda #ST_CHOOSE
        sta state
        jsr nohorses
        jsr clrbufs
        lda #$73                ; P
        sta sbuf+0
        lda #$3f                ; 0
        sta sbuf+3
        lda #$40                ; -
        sta sbuf+4
        lda #$4f                ; 3
        sta sbuf+5
        rts

do_choose:
        lda new0
        and #$0f
        beq dc_rts
        ldx #0
dc_f:   lsr a
        bcs dc_found
        inx
        bne dc_f
dc_found:
        stx nplayers
        lda rnd
        eor phase
        ora #$01
        sta rnd
        jmp enter_count
dc_rts: rts

clrbufs:                        ; clear markers and text
        lda #0
        ldx #5
cb_l:   sta mbuf,x
        sta sbuf,x
        dex
        bpl cb_l
        rts

nohorses:
        ldx #2
nh_l:   lda #$ff
        sta hdig,x
        lda #0
        sta hghost,x
        sta hblink,x
        dex
        bpl nh_l
        rts

; ---- countdown ----
enter_count:
        ldx #2
ec_z:   lda #0
        sta plo,x
        sta pmid,x
        sta phi,x
        sta bolo,x
        sta bohi,x
        sta pooped,x
        sta whipf,x
        sta wflash,x
        sta hghost,x
        lda #$ff
        sta stlo,x
        sta sthi,x
        lda #3
        sta hdig,x
        lda #1
        sta hblink,x            ; horses blink during the countdown
        dex
        bpl ec_z
        lda #0
        sta rlo
        sta rhi
        sta sstep
        sta scroll
        sta oldlo
        sta tickslo
        sta tickshi
        sta cdtick
        jsr clrbufs
        lda #5
        sta cdsec
        lda #ST_COUNT
        sta state
        jmp show_count

show_count:
        lda #1
        sta nmark               ; start line only
        jsr rendermarkers
        ldx cdsec
        lda font,x
        sta sbuf+5
        ldx nplayers
        lda font,x              ; players, digit 1
        sta sbuf+0
        rts

do_count:
        inc cdtick
        lda cdtick
        cmp #TPS
        bcs dn_sec
        jmp show_count
dn_sec: lda #0
        sta cdtick
        dec cdsec
        beq dn_go
        jmp show_count
dn_go:  lda #ST_RACE
        sta state
        lda #0
        ldx #2
dn_b:   sta hblink,x
        dex
        bpl dn_b
        ldx #5
dn_s:   sta sbuf,x              ; A = 0: drop the countdown text
        dex
        bpl dn_s
        rts

; ---- race ----
do_race:
        ldx #2
dr_w:   lda #0
        sta whipf,x
        cpx nplayers
        bcs dr_ai
        lda new0
        and keybit,x            ; human: key 1/2/3, new key-down only
        beq dr_wn
        lda #1
        sta whipf,x
        bne dr_wn
dr_ai:  jsr aidecide
dr_wn:  dex
        bpl dr_w
        jsr physics
        jsr findleader
        jsr scrollupd
        jsr gaps
        jsr setblink
        jsr flashfx
        lda #NMARK
        sta nmark
        jsr rendermarkers
        inc tickslo
        bne dr_t
        inc tickshi
dr_t:   lda ldhi
        cmp #FINHI
        bcc dr_nf
        bne dr_fin
        lda ldmid
        cmp #FINMID
        bcc dr_nf
dr_fin: jmp enter_finish
dr_nf:  rts

; ---- computer horses: decide whether to whip horse X ----
aidecide:
        lda pooped,x
        bne ai_no
        jsr rand
        sta r1
        lda ldhi
        cmp #$03
        bcc ai_cruise
        bne ai_stretch
        lda ldmid
        cmp #$20
        bcc ai_cruise
ai_stretch:                     ; leader past 800 m: spend down to 25 %
        lda sthi,x
        cmp #TIRED
        bcc ai_no
        lda r1
        and #$0f
        bne ai_no
        beq ai_yes
ai_cruise:
        lda sthi,x
        cmp aires,x             ; keep a per-horse reserve for the stretch
        bcc ai_no
        lda hdig,x
        cmp #2                  ; digit 3 or 4 (within 5 m of the leader): close
        bcs ai_close
        lda r1
        and #$1f                ; behind a digit or more: whip about 1/s
        bne ai_no
        beq ai_yes
ai_close:
        lda r1
        and #$7f                ; close: about one whip per 4 s
        bne ai_no
ai_yes: lda #1
        sta whipf,x
ai_no:  rts

rand:   lda rnd
        asl a
        bcc rn_s
        eor #$1d
rn_s:   sta rnd
        rts

; ---- physics for all three horses ----
physics:
        ldx #2
py_l:   jsr physone
        dex
        bpl py_l
        rts

physone:
        lda whipf,x
        beq po_nw
        jsr dowhip
po_nw:  ldy pooped,x            ; stamina regeneration
        lda regentab,y
        sta rg
        clc
        lda stlo,x
        adc rg
        sta stlo,x
        lda sthi,x
        adc #0
        bcc po_ok
        lda #$ff
        sta stlo,x
po_ok:  sta sthi,x
        ldy pooped,x
        beq po_dec
        cmp #TIRED
        bcc po_dec
        lda #0
        sta pooped,x            ; recovered
po_dec: lda bohi,x              ; boost -= boost >> 5
        sta t1
        lda bolo,x
        sta t0
        ldy #5
po_sh:  lsr t1
        ror t0
        dey
        bne po_sh
        sec
        lda bolo,x
        sbc t0
        sta bolo,x
        lda bohi,x
        sbc t1
        sta bohi,x
        lda pooped,x
        bne po_ps
        clc
        lda bohi,x
        adc #CRUISE
        jmp po_mv
po_ps:  lda #POOPSPD
po_mv:  clc
        adc plo,x
        sta plo,x
        lda pmid,x
        adc #0
        sta pmid,x
        lda phi,x
        adc #0
        sta phi,x
        rts

dowhip:
        lda pooped,x
        bne dw_done
        sec
        lda sthi,x
        sbc #COSTHI
        sta sthi,x
        bcs dw_ok
        lda #0                  ; ran out: pooped, no boost
        sta stlo,x
        sta sthi,x
        sta bolo,x
        sta bohi,x
        lda #1
        sta pooped,x
        rts
dw_ok:  clc
        lda bolo,x
        adc #<BUMP
        sta bolo,x
        lda bohi,x
        adc #>BUMP
        sta bohi,x
        cmp #BOOSTMAX
        bcc dw_done
        lda #BOOSTMAX
        sta bohi,x
        lda #0
        sta bolo,x
dw_done:
        rts

setblink:
        ldx #2
sb_l:   lda pooped,x
        beq sb_np
        lda #2
        bne sb_s
sb_np:  lda sthi,x
        cmp #TIRED
        bcs sb_ok
        lda #1
        bne sb_s
sb_ok:  lda #0
sb_s:   sta hblink,x
        dex
        bpl sb_l
        rts

; whip feedback: a horse that whipped (human or computer) blinks out for 3 ticks
flashfx:
        ldx #2
ff_l:   lda whipf,x
        beq ff_n
        lda #3
        sta wflash,x
ff_n:   lda wflash,x
        beq ff_d
        dec wflash,x
        lda #3
        sta hblink,x
ff_d:   dex
        bpl ff_l
        rts

; ---- leader = furthest horse (ties: lowest number) ----
findleader:
        lda #0
        sta lead
        ldx #1
fl_l:   ldy lead
        lda phi,x
        cmp phi,y
        bcc fl_n
        bne fl_s
        lda pmid,x
        cmp pmid,y
        bcc fl_n
        bne fl_s
        lda plo,x
        cmp plo,y
        bcc fl_n
        beq fl_n
fl_s:   stx lead
fl_n:   inx
        cpx #3
        bne fl_l
        ldy lead
        lda plo,y
        sta ldlo
        lda pmid,y
        sta ldmid
        lda phi,y
        sta ldhi
        rts

; ---- scroll: whole 6.25 m steps plus remainder, rounded to nearest ----
scrollupd:
        lda ldlo
        sec
        sbc oldlo               ; leader's advance this tick (< 256)
        clc
        adc rlo
        sta rlo
        bcc su_w
        inc rhi
su_w:   lda rhi
        cmp #SCROLLHI           ; one step = 6.25 m
        bcc su_d
        bne su_sub
        lda rlo
        cmp #SCROLLLO
        bcc su_d
su_sub: sec
        lda rlo
        sbc #SCROLLLO
        sta rlo
        lda rhi
        sbc #SCROLLHI
        sta rhi
        inc sstep
        jmp su_w
su_d:   lda sstep
        sta scroll
        lda rhi
        cmp #RNDHI              ; remainder > half a step: round up
        bcc su_n
        bne su_a
        lda rlo
        cmp #RNDLO
        bcc su_n
su_a:   inc scroll
su_n:   lda ldlo
        sta oldlo
        rts

; ---- digit for each horse from its gap behind the leader ----
gaps:
        ldx #2
gp_l:   lda #0
        sta hghost,x
        sec
        lda ldlo
        sbc plo,x
        sta t1                  ; gap, low byte (1/256 m)
        lda ldmid
        sbc pmid,x
        sta t0                  ; gap, whole metres
        lda ldhi
        sbc phi,x
        bne gp_g
        ldy #3                  ; digit 4: gap below GAP1
        lda t0
        cmp #>GAP1
        bcc gp_s
        bne gp_n1
        lda t1
        cmp #<GAP1
        bcc gp_s
gp_n1:  dey                     ; digit 3: below GAP2
        lda t0
        cmp #>GAP2
        bcc gp_s
        bne gp_n2
        lda t1
        cmp #<GAP2
        bcc gp_s
gp_n2:  dey                     ; digit 2: below GAP3
        lda t0
        cmp #>GAP3
        bcc gp_s
        bne gp_g
        lda t1
        cmp #<GAP3
        bcc gp_s
gp_g:   ldy #0                  ; GAP3 or more behind: dim on digit 1
        lda #1
        sta hghost,x
gp_s:   tya
        sta hdig,x
        dex
        bpl gp_l
        rts

; ---- markers: every 25 m, position p = 6 + 4k - scroll on 12 half-digits ----
rendermarkers:
        lda #0
        ldx #5
rm_c:   sta mbuf,x
        dex
        bpl rm_c
        lda scroll              ; first marker that can show: k >= (scroll-7)/4
        sec
        sbc #4
        bcs rm_k
        lda #0
rm_k:   lsr a
        lsr a
        sta mk
        lda scroll              ; last marker that can show: k <= (scroll+5)/4
        clc
        adc #5
        lsr a
        lsr a
        sta t0
        lda nmark               ; and never past the last marker wanted
        sec
        sbc #1
        cmp t0
        bcs rm_l
        sta t0
rm_l:
rm_n:   lda mk
        asl a
        asl a
        clc
        adc #6
        sec
        sbc scroll
        sta mp
        lda mk
        cmp #TURNLO             ; 425-775 m: inside the turn, top half only
        bcc rm_f
        cmp #TURNHI
        bcs rm_f
        lda #1
        bne rm_t
rm_f:   lda #0
rm_t:   sta mtype
        jsr putbar
        lda mk
        beq rm_d                ; start line and finish line: extra bar
        cmp #NMARK-1
        bne rm_x
rm_d:   inc mp
        jsr putbar
rm_x:   inc mk
        lda t0
        cmp mk
        bcs rm_n
        rts

putbar:                         ; mp = half-digit position, mtype 0 full / 1 top
        lda mp
        bmi pb_x
        cmp #12
        bcs pb_x
        lsr a
        tay                     ; Y = digit, carry = right side
        ldx mtype
        bcs pb_r
        lda lmask,x
        bne pb_o
pb_r:   lda rmask,x
pb_o:   ora mbuf,y
        sta mbuf,y
pb_x:   rts

; ---- finish: rank, show order (digits 1-3) and seconds (digits 5-6) ----
enter_finish:
        lda #ST_FINISH
        sta state
        jsr nohorses
        lda #0
        ldx #5
ef_c:   sta mbuf,x
        sta sbuf,x
        dex
        bpl ef_c
        sta rh
ef_h:   lda #0
        sta rc
        ldx #0
ef_j:   cpx rh
        beq ef_k
        ldy rh
        jsr beats
        bcc ef_k
        inc rc
ef_k:   inx
        cpx #3
        bne ef_j
        ldy rc                  ; rank 0 = winner
        ldx rh
        inx
        lda font,x              ; horse number glyph
        sta sbuf,y
        inc rh
        lda rh
        cmp #3
        bne ef_h
        lda tickslo             ; seconds = ticks * 3 / 100
        sta t0
        lda tickshi
        sta t1
        asl t0
        rol t1
        clc
        lda t0
        adc tickslo
        sta t0
        lda t1
        adc tickshi
        sta t1
        ldx #0
ef_s:   lda t1
        bne ef_u
        lda t0
        cmp #100
        bcc ef_t
ef_u:   sec
        lda t0
        sbc #100
        sta t0
        lda t1
        sbc #0
        sta t1
        inx
        cpx #99
        bcc ef_s
ef_t:   txa
        ldy #0
ef_10:  cmp #10
        bcc ef_o
        sbc #10
        iny
        bne ef_10
ef_o:   tax
        lda font,x
        sta sbuf+5
        lda font,y
        sta sbuf+4
        rts

beats:                          ; C=1 if horse X is ahead of horse Y (ties: lower number)
        lda phi,x
        cmp phi,y
        bcc bt_n
        bne bt_y
        lda pmid,x
        cmp pmid,y
        bcc bt_n
        bne bt_y
        lda plo,x
        cmp plo,y
        bcc bt_n
        bne bt_y
        stx tmp
        cpy tmp                 ; equal: X wins if Y > X
        rts
bt_y:   sec
        rts
bt_n:   clc
        rts

do_finish:
        lda new2
        and #$20                ; GO
        beq df_r
        jmp enter_choose
df_r:   rts

; ---------------------------------------------------------------------------
; tables
; ---------------------------------------------------------------------------
digsel:   .byte $09,$0b,$0d,$0f,$11,$13     ; digits 1-6
lane:     .byte $01,$40,$08                 ; horse 1 top (a), 2 middle (g), 3 bottom (d)
bmask:    .byte $00,$10,$08,$80                 ; steady, slow blink, fast blink
lmask:    .byte $30,$20                     ; left side: full (e+f), top only (f)
rmask:    .byte $06,$02                     ; right side: full (b+c), top only (b)
bitn:     .byte $01,$02,$04,$08,$10,$20,$40
keybit:   .byte $02,$04,$08                 ; keys 1, 2, 3
regentab: .byte REGEN,REGENP
aires:    .byte $80,$70,$90                 ; per-horse stamina reserve (computer)
font:     .byte $3f,$06,$5b,$4f,$66,$6d,$7d,$07,$7f,$6f
