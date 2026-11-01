; kim.inc -- PAL-II / KIM-1 symbols for ca65
; Source: PAL-II quick-reference cheat sheet (memory map, zero page, monitor routines)
; Usage:  .include "kim.inc"
;
; Notes
;  - ST and SST only work when NMIV ($17FA) = $1C00.
;  - BRK returns to the monitor only when IRQV ($17FE) = $1C00.
;  - SST switch must be OFF to run programs normally.
;  - The TTY monitor accepts upper-case input only.
;  - Register preservation of the monitor routines is not documented
;    in the cheat sheet (GETCH is noted as altering X and Y); assume
;    A, X and Y may be clobbered across any JSR into the monitor.

; ---- Zero page: user area is $0000-$00EE; $00EF-$00FF is monitor ----
PCL      = $00EF         ; saved PC low
PCH      = $00F0         ; saved PC high
PREG     = $00F1         ; saved status register P
SPUSER   = $00F2         ; saved stack pointer
ACC      = $00F3         ; saved accumulator
YREG     = $00F4         ; saved Y
XREG     = $00F5         ; saved X
CHKHI    = $00F6         ; checksum (tape / paper tape)
CHKSUM   = $00F7
INL      = $00F8         ; input buffer low (data on display)
INH      = $00F9         ; input buffer high
POINTL   = $00FA         ; address on display (low); G runs from here
POINTH   = $00FB         ; address on display (high)
TEMP     = $00FC         ; scratch
TMPX     = $00FD         ; scratch X
CHAR     = $00FE         ; TTY character
MODE     = $00FF         ; monitor mode (AD/DA)

; ---- RIOT U3 (6532-003): user ports on the APP connector ----
PAD      = $1700         ; port A data  (PA0-PA7)
PADD     = $1701         ; port A direction (1 = output)
PBD      = $1702         ; port B data  (PB0-PB5, PB7)
PBDD     = $1703         ; port B direction (1 = output)
; Timer writes, no IRQ: divide by 1, 8, 64, 1024
T1_NOIRQ    = $1704
T8_NOIRQ    = $1705
T64_NOIRQ   = $1706
T1024_NOIRQ = $1707
; Timer writes, with IRQ
T1_IRQ      = $170C
T8_IRQ      = $170D
T64_IRQ     = $170E
T1024_IRQ   = $170F
; Reads: $1706 = counter, $1707 = underflow flag (bit 7)
TIMER_READ  = $1706
TIMER_FLAG  = $1707

; ---- RIOT U2 (6532-002): system -- display / keypad / TTY (do not use) ----
SAD      = $1740         ; display segments / keypad columns; PA7 = TTL IN
SADD     = $1741         ; port A direction
SBD      = $1742         ; digit / row select; PB0 = TTL OUT
SBDD     = $1743         ; port B direction
CLK1T    = $1744         ; timer /1    (used by monitor)
CLK8T    = $1745         ; timer /8
CLK64T   = $1746         ; timer /64
CLKKT    = $1747         ; timer /1024

; ---- Monitor RAM ($17E7-$17FF) ----
CHKL     = $17E7         ; checksum
CHKH     = $17E8
SAVX     = $17E9         ; scratch (3 bytes)
VEB      = $17EC         ; "volatile execution block" (6 bytes)
CNTL30   = $17F2         ; TTY speed constant (auto-baud)
CNTH30   = $17F3
TIMH     = $17F4         ; scratch (TTY timing)
SAL      = $17F5         ; start address (tape)
SAH      = $17F6
EAL      = $17F7         ; end address (tape)
EAH      = $17F8
ID       = $17F9         ; tape record ID
NMIV     = $17FA         ; NMI vector   -> set to $1C00 for ST / SST
RSTV     = $17FC         ; RST vector (user)
IRQV     = $17FE         ; IRQ/BRK vector -> $1C00 = BRK into monitor

; ---- Monitor ROM (U5) routines ----
DUMPT    = $1800         ; save to cassette (no cassette circuits on PAL-II)
LOADT    = $1873         ; load from cassette (likewise unused)
SAVE     = $1C00         ; monitor entry (NMI/BRK), saves registers
RST      = $1C22         ; monitor reset
START    = $1C4F         ; return to monitor (JMP)
PRTPNT   = $1E1E         ; print POINTH/POINTL to TTY
CRLF     = $1E2F         ; print CR LF
PRTBYT   = $1E3B         ; print A as 2 hex digits
GETCH    = $1E5A         ; TTY character -> A (alters X, Y)
OUTSP    = $1E9E         ; print space
OUTCH    = $1EA0         ; print character in A to TTY
SCANDS   = $1F1F         ; show POINTH POINTL INH on display
CONVD    = $1F48         ; output HEX digit
OUTPUT   = $1F4E         ; output 7 segment code stored in A register (light up a custom segment)
KEYIN    = $1F40         ; key pressed? (A <> 0)
GETKEY   = $1F6A         ; key code -> A
GETBYT   = $1F9D         ; 2 hex chars from TTY -> A

KEY_DA   = $11
KEY_PLUS = $12
KEY_GO   = $13
KEY_PC   = $14
KEY_NONE = $15          ; GETKEY value when no key is down

; ---- Program start used by the build ($0200-$03FF is the usual area) ----
PROGRAM_ORG = $0200
