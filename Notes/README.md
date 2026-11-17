# Notes

### GETKEY

The following short program will display the keycode (in the right two LED digits) when a key is pressed:
```
0200: 20 6A 1F    jsr GETKEY
0203: 85 F9       sta INH
0205: 20 1F 1F    jsr SCANDS
0208: 4C 00 02    jmp $0200
```

"0" to "F" return `00` to `0F`, "AD" —> `10`, "DA" —> `11`, "+" —> `12`, "GO" —> `13`, "PC" —> `14`

`15` indicates no key is being pressed.

(`ST` and `RS` will stop the program and so cannot be tested.)
