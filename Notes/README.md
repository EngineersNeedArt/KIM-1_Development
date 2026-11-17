# Notes

## Display keycode in right two digits
```
0200: 20 6A 1F    jsr GETKEY
0203: 85 F9       sta INH
0205: 20 1F 1F    jsr SCANDS
0208: 4C 00 02    jmp $0200

