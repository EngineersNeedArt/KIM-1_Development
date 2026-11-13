; sort.s -- SORT (The First Book of KIM, Utilities)
;
; Arranges any block of data in numerical sequence, hex or BCD or both
; (the compare is unsigned, so BCD in a valid range sorts correctly too).
; Position-independent: it uses only relative branches (plus the jump back
; to the monitor), so it can be located anywhere.  The book puts it at $0200.
;
; Before running, set:
;   $17F5,$17F6   address of the first item   (SAL, SAH)
;   $17F7,$17F8   address one PAST the last item  (EAL, EAH)
; The block must contain at least one item.
;
; Order: as printed the program sorts DESCENDING (largest item first, at
; the lowest address).  The branch at "get" decides it:
;   BCS ($B0) = descending, BCC ($90) = ascending.
; Assemble with -D ASCENDING for the ascending version.
;
; It is an exchange sort.  The item at PIVOT is compared with each
; following item, and they are swapped when the later one should come
; first.  After one pass the item at PIVOT is the extreme one; PIVOT then
; moves on one item and the process repeats until the whole list is in
; sequence.

        .include "kim.inc"

HOLD        = $E7       ; temporary for the swap
PIVOT       = $E8       ; address of the item being placed, 2 bytes
SCAN        = $EA       ; address of the item being compared, 2 bytes
LIMIT       = $EC       ; end address (one past the last item), 2 bytes

        .segment "CODE"

sort:   lda SAL                 ; transfer start pointer
        sta PIVOT               ; to zero page
        sta SCAN
        lda SAH
        sta PIVOT+1
        sta SCAN+1
        lda EAL                 ; transfer end pointer
        sta LIMIT
        lda EAH
        sta LIMIT+1
        ldx #$00                ; index to zero (stays there)
        cld
get:    lda (PIVOT,x)           ; get data indirect PIVOT
        cmp (SCAN,x)            ; compare with data indirect SCAN
.ifdef ASCENDING
        bcc incn                ; ascending: no swap if pivot < item
.else
        bcs incn                ; descending: no swap if pivot >= item
.endif
swap:   lda (PIVOT,x)           ; swap data in pointer
        sta HOLD                ; locations
        lda (SCAN,x)
        sta (PIVOT,x)
        lda HOLD
        sta (SCAN,x)
incn:   inc SCAN                ; set up next comparison
        bne lastn               ; no page change
        inc SCAN+1              ; page change
lastn:  lda SCAN                ; OK for last item in pass
        cmp LIMIT
        bne get                 ; not yet
        lda LIMIT+1             ; is this the last pass/loop?
        cmp SCAN+1
        bne get                 ; ..no
        inc PIVOT               ; next pass starts one item further on
        bne over                ; no page change
        inc PIVOT+1             ; page change
over:   lda PIVOT               ; init value for next pass
        sta SCAN
        lda PIVOT+1
        sta SCAN+1
        lda SCAN                ; last item in list?
        cmp LIMIT
        bne get                 ; ..no, not yet
        lda PIVOT+1
        sta SCAN+1
        cmp LIMIT+1             ; last page?
        bne get                 ; ..no
        jmp START               ; back to KIM, done
