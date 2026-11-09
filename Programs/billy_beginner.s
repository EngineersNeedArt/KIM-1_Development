; billy beginner's program - supposed to swap $10 and $11

start:  lda $10         ; put $0010 into A
        sta $11         ; store A to $0011
        ldx $11         ; put $0011 into X
        stx $10         ; store X to $0010
        brk             ; stop