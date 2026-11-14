# Microchess

## How to build


`cd` into this directory (`/Microchess65`)

Run the following commands:

`ca65 -I .. -o microchess.o microchess.s`

`ld65 -C microchess.cfg -o microchess.bin microchess.o`

`srec_cat microchess.bin -binary \
    -crop 0x0000 0x004E  0x0070 0x00DC  0x0100 0x01AF  0x0200 0x03FA  0x1780 0x17E6 \
    -o microchess.tape -MOS_Technologies`
